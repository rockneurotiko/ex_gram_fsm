defmodule ExGram.FSM.Key.User do
  @moduledoc """
  FSM key: `{user_id}`.

  Scopes FSM state globally per-user, across all chats. This means:
  - A user carries the same FSM state whether they message the bot in a DM,
    a group chat, or via an inline query.
  - Different users always have independent FSM state.

  Use this when you want a single conversation flow that persists across contexts,
  for example a registration flow that works the same in DMs and groups.

  ## Key shape

  | Update type | Key |
  |-------------|-----|
  | Any update with a user | `{user_id}` |
  | Channel post (no user) | `:error` — FSM state is skipped |
  """

  @behaviour ExGram.FSM.Key

  @impl true
  def extract(cnt) do
    case ExGram.Dsl.extract_user(cnt.update) do
      {:ok, user} -> {:ok, {user.id}}
      :error -> :error
    end
  end
end
