defmodule ExGram.FSM.Key.Chat do
  @moduledoc """
  FSM key: `{chat_id}`.

  Scopes FSM state per-chat, shared by all users in that chat. This means:
  - All users in a group chat share a single FSM state.
  - Useful for group-level conversation flows (e.g., a poll wizard, game sessions).

  ## Key shape

  | Update type | Key |
  |-------------|-----|
  | Any update with a chat | `{chat_id}` |
  | Inline query (no chat) | `:error` — FSM state is skipped |
  """

  @behaviour ExGram.FSM.Key

  @impl true
  def extract(cnt) do
    case ExGram.Dsl.extract_chat(cnt.update) do
      {:ok, chat} -> {:ok, {chat.id}}
      :error -> :error
    end
  end
end
