defmodule ExGram.FSM.DispatchTest do
  @moduledoc """
  Full-dispatch integration tests for ExGram.FSM.

  Unlike the unit-level tests in `integration_test.exs`, these tests push updates
  through the complete ExGram dispatch pipeline:

      Update -> Dispatcher -> Middleware chain -> handle/2 -> DSL responses -> API calls

  The bot module, flows, and commands are exercised exactly as they would be in
  production.
  """
  use ExUnit.Case, async: false
  use ExGram.Test

  alias ExGram.FSM.Storage.ETS

  # --- Flow modules ---

  defmodule RegistrationFlow do
    use ExGram.FSM.Flow, name: :registration

    defstates do
      state(:get_name, to: [:get_email])
      state(:get_email, to: [:confirm, :get_name])
      state(:confirm, to: [])
    end

    def default_state, do: :get_name
  end

  defmodule SettingsFlow do
    use ExGram.FSM.Flow, name: :settings

    defstates do
      state(:choose_language, to: [:save])
      state(:save, to: [])
    end

    def default_state, do: :choose_language
  end

  # --- Bot module ---

  defmodule DispatchBot do
    use ExGram.Bot, name: :dispatch_test_bot

    use ExGram.FSM,
      storage: ExGram.FSM.Storage.ETS,
      flows: [
        ExGram.FSM.DispatchTest.RegistrationFlow,
        ExGram.FSM.DispatchTest.SettingsFlow
      ],
      on_invalid_transition: :log

    command("register")
    command("settings")
    command("cancel")
    command("status")

    def handle({:command, :register, _}, context) do
      context
      |> start_flow(:registration)
      |> answer("What's your name?")
    end

    def handle({:command, :settings, _}, context) do
      context
      |> start_flow(:settings)
      |> answer("Choose language:")
    end

    def handle({:command, :cancel, _}, context) do
      context
      |> clear_flow()
      |> answer("Cancelled.")
    end

    def handle({:command, :status, _}, context) do
      flow = get_flow(context)
      state = get_state(context)
      answer(context, "Flow: #{inspect(flow)}, State: #{inspect(state)}")
    end

    # Registration flow handlers
    def handle({:text, name, _}, %{extra: %{fsm: %ExGram.FSM.State{flow: :registration, state: :get_name}}} = context) do
      context
      |> update_data(%{name: name})
      |> transition(:get_email)
      |> answer("Got it, #{name}! What's your email?")
    end

    def handle({:text, email, _}, %{extra: %{fsm: %ExGram.FSM.State{flow: :registration, state: :get_email}}} = context) do
      context
      |> update_data(%{email: email})
      |> transition(:confirm)
      |> answer("Please confirm.")
    end

    def handle({:text, "yes", _}, %{extra: %{fsm: %ExGram.FSM.State{flow: :registration, state: :confirm}}} = context) do
      data = get_data(context)

      context
      |> clear_flow()
      |> answer("Registered! Welcome, #{data.name}!")
    end

    # Settings flow handlers
    def handle(
          {:text, lang, _},
          %{extra: %{fsm: %ExGram.FSM.State{flow: :settings, state: :choose_language}}} = context
        ) do
      context
      |> update_data(%{language: lang})
      |> transition(:save)
      |> answer("Language set to #{lang}.")
    end

    # Catch-all
    def handle(_, context), do: context
  end

  # --- Test setup ---

  setup context do
    {bot_name, _} = ExGram.Test.start_bot(context, DispatchBot)

    ExGram.Test.stub(:send_message, %{chat: %{id: 0}, message_id: 1, text: ""})

    on_exit(fn ->
      try do
        :ets.delete_all_objects(ETS.table_name(:dispatch_test_bot))
      rescue
        ArgumentError -> :ok
      end
    end)

    {:ok, bot_name: bot_name}
  end

  # --- Helpers ---

  defp build_update(user_id, chat_id, text) do
    %ExGram.Model.Update{
      message: %ExGram.Model.Message{
        chat: %ExGram.Model.Chat{id: chat_id, type: "private"},
        date: System.system_time(:second),
        from: %ExGram.Model.User{
          first_name: "TestUser",
          id: user_id,
          is_bot: false
        },
        message_id: :erlang.unique_integer([:positive]),
        text: text
      },
      update_id: :erlang.unique_integer([:positive])
    }
  end

  defp sent_texts do
    ExGram.Test.get_calls()
    |> Enum.filter(fn {_verb, action, _body} -> action == :send_message end)
    |> Enum.map(fn {_verb, _action, body} -> body.text end)
  end

  # --- Tests ---

  describe "full dispatch pipeline" do
    test "/register starts registration flow and sends prompt", %{bot_name: bot_name} do
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/register"))

      assert sent_texts() == ["What's your name?"]
    end

    test "complete registration flow end-to-end", %{bot_name: bot_name} do
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/register"))
      ExGram.Test.push_update(bot_name, build_update(1, 1, "Alice"))
      ExGram.Test.push_update(bot_name, build_update(1, 1, "alice@example.com"))
      ExGram.Test.push_update(bot_name, build_update(1, 1, "yes"))

      assert sent_texts() == [
               "What's your name?",
               "Got it, Alice! What's your email?",
               "Please confirm.",
               "Registered! Welcome, Alice!"
             ]
    end

    test "/cancel mid-flow clears state and sends confirmation", %{bot_name: bot_name} do
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/register"))
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/cancel"))

      assert "Cancelled." in sent_texts()
    end

    test "/status shows current flow and state", %{bot_name: bot_name} do
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/register"))
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/status"))

      texts = sent_texts()
      status_text = Enum.find(texts, &String.contains?(&1, "Flow:"))
      assert status_text =~ "registration"
      assert status_text =~ "get_name"
    end

    test "/settings flow sends language prompt and transitions on input", %{bot_name: bot_name} do
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/settings"))
      ExGram.Test.push_update(bot_name, build_update(1, 1, "English"))

      assert sent_texts() == ["Choose language:", "Language set to English."]
    end
  end

  describe "dispatch key isolation" do
    test "different users have independent FSM states", %{bot_name: bot_name} do
      # User 1 starts registration
      ExGram.Test.push_update(bot_name, build_update(1, 1, "/register"))

      # User 2 checks status — should have no active flow
      ExGram.Test.push_update(bot_name, build_update(2, 2, "/status"))

      texts = sent_texts()
      status_text = Enum.find(texts, &String.contains?(&1, "Flow:"))
      assert status_text =~ "nil"
    end

    test "same user in different chats has independent FSM states", %{bot_name: bot_name} do
      # User 1 in chat 100 starts registration
      ExGram.Test.push_update(bot_name, build_update(1, 100, "/register"))

      # User 1 in chat 200 checks status — different chat key, no active flow
      ExGram.Test.push_update(bot_name, build_update(1, 200, "/status"))

      texts = sent_texts()
      status_text = Enum.find(texts, &String.contains?(&1, "Flow:"))
      assert status_text =~ "nil"
    end
  end
end
