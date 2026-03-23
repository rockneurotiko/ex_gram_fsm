defmodule ExGram.FSM.Filter.InFlowTest do
  use ExUnit.Case, async: true

  alias ExGram.FSM.Filter.InFlow, as: InFlowFilter
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

  describe "call/3" do
    test "returns true when a flow is active" do
      assert InFlowFilter.call(:whatever, ctx_with_flow(:registration), nil)
    end

    test "returns true for any non-nil flow name" do
      assert InFlowFilter.call(:whatever, ctx_with_flow(:settings), nil)
      assert InFlowFilter.call(:whatever, ctx_with_flow(:on_boarding), nil)
    end

    test "returns false when flow is nil (no active flow)" do
      refute InFlowFilter.call(:whatever, ctx_with_flow(nil), nil)
    end

    test "returns false when extra has no :fsm key" do
      refute InFlowFilter.call(:whatever, ctx(%{other: :stuff}), nil)
    end

    test "returns false when extra is empty" do
      refute InFlowFilter.call(:whatever, ctx(), nil)
    end

    test "state value is irrelevant - only flow presence is checked" do
      assert InFlowFilter.call(:whatever, ctx_with_flow(:registration, :get_name), nil)
      assert InFlowFilter.call(:whatever, ctx_with_flow(:registration, :confirm), nil)
      assert InFlowFilter.call(:whatever, ctx_with_flow(:registration, nil), nil)
    end
  end

  describe "format_filter/1" do
    test "returns the InFlow label" do
      assert InFlowFilter.format_filter(nil) == "InFlow"
    end
  end
end
