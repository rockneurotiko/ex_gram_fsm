# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [v0.1.0] - 2025-04-09

### Added

- `use ExGram.FSM` macro — integrates FSM state management into any ExGram bot module
- `ExGram.FSM.Flow` — behaviour and DSL (`defstates/1`, `state/1`, `state/2`) for declaring named conversation flows with state/transition definitions
- `ExGram.FSM.States` — standalone behaviour and DSL for state/transition declarations
- `ExGram.FSM.State` — struct representing the current FSM state (`flow`, `state`, `data`)
- `ExGram.FSM.Helpers` — pipeline-friendly helper functions: `start_flow/2`, `get_flow/1`, `get_state/1`, `get_data/1`, `transition/2`, `set_state/2`, `set_state/3`, `update_data/2`, `clear_flow/1`
- `ExGram.FSM.Middleware` — ExGram middleware that loads FSM state from storage and injects it into `context.extra.fsm` before each update is handled
- `ExGram.FSM.Validator` — runtime transition validation with configurable `on_invalid_transition` policies (`:raise`, `:log`, `:ignore`, `{Module, :function}`)
- `ExGram.FSM.TransitionError` — exception raised when an invalid transition occurs under the `:raise` policy
- `ExGram.FSM.Storage` behaviour — pluggable storage backend contract (`init/1`, `get_state/1`, `set_state/2`, `get_data/1`, `set_data/2`, `update_data/2`, `clear/1`)
- `ExGram.FSM.Storage.ETS` — default in-memory ETS storage backend
- `ExGram.FSM.Key` behaviour — pluggable key extraction contract (`extract/1`) for scoping FSM state
- Built-in key adapters:
  - `ExGram.FSM.Key.ChatUser` (default) — `{chat_id, user_id}` scope
  - `ExGram.FSM.Key.User` — `{user_id}` global per-user scope
  - `ExGram.FSM.Key.Chat` — `{chat_id}` per-chat shared scope
  - `ExGram.FSM.Key.ChatTopic` — `{chat_id, thread_id}` per forum topic scope
  - `ExGram.FSM.Key.ChatTopicUser` — `{chat_id, thread_id, user_id}` per-user per forum topic scope
- `ExGram.FSM.Filter.Flow` and `ExGram.FSM.Filter.State` — ExGram.Router filter modules for routing by active flow and state
- Automatic registration of `:fsm_flow`, `:fsm_state`, and `:fsm_in_flow` filter aliases when `use ExGram.Router` is detected on the same module
- `ExGram.FSM.Filter.InFlow` - ExGram.Router filter module for matching any active FSM flow

