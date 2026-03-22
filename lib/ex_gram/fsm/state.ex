defmodule ExGram.FSM.State do
  @moduledoc """
  Struct representing a user's FSM flow, state, and associated data.

  Stored in `context.extra.fsm` by the FSM middleware after every update.

  ## Fields

  - `flow` - the current flow name atom (e.g., `:registration`, `:settings`). `nil` means
    no flow is active (the user hasn't started any conversation flow).
  - `state` - the current step atom within the active flow (e.g., `:get_name`, `:confirm`).
    `nil` means no state is set.
  - `data` - arbitrary map of user data accumulated during the conversation flow.
    Grows via `update_data/2` and is cleared by `clear_flow/1`.
  """

  @type t :: %__MODULE__{
          data: map(),
          flow: atom() | nil,
          state: atom() | nil
        }

  defstruct data: %{}, flow: nil, state: nil
end
