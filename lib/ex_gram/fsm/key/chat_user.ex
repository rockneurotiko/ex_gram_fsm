defmodule ExGram.FSM.Key.ChatUser do
  @moduledoc """
  Default FSM key: `{chat_id, user_id}`.

  Scopes FSM state per-user per-chat. This means:
  - The same user in different chats has independent FSM state.
  - Different users in the same chat have independent FSM state.

  This is the default key strategy and the most common choice for bots that
  run multi-step conversations in both DMs and group chats.

  ## Key shape

  | Update type | Key |
  |-------------|-----|
  | Message / callback in a chat | `{chat_id, user_id}` |
  | Inline query (no chat) | `{0, user_id}` — 0 is a sentinel for no-chat context |
  | Channel post (no user) | `:error` — FSM state is skipped |
  """

  @behaviour ExGram.FSM.Key

  @impl true
  def extract(cnt) do
    with {:ok, user} <- ExGram.Dsl.extract_user(cnt.update),
         {:ok, chat} <- ExGram.Dsl.extract_chat(cnt.update) do
      {:ok, {chat.id, user.id}}
    else
      _ ->
        # Fallback for inline queries (user but no chat)
        case ExGram.Dsl.extract_user(cnt.update) do
          # 0 = sentinel for no-chat context
          {:ok, user} -> {:ok, {0, user.id}}
          :error -> :error
        end
    end
  end
end
