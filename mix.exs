defmodule Inmobiliaria.MixProject do
  use Mix.Project

  def project do
    [
      app: :inmobiliaria,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Aquí le decimos a Elixir qué módulo arranca la aplicación
  def application do
    [
      mod: {Inmobiliaria.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Sin dependencias externas por ahora (todo con la librería estándar)
  defp deps do
    []
  end
end
