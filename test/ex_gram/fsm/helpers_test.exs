defmodule ExGram.FSM.HelpersTest do
  use ExUnit.Case, async: false

  import ExGram.FSM.Helpers

  alias ExGram.FSM.{State, Storage.ETS, TransitionError}

  @bot :helpers_test_bot

  setup do
    ETS.init(@bot, [])

    on_exit(fn ->
      try do
        :ets.delete_all_objects(ETS.table_name(@bot))
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  # Flow modules for testing
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
      state(:choose_language, to: [:confirm_language])
      state(:confirm_language, to: [:choose_language])
    end

    def default_state, do: :choose_language
  end

  defmodule AnyTransitionsFlow do
    use ExGram.FSM.Flow, name: :any_flow

    defstates do
      state(:a)
      state(:b)
      state(:c)
    end

    # No :to means :any transitions
  end

  defmodule NoDefaultFlow do
    use ExGram.FSM.Flow, name: :no_default

    defstates do
      state(:step_one, to: [:step_two])
      state(:step_two, to: [])
    end

    # default_state/0 not overridden → returns nil
  end

  defmodule CustomHandler do
    def handle_invalid(context, _from, _to) do
      %{
        context
        | extra: Map.put(context.extra, :fsm, %State{flow: :registration, state: :error_state})
      }
    end
  end

  @flows_map %{
    any_flow: AnyTransitionsFlow,
    no_default: NoDefaultFlow,
    registration: RegistrationFlow,
    settings: SettingsFlow
  }

  # Build a minimal context for testing helpers
  defp build_context(flow, state \\ nil, data \\ %{}, opts \\ []) do
    %ExGram.Cnt{
      extra: %{
        fsm: %State{data: data, flow: flow, state: state},
        fsm_flows: Keyword.get(opts, :flows, @flows_map),
        fsm_key: Keyword.get(opts, :key, {123, 456}),
        fsm_on_invalid_transition: Keyword.get(opts, :on_invalid, :raise),
        fsm_storage: Keyword.get(opts, :storage, ETS)
      },
      name: @bot
    }
  end

  # Build a context with no FSM info (middleware didn't run)
  defp bare_context do
    %ExGram.Cnt{extra: %{}, name: @bot}
  end

  # --- get_flow/1 ---

  describe "get_flow/1" do
    test "returns nil when no FSM state in context" do
      assert get_flow(bare_context()) == nil
    end

    test "returns nil when flow is nil" do
      assert get_flow(build_context(nil)) == nil
    end

    test "returns the active flow atom" do
      assert get_flow(build_context(:registration)) == :registration
    end

    test "returns flow for various atoms" do
      assert get_flow(build_context(:settings)) == :settings
      assert get_flow(build_context(:any_flow)) == :any_flow
    end
  end

  # --- get_state/1 ---

  describe "get_state/1" do
    test "returns nil when no FSM state in context" do
      assert get_state(bare_context()) == nil
    end

    test "returns nil when state is nil" do
      assert get_state(build_context(nil, nil)) == nil
    end

    test "returns the state atom" do
      assert get_state(build_context(:registration, :get_name)) == :get_name
    end

    test "returns state for various atoms" do
      assert get_state(build_context(:settings, :choose_language)) == :choose_language
      assert get_state(build_context(:registration, :confirm)) == :confirm
    end
  end

  # --- get_data/1 ---

  describe "get_data/1" do
    test "returns empty map when no FSM state in context" do
      assert get_data(bare_context()) == %{}
    end

    test "returns empty map when data is empty" do
      assert get_data(build_context(nil, nil, %{})) == %{}
    end

    test "returns the data map" do
      data = %{email: "alice@example.com", name: "Alice"}
      assert get_data(build_context(:registration, :confirm, data)) == data
    end
  end

  # --- start_flow/2 ---

  describe "start_flow/2" do
    test "starts flow with default_state when no flow is active" do
      ctx = build_context(nil)
      result = start_flow(ctx, :registration)
      assert get_flow(result) == :registration
      assert get_state(result) == :get_name
      assert get_data(result) == %{}
    end

    test "clears previous data when starting a flow" do
      ctx = build_context(nil, nil, %{old: "data"})
      result = start_flow(ctx, :registration)
      assert get_data(result) == %{}
    end

    test "starts flow with nil state when no default_state defined" do
      ctx = build_context(nil)
      result = start_flow(ctx, :no_default)
      assert get_flow(result) == :no_default
      assert get_state(result) == nil
    end

    test "re-starts the same flow (resets state + data)" do
      ctx = build_context(:registration, :confirm, %{name: "Alice"})
      result = start_flow(ctx, :registration)
      # Flow is the same — re-starts to default_state with empty data
      assert get_flow(result) == :registration
      assert get_state(result) == :get_name
      assert get_data(result) == %{}
    end

    test "persists new flow + state to storage" do
      ctx = build_context(nil)
      start_flow(ctx, :registration)
      stored = ETS.get_state(@bot, {123, 456})
      assert stored.flow == :registration
      assert stored.state == :get_name
    end

    test "raises ArgumentError for unregistered flow" do
      ctx = build_context(nil)

      assert_raise ArgumentError, ~r/not registered/, fn ->
        start_flow(ctx, :unknown_flow)
      end
    end

    test "applies on_invalid_transition when different flow is active (:raise)" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :raise)

      assert_raise TransitionError, fn ->
        start_flow(ctx, :settings)
      end
    end

    test "applies on_invalid_transition when different flow is active (:ignore)" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :ignore)
      result = start_flow(ctx, :settings)
      # Flow unchanged — conflict was ignored
      assert get_flow(result) == :registration
      assert get_state(result) == :get_name
    end

    test "applies on_invalid_transition when different flow is active (:log)" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :log)
      result = start_flow(ctx, :settings)
      # Flow unchanged — conflict was logged
      assert get_flow(result) == :registration
    end
  end

  # --- set_state/2 ---

  describe "set_state/2" do
    test "sets state within the active flow" do
      ctx = build_context(:registration, :get_name)
      result = set_state(ctx, :get_email)
      assert get_state(result) == :get_email
      assert get_flow(result) == :registration
    end

    test "preserves existing data when changing state" do
      ctx = build_context(:registration, :get_name, %{name: "Alice"})
      result = set_state(ctx, :get_email)
      assert get_state(result) == :get_email
      assert get_data(result) == %{name: "Alice"}
    end

    test "writes to storage" do
      ctx = build_context(:registration, :get_name)
      set_state(ctx, :get_email)
      stored = ETS.get_state(@bot, {123, 456})
      assert stored.state == :get_email
    end

    test "bypasses transition validation — always succeeds within active flow" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :raise)
      # confirm is not reachable from get_name directly per RegistrationFlow
      # but set_state/2 bypasses validation
      result = set_state(ctx, :confirm)
      assert get_state(result) == :confirm
    end

    test "applies on_invalid_transition when no flow is active (:raise)" do
      ctx = build_context(nil, nil, %{}, on_invalid: :raise)

      assert_raise TransitionError, fn ->
        set_state(ctx, :get_name)
      end
    end

    test "applies on_invalid_transition when no flow is active (:ignore)" do
      ctx = build_context(nil, nil, %{}, on_invalid: :ignore)
      result = set_state(ctx, :get_name)
      assert get_state(result) == nil
    end

    test "applies on_invalid_transition when no flow is active (:log)" do
      ctx = build_context(nil, nil, %{}, on_invalid: :log)
      result = set_state(ctx, :get_name)
      assert get_state(result) == nil
    end
  end

  # --- set_state/3 ---

  describe "set_state/3 (force escape hatch)" do
    test "forces flow + state regardless of current flow" do
      ctx = build_context(:registration, :get_name)
      result = set_state(ctx, :settings, :choose_language)
      assert get_flow(result) == :settings
      assert get_state(result) == :choose_language
    end

    test "forces flow + state even when no flow is active" do
      ctx = build_context(nil)
      result = set_state(ctx, :registration, :confirm)
      assert get_flow(result) == :registration
      assert get_state(result) == :confirm
    end

    test "preserves existing data" do
      ctx = build_context(:registration, :get_name, %{name: "Alice"})
      result = set_state(ctx, :settings, :choose_language)
      assert get_data(result) == %{name: "Alice"}
    end

    test "writes new flow + state to storage" do
      ctx = build_context(:registration, :get_name)
      set_state(ctx, :settings, :choose_language)
      stored = ETS.get_state(@bot, {123, 456})
      assert stored.flow == :settings
      assert stored.state == :choose_language
    end

    test "raises ArgumentError for unregistered flow" do
      ctx = build_context(:registration, :get_name)

      assert_raise ArgumentError, ~r/not registered/, fn ->
        set_state(ctx, :unknown, :step_one)
      end
    end
  end

  # --- transition/2 ---

  describe "transition/2" do
    test "sets state when no flow is active and flows map is empty" do
      ctx = %ExGram.Cnt{
        extra: %{
          fsm: %State{data: %{}, flow: nil, state: nil},
          fsm_flows: %{},
          fsm_key: {123, 456},
          fsm_on_invalid_transition: :raise,
          fsm_storage: ETS
        },
        name: @bot
      }

      # No flows registered means no validation module → allow all
      result = transition(ctx, :any_state)
      assert get_state(result) == :any_state
    end

    test "sets state when transitions are :any (no :to in defstates)" do
      ctx = build_context(:any_flow, :a)
      result = transition(ctx, :c)
      assert get_state(result) == :c
    end

    test "sets state for valid transition in active flow" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :raise)
      result = transition(ctx, :get_email)
      assert get_state(result) == :get_email
    end

    test "writes to storage on valid transition" do
      ctx = build_context(:registration, :get_name)
      transition(ctx, :get_email)
      stored = ETS.get_state(@bot, {123, 456})
      assert stored.state == :get_email
    end

    test "raises TransitionError on invalid transition with :raise policy" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :raise)

      assert_raise TransitionError, fn ->
        transition(ctx, :confirm)
      end
    end

    test "TransitionError has correct from/to fields" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :raise)

      error =
        assert_raise TransitionError, fn ->
          transition(ctx, :confirm)
        end

      assert error.from == :get_name
      assert error.to == :confirm
    end

    test "returns context unchanged with :log policy on invalid transition" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :log)
      result = transition(ctx, :confirm)
      assert get_state(result) == :get_name
    end

    test "returns context unchanged with :ignore policy on invalid transition" do
      ctx = build_context(:registration, :get_name, %{}, on_invalid: :ignore)
      result = transition(ctx, :confirm)
      assert get_state(result) == :get_name
    end

    test "calls custom handler with {Module, :function} policy" do
      ctx =
        build_context(:registration, :get_name, %{},
          on_invalid: {ExGram.FSM.HelpersTest.CustomHandler, :handle_invalid}
        )

      result = transition(ctx, :confirm)
      # Our custom handler sets state to :error_state
      assert get_state(result) == :error_state
    end

    test "validates using the current flow's transitions (not another flow's)" do
      # settings flow: choose_language -> confirm_language only
      ctx = build_context(:settings, :choose_language, %{}, on_invalid: :raise)

      # valid for settings
      result = transition(ctx, :confirm_language)
      assert get_state(result) == :confirm_language

      # confirm_language is not valid from choose_language in registration flow
      # but we're in settings, so this should be fine
    end
  end

  # --- update_data/2 ---

  describe "update_data/2" do
    test "merges new data into existing data in context" do
      ctx = build_context(:registration, :get_name, %{name: "Alice"})
      result = update_data(ctx, %{email: "alice@example.com"})
      assert get_data(result) == %{email: "alice@example.com", name: "Alice"}
    end

    test "overwrites existing keys" do
      ctx = build_context(:registration, :get_name, %{count: 1})
      result = update_data(ctx, %{count: 2})
      assert get_data(result)[:count] == 2
    end

    test "works on empty data" do
      ctx = build_context(:registration, :get_name, %{})
      result = update_data(ctx, %{name: "Bob"})
      assert get_data(result) == %{name: "Bob"}
    end

    test "persists data to storage" do
      ctx = build_context(:registration, :get_name, %{name: "Alice"})
      update_data(ctx, %{email: "alice@example.com"})
      stored = ETS.get_state(@bot, {123, 456})
      assert stored.data == %{email: "alice@example.com", name: "Alice"}
    end

    test "preserves flow and state atom" do
      ctx = build_context(:registration, :get_name, %{})
      result = update_data(ctx, %{name: "Eve"})
      assert get_flow(result) == :registration
      assert get_state(result) == :get_name
    end
  end

  # --- clear_flow/1 ---

  describe "clear_flow/1" do
    test "resets flow to nil, state to nil, and data to empty" do
      ctx = build_context(:registration, :confirm, %{email: "alice@example.com", name: "Alice"})
      result = clear_flow(ctx)
      assert get_flow(result) == nil
      assert get_state(result) == nil
      assert get_data(result) == %{}
    end

    test "removes entry from storage" do
      ETS.set_state(@bot, {123, 456}, %State{data: %{x: 1}, flow: :registration, state: :confirm})
      ctx = build_context(:registration, :confirm, %{x: 1})
      clear_flow(ctx)
      assert ETS.get_state(@bot, {123, 456}) == nil
    end

    test "is safe to call when no flow is active" do
      ctx = build_context(nil, nil, %{})
      result = clear_flow(ctx)
      assert get_flow(result) == nil
      assert get_state(result) == nil
    end
  end

  # --- Pipeline chaining ---

  describe "pipeline chaining" do
    test "helpers can be chained together" do
      ctx = build_context(nil)

      result =
        ctx
        |> start_flow(:registration)
        |> update_data(%{started: true})
        |> transition(:get_email)
        |> update_data(%{name: "Alice"})

      assert get_flow(result) == :registration
      assert get_state(result) == :get_email
      assert get_data(result) == %{name: "Alice", started: true}
    end

    test "clear_flow can be called after a full flow" do
      ctx = build_context(nil)

      result =
        ctx
        |> start_flow(:registration)
        |> update_data(%{name: "Alice"})
        |> clear_flow()

      assert get_flow(result) == nil
      assert get_state(result) == nil
      assert get_data(result) == %{}
    end
  end
end
