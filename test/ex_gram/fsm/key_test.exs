defmodule ExGram.FSM.KeyTest do
  use ExUnit.Case, async: true

  alias ExGram.FSM.Key.{Chat, ChatTopic, ChatTopicUser, ChatUser, User}

  # --- Shared helpers ---

  defp build_message_cnt(user_id, chat_id, opts \\ []) do
    thread_id = Keyword.get(opts, :thread_id)

    %ExGram.Cnt{
      extra: %{},
      update: %ExGram.Model.Update{
        message: %ExGram.Model.Message{
          chat: %ExGram.Model.Chat{id: chat_id, type: "group"},
          date: 0,
          from: %ExGram.Model.User{first_name: "Test", id: user_id, is_bot: false},
          message_id: 1,
          message_thread_id: thread_id,
          text: "hello"
        },
        update_id: 1
      }
    }
  end

  defp build_callback_cnt(user_id, chat_id, opts \\ []) do
    thread_id = Keyword.get(opts, :thread_id)

    %ExGram.Cnt{
      extra: %{},
      update: %ExGram.Model.Update{
        callback_query: %ExGram.Model.CallbackQuery{
          data: "btn",
          from: %ExGram.Model.User{first_name: "Test", id: user_id, is_bot: false},
          id: "cb1",
          message: %ExGram.Model.Message{
            chat: %ExGram.Model.Chat{id: chat_id, type: "group"},
            date: 0,
            message_id: 10,
            message_thread_id: thread_id,
            text: "Choose:"
          }
        },
        update_id: 2
      }
    }
  end

  defp build_inline_query_cnt(user_id) do
    %ExGram.Cnt{
      extra: %{},
      update: %ExGram.Model.Update{
        inline_query: %ExGram.Model.InlineQuery{
          from: %ExGram.Model.User{first_name: "Test", id: user_id, is_bot: false},
          id: "iq1",
          offset: "",
          query: "test"
        },
        update_id: 3
      }
    }
  end

  defp build_channel_post_cnt(chat_id) do
    %ExGram.Cnt{
      extra: %{},
      update: %ExGram.Model.Update{
        channel_post: %ExGram.Model.Message{
          chat: %ExGram.Model.Chat{id: chat_id, type: "channel"},
          date: 0,
          message_id: 1,
          text: "channel post"
        },
        update_id: 4
      }
    }
  end

  # --- ChatUser ---

  describe "ExGram.FSM.Key.ChatUser" do
    test "DM message produces {chat_id, user_id}" do
      # In DMs chat_id == user_id (both are 42)
      cnt = build_message_cnt(42, 42)
      assert ChatUser.extract(cnt) == {:ok, {42, 42}}
    end

    test "group message produces {chat_id, user_id}" do
      cnt = build_message_cnt(42, -100)
      assert ChatUser.extract(cnt) == {:ok, {-100, 42}}
    end

    test "callback query in a group produces {chat_id, user_id}" do
      cnt = build_callback_cnt(7, -200)
      assert ChatUser.extract(cnt) == {:ok, {-200, 7}}
    end

    test "inline query (no chat) produces {0, user_id}" do
      cnt = build_inline_query_cnt(42)
      assert ChatUser.extract(cnt) == {:ok, {0, 42}}
    end

    test "channel post (no user) returns :error" do
      cnt = build_channel_post_cnt(-100)
      assert ChatUser.extract(cnt) == :error
    end
  end

  # --- User ---

  describe "ExGram.FSM.Key.User" do
    test "message produces {user_id}" do
      cnt = build_message_cnt(42, -100)
      assert User.extract(cnt) == {:ok, {42}}
    end

    test "inline query produces {user_id}" do
      cnt = build_inline_query_cnt(99)
      assert User.extract(cnt) == {:ok, {99}}
    end

    test "channel post (no user) returns :error" do
      cnt = build_channel_post_cnt(-100)
      assert User.extract(cnt) == :error
    end
  end

  # --- Chat ---

  describe "ExGram.FSM.Key.Chat" do
    test "message produces {chat_id}" do
      cnt = build_message_cnt(42, -100)
      assert Chat.extract(cnt) == {:ok, {-100}}
    end

    test "channel post produces {chat_id}" do
      cnt = build_channel_post_cnt(-999)
      assert Chat.extract(cnt) == {:ok, {-999}}
    end

    test "inline query (no chat) returns :error" do
      cnt = build_inline_query_cnt(42)
      assert Chat.extract(cnt) == :error
    end
  end

  # --- ChatTopic ---

  describe "ExGram.FSM.Key.ChatTopic" do
    test "message in forum topic produces {chat_id, thread_id}" do
      cnt = build_message_cnt(42, -100, thread_id: 123)
      assert ChatTopic.extract(cnt) == {:ok, {-100, 123}}
    end

    test "message outside topic produces {chat_id, 0}" do
      cnt = build_message_cnt(42, -100)
      assert ChatTopic.extract(cnt) == {:ok, {-100, 0}}
    end

    test "callback query in forum topic produces {chat_id, thread_id}" do
      cnt = build_callback_cnt(7, -200, thread_id: 55)
      assert ChatTopic.extract(cnt) == {:ok, {-200, 55}}
    end

    test "callback query outside topic produces {chat_id, 0}" do
      cnt = build_callback_cnt(7, -200)
      assert ChatTopic.extract(cnt) == {:ok, {-200, 0}}
    end

    test "inline query (no chat) returns :error" do
      cnt = build_inline_query_cnt(42)
      assert ChatTopic.extract(cnt) == :error
    end
  end

  # --- ChatTopicUser ---

  describe "ExGram.FSM.Key.ChatTopicUser" do
    test "message in forum topic produces {chat_id, thread_id, user_id}" do
      cnt = build_message_cnt(42, -100, thread_id: 123)
      assert ChatTopicUser.extract(cnt) == {:ok, {-100, 123, 42}}
    end

    test "message outside topic produces {chat_id, 0, user_id}" do
      cnt = build_message_cnt(42, -100)
      assert ChatTopicUser.extract(cnt) == {:ok, {-100, 0, 42}}
    end

    test "callback query in forum topic produces {chat_id, thread_id, user_id}" do
      cnt = build_callback_cnt(7, -200, thread_id: 55)
      assert ChatTopicUser.extract(cnt) == {:ok, {-200, 55, 7}}
    end

    test "callback query outside topic produces {chat_id, 0, user_id}" do
      cnt = build_callback_cnt(7, -200)
      assert ChatTopicUser.extract(cnt) == {:ok, {-200, 0, 7}}
    end

    test "channel post (no user) returns :error" do
      cnt = build_channel_post_cnt(-100)
      assert ChatTopicUser.extract(cnt) == :error
    end

    test "inline query (no chat) returns :error" do
      cnt = build_inline_query_cnt(42)
      assert ChatTopicUser.extract(cnt) == :error
    end
  end
end
