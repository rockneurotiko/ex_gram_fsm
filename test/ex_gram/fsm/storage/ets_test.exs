defmodule ExGram.FSM.Storage.ETSTest do
  use ExUnit.Case, async: false

  alias ExGram.FSM.State
  alias ExGram.FSM.Storage.ETS

  # Use a unique table per test run to avoid cross-test contamination
  # Since async: false and ETS uses named table, we must clean up between tests
  setup do
    # Ensure the default table exists and is clean for each test
    ETS.init([])

    # Clear test keys used in tests
    on_exit(fn ->
      try do
        :ets.delete_all_objects(:ex_gram_fsm_state)
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  describe "init/1" do
    test "creates the ETS table and returns :ok" do
      # Table was already created in setup; calling again should be idempotent
      assert ETS.init([]) == :ok
    end

    test "is idempotent - can be called multiple times without crash" do
      assert ETS.init([]) == :ok
      assert ETS.init([]) == :ok
      assert ETS.init([]) == :ok
    end
  end

  describe "get_state/1" do
    test "returns nil for unknown key" do
      assert ETS.get_state({999, 999}) == nil
    end

    test "returns the stored state after set_state" do
      key = {1, 1}
      state = %State{flow: :registration, state: :get_name, data: %{name: "Alice"}}
      ETS.set_state(key, state)
      assert ETS.get_state(key) == state
    end

    test "roundtrip preserves struct exactly including flow field" do
      key = {100, 200}

      state = %State{
        flow: :registration,
        state: :confirm,
        data: %{name: "Bob", email: "bob@example.com"}
      }

      :ok = ETS.set_state(key, state)
      result = ETS.get_state(key)
      assert result == state
      assert result.flow == :registration
      assert result.state == :confirm
      assert result.data == %{name: "Bob", email: "bob@example.com"}
    end
  end

  describe "set_state/2" do
    test "returns :ok on success" do
      key = {1, 1}
      assert ETS.set_state(key, %State{}) == :ok
    end

    test "overwrites existing state" do
      key = {1, 1}
      ETS.set_state(key, %State{flow: :registration, state: :idle})
      ETS.set_state(key, %State{flow: :registration, state: :get_name, data: %{x: 1}})
      result = ETS.get_state(key)
      assert result.state == :get_name
      assert result.data == %{x: 1}
    end
  end

  describe "get_data/1" do
    test "returns nil for unknown key" do
      assert ETS.get_data({999, 999}) == nil
    end

    test "returns the data map for existing key" do
      key = {2, 2}
      data = %{name: "Charlie", step: 3}
      ETS.set_state(key, %State{flow: :registration, state: :working, data: data})
      assert ETS.get_data(key) == data
    end

    test "returns empty map when state has no data" do
      key = {1, 1}
      ETS.set_state(key, %State{flow: :registration, state: :idle})
      assert ETS.get_data(key) == %{}
    end
  end

  describe "set_data/2" do
    test "replaces data, preserves state atom" do
      key = {1, 1}
      ETS.set_state(key, %State{flow: :registration, state: :get_name, data: %{old: true}})
      ETS.set_data(key, %{new: true})
      result = ETS.get_state(key)
      assert result.state == :get_name
      assert result.data == %{new: true}
    end

    test "creates state with nil state and given data if key doesn't exist" do
      key = {1, 1}
      ETS.set_data(key, %{created: true})
      result = ETS.get_state(key)
      assert result.state == nil
      assert result.data == %{created: true}
    end
  end

  describe "update_data/2" do
    test "merges new_data into existing data" do
      key = {1, 1}
      ETS.set_state(key, %State{flow: :registration, state: :get_email, data: %{name: "Dave"}})
      ETS.update_data(key, %{email: "dave@example.com"})
      result = ETS.get_state(key)
      assert result.data == %{name: "Dave", email: "dave@example.com"}
    end

    test "new keys added, existing keys preserved" do
      key = {1, 1}
      ETS.set_state(key, %State{data: %{a: 1, b: 2}})
      ETS.update_data(key, %{b: 99, c: 3})
      # b is overwritten, a is preserved, c is added
      assert ETS.get_data(key) == %{a: 1, b: 99, c: 3}
    end

    test "on nil/unknown key, creates state with nil state and given data" do
      key = {999, 999}
      ETS.update_data(key, %{created: true})
      result = ETS.get_state(key)
      assert result.state == nil
      assert result.data == %{created: true}
    end
  end

  describe "clear/1" do
    test "removes the entry so get_state returns nil" do
      key = {1, 1}
      ETS.set_state(key, %State{flow: :registration, state: :idle})
      assert ETS.clear(key) == :ok
      assert ETS.get_state(key) == nil
    end

    test "returns :ok even when key doesn't exist" do
      assert ETS.clear({999, 999}) == :ok
    end

    test "clear doesn't affect other keys" do
      ETS.set_state({1, 1}, %State{flow: :registration, state: :a})
      ETS.set_state({2, 2}, %State{flow: :settings, state: :b})
      ETS.clear({1, 1})
      assert ETS.get_state({1, 1}) == nil
      assert ETS.get_state({2, 2}).state == :b
    end
  end
end
