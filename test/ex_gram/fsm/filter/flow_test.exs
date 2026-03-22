defmodule ExGram.FSM.Filter.FlowTest do
  use ExUnit.Case, async: true

  alias ExGram.FSM.Filter.Flow, as: FlowFilter
  alias ExGram.FSM.State, as: FSMState

  # Build a minimal ExGram.Cnt with the given extra map
  defp ctx(extra \\ %{}) do
    %ExGram.Cnt{
      extra: extra,
      name: :test_bot,
      update: %ExGram.Model.Update{update_id: 1}
    }
  end

  defp ctx_with_flow(flow, state \\ nil) do
    ctx(%{fsm: %FSMState{data: %{}, flow: flow, state: state}})
  end

  describe "call/3 - flow name matching" do
    test "returns true when FSM flow matches" do
      assert FlowFilter.call(:whatever, ctx_with_flow(:registration), :registration)
    end

    test "returns false when FSM flow does not match" do
      refute FlowFilter.call(:whatever, ctx_with_flow(:settings), :registration)
    end

    test "matches nil flow (no active flow)" do
      assert FlowFilter.call(:whatever, ctx_with_flow(nil), nil)
    end

    test "returns false when no FSM state in context" do
      refute FlowFilter.call(:whatever, ctx(), :registration)
    end

    test "returns false when extra has no :fsm key" do
      refute FlowFilter.call(:whatever, ctx(%{other: :stuff}), :registration)
    end

    test "returns false for wrong flow atom" do
      refute FlowFilter.call(:whatever, ctx_with_flow(:settings), :registration)
    end

    test "works with different flow name atoms" do
      assert FlowFilter.call(:whatever, ctx_with_flow(:on_boarding), :on_boarding)
      assert FlowFilter.call(:whatever, ctx_with_flow(:checkout), :checkout)
      refute FlowFilter.call(:whatever, ctx_with_flow(:checkout), :on_boarding)
    end

    test "state value is irrelevant — only flow is checked" do
      ctx_a = ctx_with_flow(:registration, :get_name)
      ctx_b = ctx_with_flow(:registration, :confirm)
      assert FlowFilter.call(:whatever, ctx_a, :registration)
      assert FlowFilter.call(:whatever, ctx_b, :registration)
    end
  end
end
