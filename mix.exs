defmodule ExGramFsm.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/rockneurotiko/ex_gram_fsm"

  def project do
    [
      app: :ex_gram_fsm,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "ExGram FSM",
      source_url: @source_url,
      docs: docs(),
      dialyzer: dialyzer(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_gram, "~> 0.60"},
      # ex_gram_router is not yet published on Hex; switch to `{:ex_gram_router, "~> 0.1.0"}` once released
      {:ex_gram_router, github: "rockneurotiko/ex_gram_router", optional: true},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Multi-flow Finite State Machine and conversation state management for ExGram Telegram bots."
  end

  defp package do
    [
      maintainers: ["rockneurotiko"],
      licenses: ["Beerware"],
      links: %{
        "GitHub" => @source_url,
        "ExGram" => "https://hex.pm/packages/ex_gram"
      },
      files: ~w(.formatter.exs lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v" <> @version,
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Core: [
          ExGram.FSM,
          ExGram.FSM.Flow,
          ExGram.FSM.States,
          ExGram.FSM.State,
          ExGram.FSM.Helpers
        ],
        Storage: [ExGram.FSM.Storage, ExGram.FSM.Storage.ETS],
        "Key Adapters": [
          ExGram.FSM.Key,
          ExGram.FSM.Key.ChatUser,
          ExGram.FSM.Key.User,
          ExGram.FSM.Key.Chat,
          ExGram.FSM.Key.ChatTopic,
          ExGram.FSM.Key.ChatTopicUser
        ],
        Filters: [ExGram.FSM.Filter.Flow, ExGram.FSM.Filter.State],
        Internals: [ExGram.FSM.Middleware, ExGram.FSM.Validator, ExGram.FSM.TransitionError]
      ]
    ]
  end

  defp dialyzer do
    [plt_file: {:no_warn, "priv/plts/dialyzer.plt"}, plt_add_apps: [:mix]]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo",
        "dialyzer"
      ]
    ]
  end
end
