defmodule ExGram.FSM.Key.ChatTopic do
  @moduledoc """
  FSM key: `{chat_id, thread_id}`.

  Scopes FSM state per forum topic, shared by all users in that topic. This is
  useful for Telegram groups with Topics (forum mode) enabled, where you want
  each topic to carry its own independent conversation flow.

  ## Key shape

  | Update type | Key |
  |-------------|-----|
  | Message in a forum topic | `{chat_id, thread_id}` |
  | Message outside a topic | `{chat_id, 0}` — 0 is a sentinel for no-topic context |
  | Inline query (no chat) | `:error` — FSM state is skipped |

  ## Accessing thread_id

  The `message_thread_id` field is read from:
  1. `update.message.message_thread_id` — for regular messages
  2. `update.callback_query.message.message_thread_id` — for callback queries
  """

  @behaviour ExGram.FSM.Key

  @impl true
  def extract(cnt) do
    case ExGram.Dsl.extract_chat(cnt.update) do
      {:ok, chat} ->
        thread_id = extract_thread_id(cnt.update) || 0
        {:ok, {chat.id, thread_id}}

      :error ->
        :error
    end
  end

  defp extract_thread_id(%{message: %{message_thread_id: thread_id}}) when not is_nil(thread_id), do: thread_id

  defp extract_thread_id(%{callback_query: %{message: %{message_thread_id: thread_id}}}) when not is_nil(thread_id),
    do: thread_id

  defp extract_thread_id(_), do: nil
end
