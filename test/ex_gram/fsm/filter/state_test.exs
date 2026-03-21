defmodule ExGram.FSM.Filter.StateTest do
  use ExUnit.Case, async: true

  alias ExGram.FSM.Filter.State, as: StateFilter
  alias ExGram.FSM.State, as: FSMState

  # Build a minimal ExGram.Cnt with the given extra map
  defp ctx(extra \\ %{}) do
    %ExGram.Cnt{
      name: :test_bot,
      extra: extra,
      update: %ExGram.Model.Update{update_id: 1}
    }
  end

  defp ctx_with_state(state, data \\ %{}) do
    ctx(%{fsm: %FSMState{flow: :test_flow, state: state, data: data}})
  end

  describe "call/3 with atom opts (state matching)" do
    test "returns true when FSM state matches" do
      assert StateFilter.call(:whatever, ctx_with_state(:get_name), :get_name)
    end

    test "returns false when FSM state does not match" do
      refute StateFilter.call(:whatever, ctx_with_state(:get_email), :get_name)
    end

    test "matches nil state" do
      assert StateFilter.call(:whatever, ctx_with_state(nil), nil)
    end

    test "returns false when no FSM state in context" do
      refute StateFilter.call(:whatever, ctx(), :get_name)
    end

    test "returns false when extra has no :fsm key" do
      refute StateFilter.call(:whatever, ctx(%{other: :stuff}), :idle)
    end

    test "returns false for wrong state atom" do
      refute StateFilter.call(:whatever, ctx_with_state(:idle), :get_name)
    end
  end

  describe "call/3 with {key, value} opts (data matching)" do
    test "returns true when data key matches expected value" do
      ctx = ctx_with_state(:get_name, %{step: :confirm})
      assert StateFilter.call(:whatever, ctx, {:step, :confirm})
    end

    test "returns false when data key has different value" do
      ctx = ctx_with_state(:get_name, %{step: :other})
      refute StateFilter.call(:whatever, ctx, {:step, :confirm})
    end

    test "returns false when data key is missing" do
      ctx = ctx_with_state(:get_name, %{})
      refute StateFilter.call(:whatever, ctx, {:step, :confirm})
    end

    test "returns false when no FSM state in context" do
      refute StateFilter.call(:whatever, ctx(), {:step, :confirm})
    end

    test "works with any comparable value" do
      ctx = ctx_with_state(:any, %{count: 42})
      assert StateFilter.call(:whatever, ctx, {:count, 42})
      refute StateFilter.call(:whatever, ctx, {:count, 0})
    end
  end
end
