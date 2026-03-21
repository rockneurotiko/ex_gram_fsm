defmodule ExGram.FSM.Storage do
  @moduledoc """
  Behaviour for FSM state storage backends.

  The default implementation is `ExGram.FSM.Storage.ETS` (in-memory, single-node).
  Implement this behaviour for persistent storage (Redis, Postgres, Mnesia, etc.).

  ## Bot-scoped storage

  All callbacks receive `bot_name` as their first argument (an atom). This allows
  a single storage backend to serve multiple bots without key collisions. Storage
  implementations should use `bot_name` to namespace data (e.g., different ETS
  tables, Redis key prefixes, database schemas, etc.).

  ## Key format

  Storage keys are opaque `term()` values produced by the configured
  `ExGram.FSM.Key` implementation. The exact shape depends on the key strategy:

  | Key module | Key shape |
  |------------|-----------|
  | `ExGram.FSM.Key.ChatUser` (default) | `{chat_id, user_id}` |
  | `ExGram.FSM.Key.User` | `{user_id}` |
  | `ExGram.FSM.Key.Chat` | `{chat_id}` |
  | `ExGram.FSM.Key.ChatTopic` | `{chat_id, thread_id}` |
  | `ExGram.FSM.Key.ChatTopicUser` | `{chat_id, thread_id, user_id}` |

  Custom storage implementations should treat the key as an opaque term and not
  pattern-match on its internal structure.
  """

  @type bot_name :: atom()
  @type key :: term()
  @type state :: ExGram.FSM.State.t()

  @doc """
  Initialize the storage backend for a specific bot. Called once at bot startup
  via the `ExGram.FSM.StorageInit` hook.

  `bot_name` is the registered bot name atom (e.g., `:my_bot`). Use it to
  namespace storage (e.g., create a per-bot ETS table).

  Receives the full options keyword list passed to `use ExGram.FSM`.
  Must be idempotent — may be called multiple times in tests.
  """
  @callback init(bot_name(), opts :: keyword()) :: :ok | {:error, term()}

  @doc """
  Retrieve the full FSM state for a key.

  Returns `nil` if the key has no stored state.
  """
  @callback get_state(bot_name(), key()) :: state() | nil

  @doc """
  Write the full FSM state for a key.

  Creates or overwrites the existing state.
  """
  @callback set_state(bot_name(), key(), state()) :: :ok | {:error, term()}

  @doc """
  Retrieve only the data map for a key.

  Returns `nil` if the key has no stored state.
  Convenience callback — can be implemented as `get_state/2` + extract data.
  """
  @callback get_data(bot_name(), key()) :: map() | nil

  @doc """
  Overwrite the data map for a key, preserving the state atom.

  If no existing state, creates one with `state: nil` and the given data.
  """
  @callback set_data(bot_name(), key(), map()) :: :ok | {:error, term()}

  @doc """
  Merge `new_data` into existing data for a key.

  Equivalent to `Map.merge(existing_data, new_data)`.
  If no existing state, creates one with `state: nil` and the given data.
  """
  @callback update_data(bot_name(), key(), new_data :: map()) :: :ok | {:error, term()}

  @doc """
  Remove all FSM state and data for a key.

  After this, `get_state/2` should return `nil` for this key.
  Must not crash if the key doesn't exist.
  """
  @callback clear(bot_name(), key()) :: :ok | {:error, term()}
end
