defmodule ExGram.FSM.States do
  @moduledoc """
  Behaviour for declaring FSM states and allowed transitions.

  Implement this behaviour to enable transition validation (both compile-time
  warnings and runtime enforcement via the `on_invalid_transition` policy).

  ## DSL approach (recommended)

  Use `defstates/1` for a concise declaration:

      defmodule MyBot.States do
        use ExGram.FSM.States

        defstates do
          state :idle, to: [:get_name]
          state :get_name, to: [:get_email, :idle]
          state :get_email, to: [:confirm, :get_name]
          state :confirm, to: [:idle]
        end
      end

  ## Direct behaviour implementation (escape hatch)

  For dynamic or programmatic state/transition definitions:

      defmodule MyBot.States do
        @behaviour ExGram.FSM.States

        @impl true
        def states, do: [:idle, :get_name, :get_email, :confirm]

        @impl true
        def transitions do
          %{
            idle: [:get_name],
            get_name: [:get_email, :idle],
            get_email: [:confirm, :get_name],
            confirm: [:idle]
          }
        end
      end

  ## No-transition-restriction mode

  To declare states without restricting transitions (useful for documentation
  purposes only), omit `:to` from all states:

      defstates do
        state :idle
        state :working
        state :done
      end
      # transitions/0 returns :any - all transitions allowed
  """

  @doc "Returns the list of all valid state atoms."
  @callback states() :: [atom()]

  @doc """
  Returns the allowed transitions map, or `:any` if all transitions are allowed.

  When returning a map, keys are source states and values are lists of
  allowed target states. Transitions not listed in the map are considered invalid.
  """
  @callback transitions() :: %{atom() => [atom()]} | :any

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ExGram.FSM.States

      # Accumulate {state_name, to_list_or_nil} entries
      Module.register_attribute(__MODULE__, :fsm_declared_states, accumulate: true)

      import ExGram.FSM.States, only: [defstates: 1, state: 1, state: 2]

      @before_compile ExGram.FSM.States
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    declared = Module.get_attribute(env.module, :fsm_declared_states) |> Enum.reverse()

    # Check for duplicate state names
    state_names = Enum.map(declared, fn {name, _} -> name end)
    duplicates = state_names -- Enum.uniq(state_names)

    if duplicates != [] do
      IO.warn(
        "ExGram.FSM.States: duplicate state names declared in #{inspect(env.module)}: " <>
          "#{inspect(Enum.uniq(duplicates))}",
        Macro.Env.stacktrace(env)
      )
    end

    unique_names = Enum.uniq(state_names)

    # Determine if any state has :to targets
    has_transitions = Enum.any?(declared, fn {_name, to} -> to != nil end)

    transitions_result =
      if has_transitions do
        transitions_map =
          for {name, to} <- declared, to != nil, into: %{} do
            # Warn about undeclared targets
            for target <- to do
              unless target in unique_names do
                IO.warn(
                  "ExGram.FSM.States: state :#{target} referenced in `to:` for " <>
                    ":#{name} but not declared as a state in #{inspect(env.module)}",
                  Macro.Env.stacktrace(env)
                )
              end
            end

            {name, to}
          end

        transitions_map
      else
        :any
      end

    quote do
      @impl true
      def states, do: unquote(unique_names)

      @impl true
      def transitions, do: unquote(Macro.escape(transitions_result))
    end
  end

  @doc """
  Declares a state inside a `defstates/1` block.

  ## Options

  - `:to` - list of allowed target states from this state

  ## Examples

      state :idle, to: [:get_name]      # can only go to :get_name
      state :idle                         # no transition restriction (when mixed, :any is NOT used)
  """
  defmacro state(name, opts \\ []) do
    to = Keyword.get(opts, :to)

    quote do
      @fsm_declared_states {unquote(name), unquote(to)}
    end
  end

  @doc """
  Declares all FSM states and their allowed transitions.

  ## Example

      defstates do
        state :idle, to: [:working]
        state :working, to: [:done, :idle]
        state :done, to: [:idle]
      end
  """
  defmacro defstates(do: block) do
    quote do
      unquote(block)
    end
  end
end
