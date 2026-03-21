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
      state = %State{flow: :registration, state: :confirm, data: %{name: "Alice"}}
      assert state.flow == :registration
      assert state.state == :confirm
      assert state.data == %{name: "Alice"}
    end

    test "can be constructed with custom data map" do
      data = %{name: "Alice", age: 30}
      state = %State{data: data}
      assert state.flow == nil
      assert state.state == nil
      assert state.data == data
    end

    test "can be constructed with both state and data" do
      state = %State{state: :confirm, data: %{name: "Alice", email: "alice@example.com"}}
      assert state.state == :confirm
      assert state.data == %{name: "Alice", email: "alice@example.com"}
    end

    test "flow and state atoms can be any atom including nil" do
      assert %State{flow: :registration}.flow == :registration
      assert %State{flow: nil}.flow == nil
      assert %State{state: :idle}.state == :idle
      assert %State{state: nil}.state == nil
      assert %State{state: :some_complex_state}.state == :some_complex_state
    end

    test "struct can be updated with map syntax — preserves other fields" do
      original = %State{flow: :registration, state: :get_name, data: %{name: "Alice"}}
      updated = %{original | state: :get_email}
      assert updated.flow == :registration
      assert updated.state == :get_email
      assert updated.data == %{name: "Alice"}
    end

    test "clearing flow preserves data" do
      original = %State{flow: :registration, state: :get_name, data: %{x: 1}}
      cleared = %{original | flow: nil, state: nil, data: %{}}
      assert cleared.flow == nil
      assert cleared.state == nil
      assert cleared.data == %{}
    end
  end
end
