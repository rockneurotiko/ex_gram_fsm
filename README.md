# ExGram FSM

[![CI](https://github.com/rockneurotiko/ex_gram_fsm/actions/workflows/ci.yml/badge.svg)](https://github.com/rockneurotiko/ex_gram_fsm/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_gram_fsm.svg)](https://hex.pm/packages/ex_gram_fsm)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_gram_fsm/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/ex_gram_fsm.svg)](https://hex.pm/packages/ex_gram_fsm)

Finite State Machine / multi-flow conversation state management for [ExGram](https://hex.pm/packages/ex_gram) Telegram bots.

Provides `use ExGram.FSM` with pluggable storage backends, named conversation flows, and runtime transition validation. Integrates with [ExGram.Router](https://github.com/rockneurotiko/ex_gram_router) via automatically-registered `:fsm_state` and `:fsm_flow` filter aliases.

## Installation

Add `ex_gram_fsm` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_gram, "~> 0.60"},
    {:ex_gram_fsm, "~> 0.1.0"}
  ]
end
```

If you are also using [ExGram.Router](https://github.com/rockneurotiko/ex_gram_router), add it too:

```elixir
def deps do
  [
    {:ex_gram, "~> 0.60"},
    {:ex_gram_fsm, "~> 0.1.0"},
    {:ex_gram_router, "~> 0.1.0"}
  ]
end
```

## Defining Flows

Each conversation flow is a separate module using `use ExGram.FSM.Flow`:

```elixir
defmodule MyBot.RegistrationFlow do
  use ExGram.FSM.Flow, name: :registration

  defstates do
    state :get_name,  to: [:get_email]
    state :get_email, to: [:done]
    state :done,      to: []
  end

  def default_state, do: :get_name
end
```

The `name:` option sets the flow's identifier atom. `defstates` declares valid states and their allowed transitions. `default_state/0` returns the state automatically set when the flow is started.

## Usage

### With ExGram.Router (recommended)

Call `use ExGram.Router` before `use ExGram.FSM`. Both `:fsm_flow` and `:fsm_state` filter aliases are registered automatically.

```elixir
defmodule MyBot do
  use ExGram.Bot, name: :my_bot
  use ExGram.Router
  use ExGram.FSM,
    storage: ExGram.FSM.Storage.ETS,
    flows: [MyBot.RegistrationFlow, MyBot.SettingsFlow],
    on_invalid_transition: :log

  command("register", description: "Start registration")
  command("settings", description: "Change settings")

  scope do
    filter :command, :register
    handle &MyBot.Handlers.start_registration/1
  end

  scope do
    filter :command, :settings
    handle &MyBot.Handlers.start_settings/1
  end

  # Route by flow + state
  scope do
    filter :fsm_flow, :registration

    scope do
      filter :fsm_state, :get_name
      filter :text
      handle &MyBot.Handlers.got_name/1
    end

    scope do
      filter :fsm_state, :get_email
      filter :text
      handle &MyBot.Handlers.got_email/1
    end
  end

  scope do
    handle &MyBot.Handlers.fallback/1
  end
end
```

Handler functions receive the context and use the imported FSM helpers:

```elixir
defmodule MyBot.Handlers do
  def start_registration(context) do
    context
    |> start_flow(:registration)
    |> answer("What's your name?")
  end

  def got_name(context) do
    name = context.update.message.text

    context
    |> update_data(%{name: name})
    |> transition(:get_email)
    |> answer("Got it, #{name}! What's your email?")
  end

  def got_email(context) do
    %{name: name} = get_data(context)
    email = context.update.message.text

    context
    |> update_data(%{email: email})
    |> clear_flow()
    |> answer("Registered! Welcome, #{name} (#{email}).")
  end

  def fallback(context), do: context
end
```

### Without ExGram.Router

Pattern-match on `context.extra.fsm` directly in `handle/2` clauses:

```elixir
defmodule MyBot do
  use ExGram.Bot, name: :my_bot
  use ExGram.FSM,
    storage: ExGram.FSM.Storage.ETS,
    flows: [MyBot.RegistrationFlow],
    on_invalid_transition: :log

  command("register", description: "Start registration")

  def handle({:command, :register, _}, context) do
    context |> start_flow(:registration) |> answer("What's your name?")
  end

  def handle({:text, name, _}, %{extra: %{fsm: %ExGram.FSM.State{flow: :registration, state: :get_name}}} = context) do
    context
    |> update_data(%{name: name})
    |> transition(:get_email)
    |> answer("Got it! What's your email?")
  end

  def handle(_, context), do: context
end
```

## Options

`use ExGram.FSM` accepts the following options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `storage:` | module | `ExGram.FSM.Storage.ETS` | Storage backend module |
| `flows:` | list of modules | `[]` | Flow modules to register (see `ExGram.FSM.Flow`) |
| `on_invalid_transition:` | atom or `{m, f}` | `:raise` | Policy for invalid transitions |
| `key:` | module | `ExGram.FSM.Key.ChatUser` | Key adapter module (see `ExGram.FSM.Key`) |

### `on_invalid_transition` policies

| Policy | Behavior |
|--------|----------|
| `:raise` (default) | Raises `ExGram.FSM.TransitionError` |
| `:log` | Logs a warning, returns context unchanged |
| `:ignore` | Silent no-op, returns context unchanged |
| `{Module, :function}` | Calls `Module.function(context, from, to)` |

## Flow Lifecycle

One flow is active at a time per key (by default, per `{chat_id, user_id}` pair). The flow lifecycle is:

1. **Start** — `start_flow(context, :flow_name)` activates a flow, sets its default state, clears data
2. **Transition** — `transition(context, :next_state)` moves to the next step with validation
3. **Accumulate** — `update_data(context, %{key: value})` persists form fields
4. **End** — `clear_flow(context)` resets to no-flow state

Attempting to `start_flow` when a **different** flow is already active triggers the `on_invalid_transition` policy.

## Helpers

`use ExGram.FSM` automatically imports these functions into your bot module:

| Function | Description |
|----------|-------------|
| `start_flow(context, flow)` | Start a named flow (sets default state, clears data) |
| `get_flow(context)` | Returns current active flow name atom, or `nil` |
| `get_state(context)` | Returns current step atom within the active flow, or `nil` |
| `get_data(context)` | Returns current FSM data map, never `nil` |
| `transition(context, to)` | Transition to next step with validation |
| `set_state(context, state)` | Force-set state within active flow, bypassing validation |
| `set_state(context, flow, state)` | Force-set flow + state, bypassing all checks (escape hatch) |
| `update_data(context, map)` | Merge a map into the FSM data |
| `clear_flow(context)` | Reset: no active flow, no state, no data |

All helpers take and return `ExGram.Cnt.t()` for pipeline compatibility.

### `transition/2` vs `set_state/2`

- **`transition/2`** validates the `from -> to` pair against the flow's declared transitions and applies the `on_invalid_transition` policy if the transition is not allowed. This is the normal path.
- **`set_state/2`** unconditionally sets the state within the active flow, bypassing transition validation. Use as an escape hatch (admin resets, recovery).
- **`set_state/3`** unconditionally sets both flow and state, ignoring any active flow. Use only for testing or extreme recovery scenarios.

## Filters (ExGram.Router integration)

When `use ExGram.Router` is detected on the same module, two filter aliases are registered automatically.

### `:fsm_flow` — match on active flow

```elixir
scope do
  filter :fsm_flow, :registration
  filter :fsm_state, :get_name
  filter :text
  handle &MyBot.Handlers.got_name/1
end
```

Match when no flow is active:

```elixir
scope do
  filter :fsm_flow, nil
  filter :command, :start
  handle &MyBot.Handlers.handle_start/1
end
```

### `:fsm_state` — match on state or data

Match on state atom:

```elixir
scope do
  filter :fsm_state, :get_name
  filter :text
  handle &MyBot.Handlers.got_name/1
end
```

Match on a key in FSM data:

```elixir
scope do
  filter :fsm_state, {:step, :confirm}
  handle &MyBot.Handlers.confirm/1
end
```

To register either filter manually (without `use ExGram.FSM`):

```elixir
alias_filter ExGram.FSM.Filter.Flow,  as: :fsm_flow
alias_filter ExGram.FSM.Filter.State, as: :fsm_state
```

## Storage

The default backend is `ExGram.FSM.Storage.ETS` (in-memory, single-node). **State is lost on restart.**

For production deployments, implement the `ExGram.FSM.Storage` behaviour:

```elixir
defmodule MyApp.RedisStorage do
  @behaviour ExGram.FSM.Storage

  @impl true
  def init(opts), do: :ok

  @impl true
  def get_state(key), do: # read from Redis

  @impl true
  def set_state(key, %ExGram.FSM.State{} = state), do: # write to Redis

  @impl true
  def get_data(key), do: # read data portion from Redis

  @impl true
  def set_data(key, data), do: # write data portion to Redis

  @impl true
  def update_data(key, new_data), do: # merge and write to Redis

  @impl true
  def clear(key), do: # delete from Redis
end
```

Use it via the `storage:` option:

```elixir
use ExGram.FSM, storage: MyApp.RedisStorage, flows: [...]
```

## Key Adapters

The key adapter controls how FSM state is scoped. It is a module implementing the `ExGram.FSM.Key` behaviour, configured via the `key:` option.

### Built-in adapters

| Module | Key shape | Scope |
|--------|-----------|-------|
| `ExGram.FSM.Key.ChatUser` (default) | `{chat_id, user_id}` | Per-user per-chat |
| `ExGram.FSM.Key.User` | `{user_id}` | Global per-user (across all chats) |
| `ExGram.FSM.Key.Chat` | `{chat_id}` | Per-chat shared (all users share one FSM) |
| `ExGram.FSM.Key.ChatTopic` | `{chat_id, thread_id}` | Per forum topic, shared by all users |
| `ExGram.FSM.Key.ChatTopicUser` | `{chat_id, thread_id, user_id}` | Per-user per forum topic |

```elixir
# Default: each user has independent state in each chat
use ExGram.FSM, key: ExGram.FSM.Key.ChatUser, flows: [...]

# User-scoped: same state across DMs, groups, and inline queries
use ExGram.FSM, key: ExGram.FSM.Key.User, flows: [...]

# Chat-scoped: shared state for all users in a chat (e.g., group game sessions)
use ExGram.FSM, key: ExGram.FSM.Key.Chat, flows: [...]

# Forum topic adapters (Telegram groups with Topics mode enabled)
use ExGram.FSM, key: ExGram.FSM.Key.ChatTopic, flows: [...]
use ExGram.FSM, key: ExGram.FSM.Key.ChatTopicUser, flows: [...]
```

### Sentinel values

When a dimension is unavailable (e.g., a message is not in a forum topic), implementations use `0` as a sentinel. When a mandatory dimension is absent (e.g., no user for `User`), the adapter returns `:error` and the middleware skips FSM state loading for that update.

### Custom key adapters

Implement the `ExGram.FSM.Key` behaviour to define your own scoping strategy:

```elixir
defmodule MyApp.FSM.Key.Custom do
  @behaviour ExGram.FSM.Key

  @impl true
  def extract(cnt) do
    with {:ok, user} <- ExGram.Dsl.extract_user(cnt.update),
         {:ok, chat} <- ExGram.Dsl.extract_chat(cnt.update) do
      {:ok, {chat.id, user.language_code}}
    end
  end
end

use ExGram.FSM, key: MyApp.FSM.Key.Custom, flows: [...]
```

## License

Beerware — see [LICENSE](LICENSE).

## Links

- [GitHub](https://github.com/rockneurotiko/ex_gram_fsm)
- [HexDocs](https://hexdocs.pm/ex_gram_fsm/)
- [Hex Package](https://hex.pm/packages/ex_gram_fsm)
- [ExGram](https://hex.pm/packages/ex_gram)
- [ExGram.Router](https://github.com/rockneurotiko/ex_gram_router)
