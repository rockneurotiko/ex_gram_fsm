defmodule ExGram.FSM.Helpers do
  @moduledoc """
  Runtime helper functions for FSM flow and state management.

  All functions take and return `ExGram.Cnt.t()` for pipeline compatibility.
  These are automatically imported into your bot module when you call
  `use ExGram.FSM`.

  ## Context keys

  The helpers read FSM config from `context.extra` keys set by the middleware:

  | Key | Type | Description |
  |-----|------|-------------|
  | `context.extra.fsm` | `%ExGram.FSM.State{}` | Current flow + state + data |
  | `context.extra.fsm_key` | `term()` | Storage key (shape depends on configured key module) |
  | `context.extra.fsm_storage` | module | Storage backend module |
  | `context.extra.fsm_flows` | `%{atom => module}` | Registered flow modules map |
  | `context.extra.fsm_on_invalid_transition` | atom or tuple | Invalid transition policy |

  ## Flow lifecycle

      # 1. Start a flow (sets flow name, default state, clears data)
      context |> start_flow(:registration)

      # 2. Transition through states (validated against the active flow)
      context |> transition(:get_email)

      # 3. Accumulate data
      context |> update_data(%{name: "Alice"})

      # 4. End the flow (resets to no-flow state)
      context |> clear_flow()
  """

  alias ExGram.FSM.State

  @doc """
  Starts a named flow for the current user/chat.

  Sets the flow name, applies the flow's `default_state/0` as the initial state
  (if defined), and clears any previous data.

  Behavior:
  - If no flow is currently active → starts the new flow
  - If the same flow is already active → re-starts it (resets state + data)
  - If a **different** flow is active → applies the `on_invalid_transition` policy.
    The "from" is the current flow name (treated as a pseudo-state), "to" is
    the requested flow name.

  ## Example

      def handle({:command, :register, _}, context) do
        context
        |> start_flow(:registration)
        |> answer("What's your name?")
      end
  """
  @spec start_flow(ExGram.Cnt.t(), atom()) :: ExGram.Cnt.t()
  def start_flow(context, flow_name) do
    current_flow = get_flow(context)
    flows_map = context.extra[:fsm_flows] || %{}

    unless Map.has_key?(flows_map, flow_name) do
      raise ArgumentError,
            "ExGram.FSM: flow #{inspect(flow_name)} is not registered. " <>
              "Add it to `use ExGram.FSM, flows: [...]`."
    end

    if current_flow != nil and current_flow != flow_name do
      # Different flow already active — apply on_invalid_transition policy
      handle_invalid_transition(context, current_flow, flow_name)
    else
      flow_mod = Map.fetch!(flows_map, flow_name)
      default = flow_mod.default_state()
      new_fsm = %State{flow: flow_name, state: default, data: %{}}
      do_update_context(context, new_fsm)
    end
  end

  @doc """
  Returns the current active flow name atom from context.

  Returns `nil` if no flow is active or if the FSM middleware didn't run.

  ## Example

      def handle({:command, :status, _}, context) do
        flow = get_flow(context)
        answer(context, "Current flow: \#{inspect(flow)}")
      end
  """
  @spec get_flow(ExGram.Cnt.t()) :: atom() | nil
  def get_flow(context) do
    case context.extra[:fsm] do
      %State{flow: flow} -> flow
      _ -> nil
    end
  end

  @doc """
  Returns the current FSM state atom (step within the active flow) from context.

  Returns `nil` if no state is set or if the FSM middleware didn't run.

  ## Example

      def handle({:command, :status, _}, context) do
        state = get_state(context)
        answer(context, "Current step: \#{inspect(state)}")
      end
  """
  @spec get_state(ExGram.Cnt.t()) :: atom() | nil
  def get_state(context) do
    case context.extra[:fsm] do
      %State{state: state} -> state
      _ -> nil
    end
  end

  @doc """
  Returns the current FSM data map from context.

  Never returns `nil` — returns `%{}` if no FSM state exists.

  ## Example

      def handle({:command, :status, _}, context) do
        data = get_data(context)
        answer(context, "Your data: \#{inspect(data)}")
      end
  """
  @spec get_data(ExGram.Cnt.t()) :: map()
  def get_data(context) do
    case context.extra[:fsm] do
      %State{data: data} -> data
      _ -> %{}
    end
  end

  @doc """
  Unconditionally sets the FSM state within the currently active flow.

  Requires an active flow. If no flow is active, the `on_invalid_transition`
  policy is applied (with `from: nil, to: new_state`).

  This bypasses transition validation — use `transition/2` for the normal path.

  Use cases:
  - Resetting to the flow's first step
  - Admin override within a flow
  - Recovery from an error state within a flow

  ## Example

      def handle({:command, :restart_flow, _}, context) do
        context
        |> set_state(:get_name)
        |> answer("Let's start over. What's your name?")
      end
  """
  @spec set_state(ExGram.Cnt.t(), atom()) :: ExGram.Cnt.t()
  def set_state(context, new_state) do
    if get_flow(context) == nil do
      # No active flow — use on_invalid_transition policy
      handle_invalid_transition(context, nil, new_state)
    else
      current_fsm = context.extra[:fsm] || %State{}
      new_fsm = %{current_fsm | state: new_state}
      do_update_context(context, new_fsm)
    end
  end

  @doc """
  Force sets a flow and state, bypassing all conflict and validation checks.

  This is the escape hatch — it always succeeds regardless of the current flow.
  The data map is preserved as-is. Use this only for admin resets, recovery, or
  testing.

  ## Example

      def handle({:command, :admin_reset, _}, context) do
        context
        |> set_state(:registration, :get_name)
        |> answer("Admin reset. Starting registration flow.")
      end
  """
  @spec set_state(ExGram.Cnt.t(), atom(), atom()) :: ExGram.Cnt.t()
  def set_state(context, flow_name, new_state) do
    flows_map = context.extra[:fsm_flows] || %{}

    unless Map.has_key?(flows_map, flow_name) do
      raise ArgumentError,
            "ExGram.FSM: flow #{inspect(flow_name)} is not registered. " <>
              "Add it to `use ExGram.FSM, flows: [...]`."
    end

    current_fsm = context.extra[:fsm] || %State{}
    new_fsm = %{current_fsm | flow: flow_name, state: new_state}
    do_update_context(context, new_fsm)
  end

  @doc """
  Sets the FSM state with transition validation against the active flow.

  This is the normal path for moving through steps. Use `set_state/2` only as
  an escape hatch when you want to force a state skip validation.

  Behavior:
  1. Reads the current state from `context.extra.fsm.state`
  2. Reads the active flow from `context.extra.fsm.flow`
  3. Looks up the flow module and checks whether `from -> to` is a valid transition
  4. If valid (or no flows configured): updates state and persists to storage
  5. If NOT valid: delegates to the `on_invalid_transition` policy

  Return value depends on policy:
  - `:raise` — raises `ExGram.FSM.TransitionError` (never returns normally)
  - `:log` — logs a warning, returns `context` unchanged
  - `:ignore` — returns `context` unchanged silently
  - `{Module, :function}` — calls `Module.function(context, from, to)`, returns its result

  ## Example

      def handle({:text, name, _}, %{extra: %{fsm: %ExGram.FSM.State{flow: :registration, state: :get_name}}} = context) do
        context
        |> update_data(%{name: name})
        |> transition(:get_email)
        |> answer("Got it! What's your email?")
      end
  """
  @spec transition(ExGram.Cnt.t(), atom()) :: ExGram.Cnt.t()
  def transition(context, to) do
    from = get_state(context)
    flow = get_flow(context)
    flows_map = context.extra[:fsm_flows] || %{}

    # Look up the flow module for transition validation
    states_mod = if flow, do: Map.get(flows_map, flow), else: nil

    if valid_transition?(states_mod, from, to) do
      do_set_state(context, to)
    else
      handle_invalid_transition(context, from, to)
    end
  end

  @doc """
  Merges a map into the current FSM data, persisting the result.

  Uses `Map.merge/2` semantics: new keys are added, existing keys are overwritten.
  The active flow and state are preserved.

  ## Example

      def handle({:text, name, _}, context) do
        context
        |> update_data(%{name: name})
        |> transition(:get_email)
        |> answer("What's your email?")
      end
  """
  @spec update_data(ExGram.Cnt.t(), map()) :: ExGram.Cnt.t()
  def update_data(context, new_data) when is_map(new_data) do
    current_fsm = context.extra[:fsm] || %State{}
    merged_data = Map.merge(current_fsm.data, new_data)
    new_fsm = %{current_fsm | data: merged_data}

    # Update in-memory
    new_extra = Map.put(context.extra, :fsm, new_fsm)
    context = %{context | extra: new_extra}

    # Persist to storage
    key = context.extra[:fsm_key]
    storage = context.extra[:fsm_storage]

    if key && storage do
      case storage.set_state(key, new_fsm) do
        :ok ->
          :ok

        {:error, reason} ->
          require Logger

          Logger.error(
            "ExGram.FSM storage write failed (update_data/set_state): #{inspect(reason)}"
          )
      end
    end

    context
  end

  @doc """
  Resets the FSM to a clean state: no active flow, no state, no data.

  Calls `storage.clear/1` to remove the user's FSM record entirely.

  ## Example

      def handle({:command, :cancel, _}, context) do
        context
        |> clear_flow()
        |> answer("Cancelled. Send /start to begin again.")
      end
  """
  @spec clear_flow(ExGram.Cnt.t()) :: ExGram.Cnt.t()
  def clear_flow(context) do
    key = context.extra[:fsm_key]
    storage = context.extra[:fsm_storage]
    new_fsm = %State{flow: nil, state: nil, data: %{}}

    # Update in-memory
    new_extra = Map.put(context.extra, :fsm, new_fsm)
    context = %{context | extra: new_extra}

    # Clear from storage
    if key && storage do
      case storage.clear(key) do
        :ok ->
          :ok

        {:error, reason} ->
          require Logger
          Logger.error("ExGram.FSM storage write failed (clear_flow): #{inspect(reason)}")
      end
    end

    context
  end

  # --- Private helpers ---

  @spec do_set_state(ExGram.Cnt.t(), atom()) :: ExGram.Cnt.t()
  defp do_set_state(context, new_state) do
    current_fsm = context.extra[:fsm] || %State{}
    new_fsm = %{current_fsm | state: new_state}
    do_update_context(context, new_fsm)
  end

  @spec do_update_context(ExGram.Cnt.t(), State.t()) :: ExGram.Cnt.t()
  defp do_update_context(context, new_fsm_state) do
    # 1. Update in-memory (for pipeline)
    new_extra = Map.put(context.extra, :fsm, new_fsm_state)
    context = %{context | extra: new_extra}

    # 2. Write to storage (for next update)
    key = context.extra[:fsm_key]
    storage = context.extra[:fsm_storage]

    if key && storage do
      case storage.set_state(key, new_fsm_state) do
        :ok ->
          :ok

        {:error, reason} ->
          require Logger
          Logger.error("ExGram.FSM storage write failed (set_state): #{inspect(reason)}")
      end
    end

    context
  end

  @spec valid_transition?(module() | nil, atom() | nil, atom()) :: boolean()
  defp valid_transition?(nil, _from, _to), do: true

  defp valid_transition?(states_mod, from, to) do
    if Code.ensure_loaded?(states_mod) && function_exported?(states_mod, :transitions, 0) do
      case states_mod.transitions() do
        :any ->
          true

        transitions_map when is_map(transitions_map) ->
          allowed = Map.get(transitions_map, from, [])
          to in allowed
      end
    else
      true
    end
  end

  @spec handle_invalid_transition(ExGram.Cnt.t(), atom() | nil, atom()) :: ExGram.Cnt.t()
  defp handle_invalid_transition(context, from, to) do
    policy = context.extra[:fsm_on_invalid_transition] || :raise

    case policy do
      :raise ->
        raise ExGram.FSM.TransitionError, from: from, to: to

      :log ->
        require Logger

        Logger.warning(
          "ExGram.FSM: invalid transition from #{inspect(from)} to #{inspect(to)}, ignoring"
        )

        context

      :ignore ->
        context

      {module, function} when is_atom(module) and is_atom(function) ->
        apply(module, function, [context, from, to])
    end
  end
end
