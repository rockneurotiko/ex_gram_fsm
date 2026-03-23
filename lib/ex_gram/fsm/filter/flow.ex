defmodule ExGram.FSM.Filter.Flow do
  @moduledoc """
  An `ExGram.Router.Filter` that matches on the current active FSM flow name.

  This filter is automatically registered as the `:fsm_flow` alias when
  `use ExGram.FSM` detects that `use ExGram.Router` has also been called on
  the same module.

  ## Usage

  Combine with `:fsm_state` to scope routes to a specific flow and step:

      scope do
        filter :fsm_flow, :registration
        filter :fsm_state, :get_name
        filter :text
        handle &MyBot.Handlers.got_name/1
      end

      scope do
        filter :fsm_flow, :settings
        filter :fsm_state, :choose_language
        filter :text
        handle &MyBot.Handlers.set_language/1
      end

  Match on "no active flow":

      scope do
        filter :fsm_flow, nil
        filter :command, :start
        handle &MyBot.Handlers.start/1
      end

  ## Options

  - `atom` — matches when `context.extra.fsm.flow == atom`
  - `nil` — matches when there is no active flow (`flow == nil`)
  """

  @behaviour ExGram.Router.Filter

  alias ExGram.FSM.State

  @impl ExGram.Router.Filter
  @doc """
  Filter callback.

  Returns `true` when the current FSM flow name equals `expected_flow`.
  """
  @spec call(term(), ExGram.Cnt.t(), atom() | nil) :: boolean()
  def call(_update_info, context, expected_flow) when is_atom(expected_flow) do
    case context.extra do
      %{fsm: %State{flow: ^expected_flow}} -> true
      _ -> false
    end
  end

  @impl ExGram.Router.Filter
  def format_filter(nil), do: "FSM.Flow(nil)"
  def format_filter(expected_flow) when is_atom(expected_flow), do: "FSM.Flow(name=#{inspect(expected_flow)})"
end
