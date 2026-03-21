defmodule ExGram.FSM.StatesTest do
  use ExUnit.Case, async: true

  describe "defstates with transitions" do
    defmodule WithTransitions do
      use ExGram.FSM.States

      defstates do
        state(:idle, to: [:get_name])
        state(:get_name, to: [:get_email, :idle])
        state(:get_email, to: [:confirm, :get_name])
        state(:confirm, to: [:idle])
      end
    end

    test "states/0 returns all declared state atoms" do
      states = WithTransitions.states()
      assert :idle in states
      assert :get_name in states
      assert :get_email in states
      assert :confirm in states
      assert length(states) == 4
    end

    test "transitions/0 returns the correct map" do
      transitions = WithTransitions.transitions()
      assert is_map(transitions)
      assert transitions[:idle] == [:get_name]
      assert transitions[:get_name] == [:get_email, :idle]
      assert transitions[:get_email] == [:confirm, :get_name]
      assert transitions[:confirm] == [:idle]
    end

    test "transitions/0 only includes states with :to" do
      transitions = WithTransitions.transitions()
      assert map_size(transitions) == 4
    end
  end

  describe "defstates without :to (any transitions)" do
    defmodule WithoutTransitions do
      use ExGram.FSM.States

      defstates do
        state(:idle)
        state(:working)
        state(:done)
      end
    end

    test "states/0 returns all declared state atoms" do
      states = WithoutTransitions.states()
      assert :idle in states
      assert :working in states
      assert :done in states
      assert length(states) == 3
    end

    test "transitions/0 returns :any" do
      assert WithoutTransitions.transitions() == :any
    end
  end

  describe "mixed states (some with :to, some without)" do
    defmodule MixedStates do
      use ExGram.FSM.States

      defstates do
        state(:idle, to: [:working])
        state(:working)
        state(:done, to: [:idle])
      end
    end

    test "all states appear in states/0" do
      states = MixedStates.states()
      assert :idle in states
      assert :working in states
      assert :done in states
    end

    test "transitions/0 includes only states with :to" do
      transitions = MixedStates.transitions()
      assert is_map(transitions)
      assert transitions[:idle] == [:working]
      assert transitions[:done] == [:idle]
      # :working has no :to so it doesn't appear as a key in transitions
      refute Map.has_key?(transitions, :working)
    end
  end

  describe "direct behaviour implementation" do
    defmodule DirectImpl do
      @behaviour ExGram.FSM.States

      @impl true
      def states, do: [:a, :b, :c]

      @impl true
      def transitions do
        %{a: [:b], b: [:c], c: [:a]}
      end
    end

    test "states/0 returns declared states" do
      assert DirectImpl.states() == [:a, :b, :c]
    end

    test "transitions/0 returns the map" do
      assert DirectImpl.transitions() == %{a: [:b], b: [:c], c: [:a]}
    end
  end

  describe "behaviour callbacks are correct type" do
    test "states/0 returns a list of atoms" do
      states = ExGram.FSM.StatesTest.WithTransitions.states()
      assert is_list(states)
      assert Enum.all?(states, &is_atom/1)
    end

    test "transitions/0 returns either :any or a map" do
      result = ExGram.FSM.StatesTest.WithTransitions.transitions()
      assert is_map(result) or result == :any
    end
  end
end
