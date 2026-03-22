defmodule ExGram.FSM.TransitionError do
  @moduledoc """
  Exception raised when an invalid FSM transition is attempted and the
  `on_invalid_transition` policy is `:raise` (the default).

  ## Fields

  - `message` - human-readable error message
  - `from` - the source state atom
  - `to` - the attempted target state atom

  ## Example

      # When :raise policy is active:
      transition(context, :confirm)
      # => raises %ExGram.FSM.TransitionError{from: :idle, to: :confirm, ...}

  ## Handling in the bot

      def handle_error(%ExGram.Error{error: %ExGram.FSM.TransitionError{from: from, to: to}}) do
        Logger.error("Invalid FSM transition: \#{from} -> \#{to}")
      end
  """

  defexception [:message, :from, :to]

  @impl true
  def exception(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    msg = "invalid FSM transition from :#{from} to :#{to}"

    %__MODULE__{
      from: from,
      message: msg,
      to: to
    }
  end
end
