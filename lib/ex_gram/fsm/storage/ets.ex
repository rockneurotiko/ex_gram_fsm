defmodule ExGram.FSM.Storage.ETS do
  @moduledoc """
  Default in-memory FSM storage using ETS.

  Suitable for development and single-node deployments.
  **State is lost on application restart.**

  ## Bot-scoped tables

  Each bot gets its own ETS table, named `:"ex_gram_fsm_{bot_name}"` by default.
  This ensures multiple bots running in the same node do not share FSM state.
  Override the table name via the `:ets_table` option:

      use ExGram.FSM, storage: ExGram.FSM.Storage.ETS, ets_table: :my_custom_table

  ## Concurrency

  Single-key ETS operations (`get_state`, `set_state`, `clear`) are atomic.
  However, `update_data/3` and `set_data/3` are read-modify-write operations
  and are **not atomic**. If you need atomicity for concurrent updates to the
  same key, use a storage backend with proper transactions (Postgres, Mnesia, etc.).

  ## Table ownership

  The ETS table is created as `:public` and `:named_table` in `init/2`.
  The table is owned by the process that first calls `init/2`.
  If that process dies, the table is destroyed.

  For production use, consider wrapping the table in a GenServer in your
  supervision tree to ensure stable ownership.
  """

  @behaviour ExGram.FSM.Storage

  @impl true
  @spec init(atom(), keyword()) :: :ok
  def init(bot_name, opts \\ []) do
    table = Keyword.get(opts, :ets_table, table_name(bot_name))

    try do
      :ets.new(table, [:set, :public, :named_table, {:read_concurrency, true}])
      :ok
    rescue
      ArgumentError -> :ok
    end
  end

  @impl true
  @spec get_state(atom(), ExGram.FSM.Storage.key()) :: ExGram.FSM.State.t() | nil
  def get_state(bot_name, key) do
    table = table_name(bot_name)

    case :ets.lookup(table, key) do
      [{^key, state}] -> state
      [] -> nil
    end
  end

  @impl true
  @spec set_state(atom(), ExGram.FSM.Storage.key(), ExGram.FSM.State.t()) :: :ok
  def set_state(bot_name, key, %ExGram.FSM.State{} = state) do
    :ets.insert(table_name(bot_name), {key, state})
    :ok
  end

  @impl true
  @spec get_data(atom(), ExGram.FSM.Storage.key()) :: map() | nil
  def get_data(bot_name, key) do
    case get_state(bot_name, key) do
      %ExGram.FSM.State{data: data} -> data
      nil -> nil
    end
  end

  @impl true
  @spec set_data(atom(), ExGram.FSM.Storage.key(), map()) :: :ok
  def set_data(bot_name, key, data) when is_map(data) do
    state = get_state(bot_name, key) || %ExGram.FSM.State{}
    set_state(bot_name, key, %{state | data: data})
  end

  @impl true
  @spec update_data(atom(), ExGram.FSM.Storage.key(), map()) :: :ok
  def update_data(bot_name, key, new_data) when is_map(new_data) do
    state = get_state(bot_name, key) || %ExGram.FSM.State{}
    merged = Map.merge(state.data, new_data)
    set_state(bot_name, key, %{state | data: merged})
  end

  @impl true
  @spec clear(atom(), ExGram.FSM.Storage.key()) :: :ok
  def clear(bot_name, key) do
    :ets.delete(table_name(bot_name), key)
    :ok
  end

  @doc false
  @spec table_name(atom()) :: atom()
  def table_name(bot_name), do: :"ex_gram_fsm_#{bot_name}"
end
