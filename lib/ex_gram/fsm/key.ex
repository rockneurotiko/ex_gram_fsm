defmodule ExGram.FSM.Key do
  @moduledoc """
  Behaviour for extracting FSM storage keys from Telegram updates.

  The key determines how FSM state is scoped. Different key strategies allow
  per-user, per-chat, per-topic, or combined scoping.

  ## Built-in implementations

  | Module | Key shape | Scope |
  |--------|-----------|-------|
  | `ExGram.FSM.Key.ChatUser` (default) | `{chat_id, user_id}` | Per-user per-chat |
  | `ExGram.FSM.Key.User` | `{user_id}` | Global per-user (across all chats) |
  | `ExGram.FSM.Key.Chat` | `{chat_id}` | Per-chat shared (all users share one FSM) |
  | `ExGram.FSM.Key.ChatTopic` | `{chat_id, thread_id}` | Per forum topic, shared by all users |
  | `ExGram.FSM.Key.ChatTopicUser` | `{chat_id, thread_id, user_id}` | Per-user per forum topic |

  ## Usage

  Configure the key module via the `key:` option in `use ExGram.FSM`:

      use ExGram.FSM,
        key: ExGram.FSM.Key.User,
        flows: [MyBot.RegistrationFlow]

  ## Custom implementations

  Implement this behaviour to define your own key strategy:

      defmodule MyApp.FSM.Key.UserLanguage do
        @behaviour ExGram.FSM.Key

        @impl true
        def extract(cnt) do
          with {:ok, user} <- ExGram.Dsl.extract_user(cnt.update) do
            {:ok, {user.id, user.language_code}}
          end
        end
      end

      use ExGram.FSM, key: MyApp.FSM.Key.UserLanguage, ...

  ## Sentinel values

  When a field is unavailable but another dimension is present, implementations
  use `0` as a sentinel (e.g., inline queries have no chat, so chat_id is `0`;
  messages outside forum topics have no thread_id, so thread_id is `0`).

  When a mandatory dimension is missing (e.g., no user for a `User` key), the
  callback should return `:error` to skip FSM state loading for that update.
  """

  @type t :: term()

  @doc """
  Extract a storage key from the current update context.

  Return `{:ok, key}` with any term as the key, or `:error` if the key cannot
  be determined for this update type (e.g., no user for a user-scoped key).

  When `:error` is returned, the middleware sets an empty `%ExGram.FSM.State{}`
  in `context.extra.fsm` and does not store or load any FSM state.
  """
  @callback extract(ExGram.Cnt.t()) :: {:ok, t()} | :error
end
