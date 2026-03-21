defmodule ExGram.FSM.Middleware do
  @moduledoc """
  ExGram middleware that loads FSM state before every handler call.

  This middleware is automatically registered by `use ExGram.FSM`. You don't
  need to add it manually.

  ## What it does

  Before every `handle/2` call, this middleware:
  1. Extracts a storage key from the update using the configured `ExGram.FSM.Key` module
  2. Reads the FSM state from the configured storage backend
  3. Writes the state and config into `context.extra`

  ## Context keys populated

  After this middleware runs, `context.extra` contains:

  | Key | Type | Description |
  |-----|------|-------------|
  | `:fsm` | `%ExGram.FSM.State{}` | Current flow + state + data |
  | `:fsm_key` | `term()` | The storage key (shape depends on configured key module) |
  | `:fsm_storage` | module | Storage backend module |
  | `:fsm_flows` | `%{atom => module}` | Map of registered flow name → flow module |
  | `:fsm_on_invalid_transition` | atom or tuple | Invalid transition policy |

  ## FSM key strategy

  The key is extracted by the module set via the `key:` option in `use ExGram.FSM`
  (default: `ExGram.FSM.Key.ChatUser`). See `ExGram.FSM.Key` for built-in options
  and how to implement a custom strategy.
  """

  @behaviour ExGram.Middleware

  alias ExGram.FSM.State

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%ExGram.Cnt{} = cnt, opts) do
    storage = Keyword.fetch!(opts, :storage)
    key_mod = Keyword.get(opts, :key, ExGram.FSM.Key.ChatUser)
    flows_map = build_flows_map(opts)

    case key_mod.extract(cnt) do
      {:ok, key} ->
        ensure_storage_init(storage, opts)
        fsm_state = storage.get_state(key) || %State{}

        cnt
        |> ExGram.Middleware.add_extra(:fsm, fsm_state)
        |> ExGram.Middleware.add_extra(:fsm_key, key)
        |> ExGram.Middleware.add_extra(:fsm_storage, storage)
        |> ExGram.Middleware.add_extra(
          :fsm_on_invalid_transition,
          Keyword.get(opts, :on_invalid_transition, :raise)
        )
        |> ExGram.Middleware.add_extra(:fsm_flows, flows_map)

      :error ->
        # Key could not be extracted (e.g., channel post with no user for a user-scoped key).
        # Set empty FSM state so handlers don't crash on missing key.
        ExGram.Middleware.add_extra(cnt, :fsm, %State{})
    end
  end

  # --- Private helpers ---

  # Build %{flow_name_atom => module} from either :flows (already built) or :flow_modules (list)
  @spec build_flows_map(keyword()) :: %{atom() => module()}
  defp build_flows_map(opts) do
    cond do
      # Pre-built map (passed directly in tests or older call sites)
      flows = Keyword.get(opts, :flows) ->
        flows

      # List of flow modules (from use ExGram.FSM, flows: [...])
      mods = Keyword.get(opts, :flow_modules) ->
        mods
        |> Enum.reduce(%{}, fn mod, acc ->
          try do
            Map.put(acc, mod.flow_name(), mod)
          rescue
            UndefinedFunctionError -> acc
          end
        end)

      true ->
        %{}
    end
  end

  @spec ensure_storage_init(module(), keyword()) :: :ok
  defp ensure_storage_init(storage, opts) do
    pt_key = {__MODULE__, :init, storage}

    if !:persistent_term.get(pt_key, false) do
      storage.init(opts)
      :persistent_term.put(pt_key, true)
    end

    :ok
  end
end
