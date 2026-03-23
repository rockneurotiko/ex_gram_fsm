defmodule ExGram.FSM.Filter.InFlow do
  @moduledoc """
  An `ExGram.Router.Filter` that matches when any FSM flow is active.

  This filter is automatically registered as the `:in_flow` alias when
  `use ExGram.FSM` detects that `use ExGram.Router` has also been called on
  the same module.

  ## Usage

  Use in a scope to match when any flow is active:

      scope do
        filter :in_flow
        handle &MyBot.Handlers.in_flow/1
      end
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call(_update_info, context, _) do
    case context.extra do
      %{fsm: %ExGram.FSM.State{flow: flow}} when flow != nil -> true
      _ -> false
    end
  end

  @impl ExGram.Router.Filter
  def format_filter(_), do: "InFlow"
end
