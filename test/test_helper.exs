# Start ExGram supervisor (provides Registry.ExGram, required by ExGram.Test.start_bot/3)
{:ok, _} = ExGram.start_link()

# Start the test adapter's NimbleOwnership server (required for stubs/expects/allow)
{:ok, _} = ExGram.Adapter.Test.start_link()

ExUnit.start()
