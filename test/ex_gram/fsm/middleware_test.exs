defmodule ExGram.FSM.MiddlewareTest do
  use ExUnit.Case, async: false

  alias ExGram.FSM.{Middleware, State, Storage.ETS}

  @bot :middleware_test_bot

  setup do
    ETS.init(@bot, [])

    on_exit(fn ->
      try do
        :ets.delete_all_objects(ETS.table_name(@bot))
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  @default_opts [storage: ETS]

  # Build various update types for testing key extraction
  defp build_message_cnt(user_id, chat_id) do
    %ExGram.Cnt{
      name: @bot,
      extra: %{},
      update: %ExGram.Model.Update{
        update_id: 1,
        message: %ExGram.Model.Message{
          message_id: 1,
          date: 0,
          chat: %ExGram.Model.Chat{id: chat_id, type: "private"},
          from: %ExGram.Model.User{
            id: user_id,
            is_bot: false,
            first_name: "Test"
          },
          text: "hello"
        }
      }
    }
  end

  defp build_inline_query_cnt(user_id) do
    %ExGram.Cnt{
      name: @bot,
      extra: %{},
      update: %ExGram.Model.Update{
        update_id: 2,
        inline_query: %ExGram.Model.InlineQuery{
          id: "iq1",
          from: %ExGram.Model.User{
            id: user_id,
            is_bot: false,
            first_name: "Test"
          },
          query: "test",
          offset: ""
        }
      }
    }
  end

  defp build_channel_post_cnt do
    %ExGram.Cnt{
      name: @bot,
      extra: %{},
      update: %ExGram.Model.Update{
        update_id: 3,
        channel_post: %ExGram.Model.Message{
          message_id: 1,
          date: 0,
          chat: %ExGram.Model.Chat{id: -100, type: "channel"},
          text: "channel post"
        }
      }
    }
  end

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [storage: ETS, flows: %{}]
      assert Middleware.init(opts) == opts
    end
  end

  describe "call/2 - new user" do
    test "sets empty FSM state for new user (no flow, no state, no data)" do
      cnt = build_message_cnt(1, 1)
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm == %State{}
      assert result.extra.fsm.flow == nil
      assert result.extra.fsm.state == nil
      assert result.extra.fsm.data == %{}
    end

    test "sets all required extra keys" do
      cnt = build_message_cnt(1, 1)
      flows_map = %{registration: SomeFlowModule}
      opts = [storage: ETS, flows: flows_map, on_invalid_transition: :log]
      result = Middleware.call(cnt, opts)
      assert result.extra.fsm_key == {1, 1}
      assert result.extra.fsm_storage == ETS
      assert result.extra.fsm_flows == flows_map
      assert result.extra.fsm_on_invalid_transition == :log
    end

    test "fsm_flows defaults to empty map when not specified" do
      cnt = build_message_cnt(1, 1)
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm_flows == %{}
    end

    test "does not set fsm_states or fsm_default_state (removed keys)" do
      cnt = build_message_cnt(1, 1)
      result = Middleware.call(cnt, @default_opts)
      refute Map.has_key?(result.extra, :fsm_states)
      refute Map.has_key?(result.extra, :fsm_default_state)
    end
  end

  describe "call/2 - existing user" do
    test "loads state from storage" do
      stored = %State{flow: :registration, state: :get_name, data: %{name: "Alice"}}
      ETS.set_state(@bot, {1, 1}, stored)

      cnt = build_message_cnt(1, 1)
      result = Middleware.call(cnt, @default_opts)

      assert result.extra.fsm == stored
      assert result.extra.fsm.flow == :registration
      assert result.extra.fsm.state == :get_name
      assert result.extra.fsm.data == %{name: "Alice"}
    end
  end

  describe "call/2 - FSM key extraction" do
    test "DM: key is {chat_id, user_id}" do
      # In DMs, chat_id == user_id
      cnt = build_message_cnt(42, 42)
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm_key == {42, 42}
    end

    test "group chat: key is {group_chat_id, user_id}" do
      cnt = build_message_cnt(42, -100)
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm_key == {-100, 42}
    end

    test "inline query (no chat): key is {0, user_id}" do
      cnt = build_inline_query_cnt(42)
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm_key == {0, 42}
    end

    test "channel post (no from user): sets empty FSM state, no crash" do
      cnt = build_channel_post_cnt()
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm == %State{}
      # No fsm_key set for channel posts
      refute Map.has_key?(result.extra, :fsm_key)
    end
  end

  describe "call/2 - default on_invalid_transition" do
    test "defaults to :raise when not specified" do
      cnt = build_message_cnt(1, 1)
      result = Middleware.call(cnt, @default_opts)
      assert result.extra.fsm_on_invalid_transition == :raise
    end
  end
end
