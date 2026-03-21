defmodule ExGram.FSM.Storage do
  @moduledoc """
  Behaviour for FSM state storage backends.

  The default implementation is `ExGram.FSM.Storage.ETS` (in-memory, single-node).
  Implement this behaviour for persistent storage (Redis, Postgres, Mnesia, etc.).

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

  @type key :: term()
  @type state :: ExGram.FSM.State.t()

  @doc """
  Initialize the storage backend. Called once on first use.

  Receives the full options keyword list passed to `use ExGram.FSM`.
  Must be idempotent - may be called multiple times in tests.
  """
  @callback init(opts :: keyword()) :: :ok | {:error, term()}

  @doc """
  Retrieve the full FSM state for a key.

  Returns `nil` if the key has no stored state.
  """
  @callback get_state(key()) :: state() | nil

  @doc """
  Write the full FSM state for a key.

  Creates or overwrites the existing state.
  """
  @callback set_state(key(), state()) :: :ok | {:error, term()}

  @doc """
  Retrieve only the data map for a key.

  Returns `nil` if the key has no stored state.
  Convenience callback - can be implemented as `get_state/1` + extract data.
  """
  @callback get_data(key()) :: map() | nil

  @doc """
  Overwrite the data map for a key, preserving the state atom.

  If no existing state, creates one with `state: nil` and the given data.
  """
  @callback set_data(key(), map()) :: :ok | {:error, term()}

  @doc """
  Merge `new_data` into existing data for a key.

  Equivalent to `Map.merge(existing_data, new_data)`.
  If no existing state, creates one with `state: nil` and the given data.
  """
  @callback update_data(key(), new_data :: map()) :: :ok | {:error, term()}

  @doc """
  Remove all FSM state and data for a key.

  After this, `get_state/1` should return `nil` for this key.
  Must not crash if the key doesn't exist.
  """
  @callback clear(key()) :: :ok | {:error, term()}
end
