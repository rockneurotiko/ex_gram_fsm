defmodule ExGram.FSM.FlowTest do
  use ExUnit.Case, async: true

  # --- Test flow modules ---

  defmodule FullFlow do
    use ExGram.FSM.Flow, name: :full_flow

    defstates do
      state(:step_a, to: [:step_b])
      state(:step_b, to: [:step_c, :step_a])
      state(:step_c, to: [])
    end

    def default_state, do: :step_a
  end

  defmodule NoDefaultFlow do
    use ExGram.FSM.Flow, name: :no_default_flow

    defstates do
      state(:first, to: [:second])
      state(:second, to: [])
    end

    # default_state/0 not overridden — returns nil
  end

  defmodule AnyTransitionsFlow do
    use ExGram.FSM.Flow, name: :any_transitions_flow

    defstates do
      state(:x)
      state(:y)
      state(:z)
    end

    # No :to on any state — transitions/0 returns :any
  end

  defmodule SingleStateFlow do
    use ExGram.FSM.Flow, name: :single_state_flow

    defstates do
      state(:only_state, to: [])
    end
  end

  # --- flow_name/0 ---

  describe "flow_name/0" do
    test "returns the configured name atom" do
      assert FullFlow.flow_name() == :full_flow
    end

    test "each module has its own unique name" do
      assert NoDefaultFlow.flow_name() == :no_default_flow
      assert AnyTransitionsFlow.flow_name() == :any_transitions_flow
      assert SingleStateFlow.flow_name() == :single_state_flow
    end
  end

  # --- default_state/0 ---

  describe "default_state/0" do
    test "returns the overridden default state" do
      assert FullFlow.default_state() == :step_a
    end

    test "returns nil when not overridden" do
      assert NoDefaultFlow.default_state() == nil
      assert AnyTransitionsFlow.default_state() == nil
    end
  end

  # --- states/0 ---

  describe "states/0" do
    test "returns all declared state atoms" do
      states = FullFlow.states()
      assert :step_a in states
      assert :step_b in states
      assert :step_c in states
    end

    test "returns states in declaration order" do
      assert FullFlow.states() == [:step_a, :step_b, :step_c]
    end

    test "single state" do
      assert SingleStateFlow.states() == [:only_state]
    end

    test "states with no :to" do
      states = AnyTransitionsFlow.states()
      assert :x in states
      assert :y in states
      assert :z in states
    end
  end

  # --- transitions/0 ---

  describe "transitions/0" do
    test "returns transitions map when :to is specified" do
      transitions = FullFlow.transitions()
      assert is_map(transitions)
      assert transitions[:step_a] == [:step_b]
      assert transitions[:step_b] == [:step_c, :step_a]
      assert transitions[:step_c] == []
    end

    test "returns :any when no :to is specified on any state" do
      assert AnyTransitionsFlow.transitions() == :any
    end

    test "transitions map for single state with empty :to" do
      assert SingleStateFlow.transitions() == %{only_state: []}
    end
  end

  # --- Behaviour callbacks implemented ---

  describe "ExGram.FSM.Flow behaviour" do
    test "FullFlow implements all 4 callbacks" do
      assert function_exported?(FullFlow, :flow_name, 0)
      assert function_exported?(FullFlow, :default_state, 0)
      assert function_exported?(FullFlow, :states, 0)
      assert function_exported?(FullFlow, :transitions, 0)
    end

    test "NoDefaultFlow implements all 4 callbacks" do
      assert function_exported?(NoDefaultFlow, :flow_name, 0)
      assert function_exported?(NoDefaultFlow, :default_state, 0)
      assert function_exported?(NoDefaultFlow, :states, 0)
      assert function_exported?(NoDefaultFlow, :transitions, 0)
    end
  end

  # --- Missing :name option raises at compile time ---

  describe "missing :name option" do
    test "raises CompileError when :name is not provided" do
      assert_raise CompileError, ~r/`:name` option is required/, fn ->
        defmodule MissingName do
          use ExGram.FSM.Flow
        end
      end
    end
  end
end
