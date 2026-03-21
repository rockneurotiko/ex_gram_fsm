defmodule ExGram.FSM.Filter.State do
  @moduledoc """
  An `ExGram.Router.Filter` that matches on the current FSM state or FSM data.

  This filter is automatically registered as the `:fsm_state` alias when
  `use ExGram.FSM` detects that `use ExGram.Router` has also been called on
  the same module.

  ## Usage

  Match on FSM state atom:

      scope do
        filter :fsm_state, :get_name
        filter :text
        handle &MyBot.Handlers.got_name/1
      end

  Match on a key in FSM data:

      scope do
        filter :fsm_state, {:step, :confirm}
        handle &MyBot.Handlers.confirm/1
      end

  ## Options

  - `atom` — matches when `context.extra.fsm.state == atom`
  - `{key, value}` — matches when `context.extra.fsm.data[key] == value`
  - `nil` — matches when there is no FSM state set (`state == nil`)
  """

  @behaviour ExGram.Router.Filter

  alias ExGram.FSM.State

  @impl ExGram.Router.Filter
  @doc """
  Filter callback.

  - `opts` is an atom: returns `true` when the current FSM state equals that atom.
  - `opts` is `{key, value}`: returns `true` when `context.extra.fsm.data[key] == value`.
  """
  @spec call(term(), ExGram.Cnt.t(), atom() | nil | {term(), term()}) :: boolean()
  def call(_update_info, context, expected_state) when is_atom(expected_state) do
    case context.extra do
      %{fsm: %State{state: ^expected_state}} -> true
      _ -> false
    end
  end

  def call(_update_info, context, {data_key, expected_value}) do
    case context.extra do
      %{fsm: %State{data: data}} -> Map.get(data, data_key) == expected_value
      _ -> false
    end
  end
end
