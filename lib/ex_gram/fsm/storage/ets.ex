defmodule ExGram.FSM.Storage.ETS do
  @moduledoc """
  Default in-memory FSM storage using ETS.

  Suitable for development and single-node deployments.
  **State is lost on application restart.**

  ## Concurrency

  Single-key ETS operations (`get_state`, `set_state`, `clear`) are atomic.
  However, `update_data/2` and `set_data/2` are read-modify-write operations
  and are **not atomic**. If you need atomicity for concurrent updates to the
  same key, use a storage backend with proper transactions (Postgres, Mnesia, etc.).

  ## Table ownership

  The ETS table is created as `:public` and `:named_table` in `init/1`.
  The table is owned by the process that first calls `init/1`.
  If that process dies, the table is destroyed.

  For production use, consider wrapping the table in a GenServer in your
  supervision tree to ensure stable ownership.

  ## Configuration

  The table name can be configured via the `:ets_table` option passed through
  `use ExGram.FSM`:

      use ExGram.FSM, storage: ExGram.FSM.Storage.ETS, ets_table: :my_custom_table
  """

  @behaviour ExGram.FSM.Storage

  @default_table :ex_gram_fsm_state

  @impl true
  @spec init(keyword()) :: :ok
  def init(opts \\ []) do
    table = Keyword.get(opts, :ets_table, @default_table)

    try do
      :ets.new(table, [:set, :public, :named_table, {:read_concurrency, true}])
      :ok
    rescue
      ArgumentError -> :ok
    end
  end

  @impl true
  @spec get_state(ExGram.FSM.Storage.key()) :: ExGram.FSM.State.t() | nil
  def get_state(key) do
    table = get_table_name()

    case :ets.lookup(table, key) do
      [{^key, state}] -> state
      [] -> nil
    end
  end

  @impl true
  @spec set_state(ExGram.FSM.Storage.key(), ExGram.FSM.State.t()) :: :ok
  def set_state(key, %ExGram.FSM.State{} = state) do
    :ets.insert(get_table_name(), {key, state})
    :ok
  end

  @impl true
  @spec get_data(ExGram.FSM.Storage.key()) :: map() | nil
  def get_data(key) do
    case get_state(key) do
      %ExGram.FSM.State{data: data} -> data
      nil -> nil
    end
  end

  @impl true
  @spec set_data(ExGram.FSM.Storage.key(), map()) :: :ok
  def set_data(key, data) when is_map(data) do
    state = get_state(key) || %ExGram.FSM.State{}
    set_state(key, %{state | data: data})
  end

  @impl true
  @spec update_data(ExGram.FSM.Storage.key(), map()) :: :ok
  def update_data(key, new_data) when is_map(new_data) do
    state = get_state(key) || %ExGram.FSM.State{}
    merged = Map.merge(state.data, new_data)
    set_state(key, %{state | data: merged})
  end

  @impl true
  @spec clear(ExGram.FSM.Storage.key()) :: :ok
  def clear(key) do
    :ets.delete(get_table_name(), key)
    :ok
  end

  defp get_table_name, do: @default_table
end
