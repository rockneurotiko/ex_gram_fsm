defmodule ExGram.FSM.Validator do
  @moduledoc false

  @doc """
  Validates accumulated transition calls against a States module.

  Called at compile time via `@before_compile ExGram.FSM`. Emits warnings
  (not errors) for undeclared transitions so compilation always succeeds.

  ## Limitations

  - Only catches `transition(_, :literal_atom)` calls - dynamic atoms cannot
    be validated at compile time.
  - Only catches transitions inside `with_state` blocks - `transition/2` calls
    in regular `handle/2` clauses are not tracked.
  - Emits warnings, not errors - compilation always proceeds.
  """
  def validate_transitions(transition_calls, states_mod, env) do
    if states_mod != nil &&
         Code.ensure_loaded?(states_mod) &&
         function_exported?(states_mod, :transitions, 0) do
      transitions = states_mod.transitions()

      if transitions != :any do
        for {from, to} <- transition_calls do
          allowed = Map.get(transitions, from, [])

          unless to in allowed do
            IO.warn(
              "ExGram.FSM: transition from :#{from} to :#{to} is not declared " <>
                "in #{inspect(states_mod)}. Declared transitions from :#{from}: " <>
                "#{inspect(allowed)}",
              Macro.Env.stacktrace(env)
            )
          end
        end
      end
    end
  end
end
