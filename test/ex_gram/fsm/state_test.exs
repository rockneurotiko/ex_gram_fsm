defmodule ExGram.FSM.StateTest do
  use ExUnit.Case, async: true

  alias ExGram.FSM.State

  describe "%ExGram.FSM.State{}" do
    test "default struct has nil flow, nil state, and empty data" do
      state = %State{}
      assert state.flow == nil
      assert state.state == nil
      assert state.data == %{}
    end

    test "can be constructed with a flow atom" do
      state = %State{flow: :registration}
      assert state.flow == :registration
      assert state.state == nil
      assert state.data == %{}
    end

    test "can be constructed with custom state atom" do
      state = %State{state: :get_name}
      assert state.flow == nil
      assert state.state == :get_name
      assert state.data == %{}
    end

    test "can be constructed with flow, state, and data" do
      state = %State{data: %{name: "Alice"}, flow: :registration, state: :confirm}
      assert state.flow == :registration
      assert state.state == :confirm
      assert state.data == %{name: "Alice"}
    end

    test "can be constructed with custom data map" do
      data = %{age: 30, name: "Alice"}
      state = %State{data: data}
      assert state.flow == nil
      assert state.state == nil
      assert state.data == data
    end

    test "can be constructed with both state and data" do
      state = %State{data: %{email: "alice@example.com", name: "Alice"}, state: :confirm}
      assert state.state == :confirm
      assert state.data == %{email: "alice@example.com", name: "Alice"}
    end

    test "flow and state atoms can be any atom including nil" do
      assert %State{flow: :registration}.flow == :registration
      assert %State{flow: nil}.flow == nil
      assert %State{state: :idle}.state == :idle
      assert %State{state: nil}.state == nil
      assert %State{state: :some_complex_state}.state == :some_complex_state
    end

    test "struct can be updated with map syntax — preserves other fields" do
      original = %State{data: %{name: "Alice"}, flow: :registration, state: :get_name}
      updated = %{original | state: :get_email}
      assert updated.flow == :registration
      assert updated.state == :get_email
      assert updated.data == %{name: "Alice"}
    end

    test "clearing flow preserves data" do
      original = %State{data: %{x: 1}, flow: :registration, state: :get_name}
      cleared = %{original | data: %{}, flow: nil, state: nil}
      assert cleared.flow == nil
      assert cleared.state == nil
      assert cleared.data == %{}
    end
  end
end
