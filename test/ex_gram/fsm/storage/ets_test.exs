defmodule ExGram.FSM.Storage.ETSTest do
  use ExUnit.Case, async: false

  alias ExGram.FSM.State
  alias ExGram.FSM.Storage.ETS

  @bot :ets_test_bot

  # Use a unique table per test run to avoid cross-test contamination
  # Since async: false and ETS uses named table, we must clean up between tests
  setup do
    # Ensure the per-bot table exists and is clean for each test
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

  describe "init/2" do
    test "creates the ETS table and returns :ok" do
      # Table was already created in setup; calling again should be idempotent
      assert ETS.init(@bot, []) == :ok
    end

    test "is idempotent - can be called multiple times without crash" do
      assert ETS.init(@bot, []) == :ok
      assert ETS.init(@bot, []) == :ok
      assert ETS.init(@bot, []) == :ok
    end

    test "different bot names get different tables" do
      assert ETS.init(:bot_a, []) == :ok
      assert ETS.init(:bot_b, []) == :ok
      assert ETS.table_name(:bot_a) != ETS.table_name(:bot_b)

      on_exit(fn ->
        try do
          :ets.delete_all_objects(ETS.table_name(:bot_a))
          :ets.delete_all_objects(ETS.table_name(:bot_b))
        rescue
          ArgumentError -> :ok
        end
      end)
    end
  end

  describe "get_state/2" do
    test "returns nil for unknown key" do
      assert ETS.get_state(@bot, {999, 999}) == nil
    end

    test "returns the stored state after set_state" do
      key = {1, 1}
      state = %State{flow: :registration, state: :get_name, data: %{name: "Alice"}}
      ETS.set_state(@bot, key, state)
      assert ETS.get_state(@bot, key) == state
    end

    test "roundtrip preserves struct exactly including flow field" do
      key = {100, 200}

      state = %State{
        flow: :registration,
        state: :confirm,
        data: %{name: "Bob", email: "bob@example.com"}
      }

      :ok = ETS.set_state(@bot, key, state)
      result = ETS.get_state(@bot, key)
      assert result == state
      assert result.flow == :registration
      assert result.state == :confirm
      assert result.data == %{name: "Bob", email: "bob@example.com"}
    end

    test "state for one bot does not bleed into another bot" do
      ETS.init(:bot_x, [])
      ETS.init(:bot_y, [])
      key = {1, 1}
      state = %State{flow: :registration, state: :get_name}
      ETS.set_state(:bot_x, key, state)
      assert ETS.get_state(:bot_x, key) == state
      assert ETS.get_state(:bot_y, key) == nil

      on_exit(fn ->
        try do
          :ets.delete_all_objects(ETS.table_name(:bot_x))
          :ets.delete_all_objects(ETS.table_name(:bot_y))
        rescue
          ArgumentError -> :ok
        end
      end)
    end
  end

  describe "set_state/3" do
    test "returns :ok on success" do
      key = {1, 1}
      assert ETS.set_state(@bot, key, %State{}) == :ok
    end

    test "overwrites existing state" do
      key = {1, 1}
      ETS.set_state(@bot, key, %State{flow: :registration, state: :idle})
      ETS.set_state(@bot, key, %State{flow: :registration, state: :get_name, data: %{x: 1}})
      result = ETS.get_state(@bot, key)
      assert result.state == :get_name
      assert result.data == %{x: 1}
    end
  end

  describe "get_data/2" do
    test "returns nil for unknown key" do
      assert ETS.get_data(@bot, {999, 999}) == nil
    end

    test "returns the data map for existing key" do
      key = {2, 2}
      data = %{name: "Charlie", step: 3}
      ETS.set_state(@bot, key, %State{flow: :registration, state: :working, data: data})
      assert ETS.get_data(@bot, key) == data
    end

    test "returns empty map when state has no data" do
      key = {1, 1}
      ETS.set_state(@bot, key, %State{flow: :registration, state: :idle})
      assert ETS.get_data(@bot, key) == %{}
    end
  end

  describe "set_data/3" do
    test "replaces data, preserves state atom" do
      key = {1, 1}
      ETS.set_state(@bot, key, %State{flow: :registration, state: :get_name, data: %{old: true}})
      ETS.set_data(@bot, key, %{new: true})
      result = ETS.get_state(@bot, key)
      assert result.state == :get_name
      assert result.data == %{new: true}
    end

    test "creates state with nil state and given data if key doesn't exist" do
      key = {1, 1}
      ETS.set_data(@bot, key, %{created: true})
      result = ETS.get_state(@bot, key)
      assert result.state == nil
      assert result.data == %{created: true}
    end
  end

  describe "update_data/3" do
    test "merges new_data into existing data" do
      key = {1, 1}
      ETS.set_state(@bot, key, %State{flow: :registration, state: :get_email, data: %{name: "Dave"}})
      ETS.update_data(@bot, key, %{email: "dave@example.com"})
      result = ETS.get_state(@bot, key)
      assert result.data == %{name: "Dave", email: "dave@example.com"}
    end

    test "new keys added, existing keys preserved" do
      key = {1, 1}
      ETS.set_state(@bot, key, %State{data: %{a: 1, b: 2}})
      ETS.update_data(@bot, key, %{b: 99, c: 3})
      # b is overwritten, a is preserved, c is added
      assert ETS.get_data(@bot, key) == %{a: 1, b: 99, c: 3}
    end

    test "on nil/unknown key, creates state with nil state and given data" do
      key = {999, 999}
      ETS.update_data(@bot, key, %{created: true})
      result = ETS.get_state(@bot, key)
      assert result.state == nil
      assert result.data == %{created: true}
    end
  end

  describe "clear/2" do
    test "removes the entry so get_state returns nil" do
      key = {1, 1}
      ETS.set_state(@bot, key, %State{flow: :registration, state: :idle})
      assert ETS.clear(@bot, key) == :ok
      assert ETS.get_state(@bot, key) == nil
    end

    test "returns :ok even when key doesn't exist" do
      assert ETS.clear(@bot, {999, 999}) == :ok
    end

    test "clear doesn't affect other keys" do
      ETS.set_state(@bot, {1, 1}, %State{flow: :registration, state: :a})
      ETS.set_state(@bot, {2, 2}, %State{flow: :settings, state: :b})
      ETS.clear(@bot, {1, 1})
      assert ETS.get_state(@bot, {1, 1}) == nil
      assert ETS.get_state(@bot, {2, 2}).state == :b
    end
  end
end
