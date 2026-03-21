defmodule ExGram.FSM do
  @moduledoc """
  Finite State Machine / conversation state management for ExGram Telegram bots.

  ## Quick start

  ### With ExGram.Router (recommended)

      defmodule MyBot do
        use ExGram.Bot, name: :my_bot
        use ExGram.Router
        use ExGram.FSM,
          storage: ExGram.FSM.Storage.ETS,
          flows: [MyBot.RegistrationFlow, MyBot.SettingsFlow],
          on_invalid_transition: :log

        command("register")

        scope do
          filter :command, :register
          handle &MyBot.Handlers.register/1
        end

        scope do
          filter :fsm_flow, :registration
          filter :fsm_state, :get_name
          filter :text
          handle &MyBot.Handlers.got_name/1
        end

        scope do
          handle &MyBot.Handlers.fallback/1
        end
      end

  The `:fsm_flow` and `:fsm_state` filter aliases are registered automatically
  when `use ExGram.FSM` detects that `use ExGram.Router` was also called. Use them
  to scope routes to a specific flow and step.

  ### Without ExGram.Router

  Pattern-match on `context.extra.fsm` directly in `handle/2` clauses:

      defmodule MyBot do
        use ExGram.Bot, name: :my_bot
        use ExGram.FSM,
          storage: ExGram.FSM.Storage.ETS,
          flows: [MyBot.RegistrationFlow]

        command("register")

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

  ## Options

  | Option | Type | Default | Description |
  |--------|------|---------|-------------|
  | `storage:` | module | `ExGram.FSM.Storage.ETS` | Storage backend |
  | `flows:` | list of modules | `[]` | Flow modules (each using `use ExGram.FSM.Flow`) |
  | `on_invalid_transition:` | atom or `{m, f}` | `:raise` | Invalid transition policy |
  | `key:` | module | `ExGram.FSM.Key.ChatUser` | Key adapter (see `ExGram.FSM.Key`) |

  ## `on_invalid_transition` policies

  | Policy | Behavior |
  |--------|----------|
  | `:raise` (default) | Raises `ExGram.FSM.TransitionError` |
  | `:log` | Logs a warning, returns context unchanged |
  | `:ignore` | Silent no-op, returns context unchanged |
  | `{Module, :function}` | Calls `Module.function(context, from, to)` |

  ## Imported helpers

  `use ExGram.FSM` automatically imports these functions:

  - `start_flow/2` - start a named flow (sets flow + default state + clears data)
  - `get_flow/1` - read current flow name atom
  - `get_state/1` - read current state atom within the active flow
  - `get_data/1` - read current data map
  - `set_state/2` - force set state within the active flow (no transition validation)
  - `set_state/3` - force set flow + state (escape hatch, ignores conflicts)
  - `transition/2` - set state with validation against the active flow's transitions
  - `update_data/2` - merge map into FSM data
  - `clear_flow/1` - reset flow, state, and data entirely
  """

  @doc false
  defmacro __using__(opts) do
    storage = Keyword.get(opts, :storage, ExGram.FSM.Storage.ETS)
    flow_mods = Keyword.get(opts, :flows, [])
    on_invalid = Keyword.get(opts, :on_invalid_transition, :raise)
    key_mod = Keyword.get(opts, :key, ExGram.FSM.Key.ChatUser)

    # Pass flow modules list to middleware; the middleware will build the flows map
    # at runtime when init/1 is called (by which point all modules are compiled).
    middleware_opts = [
      storage: storage,
      key: key_mod,
      flow_modules: flow_mods,
      on_invalid_transition: on_invalid
    ]

    quote do
      import ExGram.FSM.Helpers
      # Verify that use ExGram.Bot was called first (checks for @middlewares attribute)
      if !Module.has_attribute?(__MODULE__, :middlewares) do
        raise CompileError,
          description:
            "ExGram.FSM: `use ExGram.FSM` must be called after `use ExGram.Bot`. " <>
              "Add `use ExGram.Bot, name: :my_bot` before `use ExGram.FSM`."
      end

      # Store FSM config in module attributes
      @fsm_storage unquote(storage)
      @fsm_flow_modules unquote(flow_mods)
      @fsm_on_invalid_transition unquote(on_invalid)

      # Auto-register the FSM middleware
      middleware(ExGram.FSM.Middleware, unquote(middleware_opts))

      # Import runtime helpers

      # Auto-register :fsm_state and :fsm_flow filter aliases if ExGram.Router is in use
      if Module.has_attribute?(__MODULE__, :__exgram_filter_aliases__) do
        existing = Module.get_attribute(__MODULE__, :__exgram_filter_aliases__)

        if !Keyword.has_key?(existing, :fsm_state) do
          Module.put_attribute(
            __MODULE__,
            :__exgram_filter_aliases__,
            [{:fsm_state, ExGram.FSM.Filter.State} | existing]
          )
        end

        existing2 = Module.get_attribute(__MODULE__, :__exgram_filter_aliases__)

        if !Keyword.has_key?(existing2, :fsm_flow) do
          Module.put_attribute(
            __MODULE__,
            :__exgram_filter_aliases__,
            [{:fsm_flow, ExGram.FSM.Filter.Flow} | existing2]
          )
        end
      end
    end
  end
end
