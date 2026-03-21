defmodule ExGram.FSM.Key.ChatTopicUser do
  @moduledoc """
  FSM key: `{chat_id, thread_id, user_id}`.

  Scopes FSM state per-user per forum topic. This is the most granular scoping
  available for Telegram groups with Topics (forum mode) enabled.

  Each user gets their own independent FSM state within each forum topic, while
  different topics remain completely isolated.

  ## Key shape

  | Update type | Key |
  |-------------|-----|
  | Message in a forum topic | `{chat_id, thread_id, user_id}` |
  | Message outside a topic | `{chat_id, 0, user_id}` — 0 is a sentinel for no-topic context |
  | Channel post (no user) | `:error` — FSM state is skipped |
  | Inline query (no chat) | `:error` — FSM state is skipped |

  ## Accessing thread_id

  The `message_thread_id` field is read from:
  1. `update.message.message_thread_id` — for regular messages
  2. `update.callback_query.message.message_thread_id` — for callback queries
  """

  @behaviour ExGram.FSM.Key

  @impl true
  def extract(cnt) do
    with {:ok, chat} <- ExGram.Dsl.extract_chat(cnt.update),
         {:ok, user} <- ExGram.Dsl.extract_user(cnt.update) do
      thread_id = extract_thread_id(cnt.update) || 0
      {:ok, {chat.id, thread_id, user.id}}
    else
      _ -> :error
    end
  end

  defp extract_thread_id(%{message: %{message_thread_id: thread_id}})
       when not is_nil(thread_id),
       do: thread_id

  defp extract_thread_id(%{callback_query: %{message: %{message_thread_id: thread_id}}})
       when not is_nil(thread_id),
       do: thread_id

  defp extract_thread_id(_), do: nil
end
