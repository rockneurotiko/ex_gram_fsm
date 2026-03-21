defmodule ExGram.FSM.IntegrationTest do
  use ExUnit.Case, async: false

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

  # --- Test bot module ---

  defmodule TestBot do
    use ExGram.Bot, name: :integration_test_bot

    use ExGram.FSM,
      storage: ExGram.FSM.Storage.ETS,
      flows: [
        ExGram.FSM.IntegrationTest.RegistrationFlow,
        ExGram.FSM.IntegrationTest.SettingsFlow
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

  setup do
    ETS.init(:integration_test_bot, [])

    on_exit(fn ->
      try do
        :ets.delete_all_objects(ETS.table_name(:integration_test_bot))
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  defp stored_state(key), do: ETS.get_state(:integration_test_bot, key)

  @flows_map %{
    registration: RegistrationFlow,
    settings: SettingsFlow
  }

  defp build_message_cnt(user_id, chat_id, text) do
    %ExGram.Cnt{
      name: :integration_test_bot,
      extra: %{},
      update: %ExGram.Model.Update{
        update_id: :erlang.unique_integer([:positive]),
        message: %ExGram.Model.Message{
          message_id: :erlang.unique_integer([:positive]),
          date: System.system_time(:second),
          chat: %ExGram.Model.Chat{id: chat_id, type: "private"},
          from: %ExGram.Model.User{
            id: user_id,
            is_bot: false,
            first_name: "TestUser"
          },
          text: text
        }
      }
    }
  end

  defp apply_fsm_middleware(cnt, opts \\ []) do
    middleware_opts =
      Keyword.merge(
        [
          storage: ETS,
          flows: @flows_map,
          on_invalid_transition: :log
        ],
        opts
      )

    ExGram.FSM.Middleware.call(cnt, middleware_opts)
  end

  # --- Tests ---

  describe "state persistence across updates" do
    test "flow + state written in one update is loaded in the next" do
      import ExGram.FSM.Helpers

      cnt1 = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      start_flow(cnt1, :registration)

      cnt2 = build_message_cnt(1, 1, "Alice") |> apply_fsm_middleware()
      assert cnt2.extra.fsm.flow == :registration
      assert cnt2.extra.fsm.state == :get_name
    end

    test "data written in one update is loaded in the next" do
      import ExGram.FSM.Helpers

      cnt1 = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      cnt1 |> start_flow(:registration) |> update_data(%{name: "Alice"})

      cnt2 = build_message_cnt(1, 1, "alice@example.com") |> apply_fsm_middleware()
      assert cnt2.extra.fsm.data == %{name: "Alice"}
    end
  end

  describe "state isolation between users" do
    test "two users don't interfere with each other" do
      import ExGram.FSM.Helpers

      # User 1 starts registration flow
      cnt1 = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      start_flow(cnt1, :registration)

      # User 2 still has no flow
      cnt2 = build_message_cnt(2, 2, "hello") |> apply_fsm_middleware()
      assert cnt2.extra.fsm.flow == nil
      assert cnt2.extra.fsm.state == nil

      # User 1's state is still registration
      stored_1 = stored_state({1, 1})
      assert stored_1.flow == :registration
      assert stored_1.state == :get_name
    end
  end

  describe "FSM key isolation" do
    test "same user in different chats has different FSM states" do
      import ExGram.FSM.Helpers

      cnt1 = build_message_cnt(1, 100, "hello") |> apply_fsm_middleware()
      start_flow(cnt1, :registration)

      cnt2 = build_message_cnt(1, 200, "hello") |> apply_fsm_middleware()
      # Different chat — different key — no flow active
      assert cnt2.extra.fsm.flow == nil

      assert stored_state({100, 1}).flow == :registration
      assert stored_state({200, 1}) == nil
    end
  end

  describe "full registration flow" do
    test "completes registration flow end-to-end" do
      import ExGram.FSM.Helpers

      # Start
      cnt = build_message_cnt(1, 1, "/register") |> apply_fsm_middleware()
      ctx = start_flow(cnt, :registration)
      assert get_flow(ctx) == :registration
      assert get_state(ctx) == :get_name

      # Name step
      cnt2 = build_message_cnt(1, 1, "Alice") |> apply_fsm_middleware()
      ctx2 = cnt2 |> update_data(%{name: "Alice"}) |> transition(:get_email)
      assert get_state(ctx2) == :get_email

      # Email step
      cnt3 = build_message_cnt(1, 1, "alice@example.com") |> apply_fsm_middleware()
      ctx3 = cnt3 |> update_data(%{email: "alice@example.com"}) |> transition(:confirm)
      assert get_state(ctx3) == :confirm

      # Confirm step — clear flow
      cnt4 = build_message_cnt(1, 1, "yes") |> apply_fsm_middleware()
      ctx4 = clear_flow(cnt4)
      assert get_flow(ctx4) == nil
      assert get_state(ctx4) == nil
    end
  end

  describe "flow conflict behavior" do
    test "starting a different flow while in one applies on_invalid_transition" do
      import ExGram.FSM.Helpers

      # User is in registration flow
      cnt1 = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      start_flow(cnt1, :registration)

      # Next update, they try to start settings — but registration is active
      cnt2 = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      # With :log policy, conflict is ignored, registration stays
      result = start_flow(cnt2, :settings)
      assert get_flow(result) == :registration
    end
  end

  describe "transition validation" do
    test "valid transition updates state within active flow" do
      import ExGram.FSM.Helpers

      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      ctx = start_flow(cnt, :registration)
      result = transition(ctx, :get_email)
      assert get_state(result) == :get_email
    end

    test "invalid transition with :log policy leaves state unchanged" do
      import ExGram.FSM.Helpers

      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      ctx = start_flow(cnt, :registration)

      # get_name -> confirm is not a valid transition
      result = transition(ctx, :confirm)
      assert get_state(result) == :get_name
    end

    test "transitions are validated per-flow (not cross-flow)" do
      import ExGram.FSM.Helpers

      # settings flow: choose_language -> save
      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      ctx = start_flow(cnt, :settings)
      assert get_state(ctx) == :choose_language

      result = transition(ctx, :save)
      assert get_state(result) == :save
    end
  end

  describe "clear_flow" do
    test "clear_flow resets to nil flow/state/data" do
      import ExGram.FSM.Helpers

      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()

      ctx =
        cnt
        |> start_flow(:registration)
        |> update_data(%{name: "Alice"})
        |> clear_flow()

      assert get_flow(ctx) == nil
      assert get_state(ctx) == nil
      assert get_data(ctx) == %{}
    end

    test "clear_flow removes data from storage" do
      import ExGram.FSM.Helpers

      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      cnt |> start_flow(:registration) |> update_data(%{name: "Alice"}) |> clear_flow()

      stored = stored_state({1, 1})
      assert stored == nil
    end
  end

  describe "set_state/3 escape hatch" do
    test "can force flow + state regardless of current active flow" do
      import ExGram.FSM.Helpers

      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      ctx = start_flow(cnt, :registration)

      # Admin forces settings flow directly
      result = set_state(ctx, :settings, :save)
      assert get_flow(result) == :settings
      assert get_state(result) == :save
    end
  end

  describe "FSM state pattern matching" do
    test "flow + state pattern is accessible in handle/2 second arg" do
      import ExGram.FSM.Helpers

      cnt = build_message_cnt(1, 1, "hello") |> apply_fsm_middleware()
      ctx = start_flow(cnt, :registration)

      assert match?(
               %{extra: %{fsm: %ExGram.FSM.State{flow: :registration, state: :get_name}}},
               ctx
             )
    end
  end
end
