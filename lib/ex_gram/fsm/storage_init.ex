defmodule ExGram.FSM.StorageInit do
  @moduledoc """
  `ExGram.BotInit` hook that initialises the FSM storage backend at bot startup.

  This hook is automatically registered by `use ExGram.FSM` — you do not need
  to add it manually. It calls `storage.init/2` once per bot during the startup
  sequence, before the bot begins processing updates.

  The hook receives the bot name atom via `opts[:bot]` (provided by the ExGram
  dispatcher) and the storage module via `opts[:storage]` (injected by
  `use ExGram.FSM`).
  """

  @behaviour ExGram.BotInit

  @impl ExGram.BotInit
  def on_bot_init(opts) do
    bot_name = Keyword.fetch!(opts, :bot)
    storage = Keyword.fetch!(opts, :storage)
    storage.init(bot_name, opts)
  end
end
