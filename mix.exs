defmodule Inmobiliaria.MixProject do
  use Mix.Project

  def project do
    [
      app: :inmobiliaria,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      config_path: "config/config.exs",
      deps: deps()
    ]
  end

  # Aquí le decimos a Elixir qué módulo arranca la aplicación
  def application do
  [
    mod: {Inmobiliaria.Application, []},
    extra_applications: [:logger, :inets, :crypto]
  ]
end

  # Sin dependencias externas por ahora (todo con la librería estándar)
defp deps do
  [
    {:phoenix, "~> 1.7"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},
    {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
    {:bandit, "~> 1.2"},
    {:jason, "~> 1.2"}
  ]
end
end
