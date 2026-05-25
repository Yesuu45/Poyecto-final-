defmodule Inmobiliaria.MixProject do
  @moduledoc """
  Configuración central del proyecto (Mix Project).
  Define los metadatos del sistema, las dependencias del ecosistema Phoenix/Bandit,
  las aplicaciones OTP adicionales y los ganchos de compilación para la infraestructura inmobiliaria.
  """
  use Mix.Project

  @doc """
  Define la configuración general y metadatos del proyecto.
  """
  def project do
    [
      app: :inmobiliaria,
      version: "0.1.0",
      elixir: "~> 1.14",
      # Si estamos en producción, los fallos en procesos principales provocan el cierre inmediato del nodo
      start_permanent: Mix.env() == :prod,
      config_path: "config/config.exs",
      deps: deps()
    ]
  end

  @doc """
  Configura las especificaciones de la aplicación OTP resultante.
  Indica el punto de entrada raíz del Supervision Tree y carga los servicios del sistema.
  """
  def application do
    [
      # Callback que apunta al módulo Application para iniciar el árbol de supervisión
      mod: {Inmobiliaria.Application, []},
      # Aplicaciones nativas extras requeridas para criptografía, red y logs de la BEAM
      extra_applications: [:logger, :inets, :crypto]
    ]
  end

  @doc """
  Lista de dependencias externas del proyecto administradas por Hex.
  Incluye el core de Phoenix, el servidor HTTP Bandit y utilidades de serialización.
  """
  defp deps do
    [
      # Framework principal y abstracción HTML
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.0"},

      # Motor reactivo en tiempo real mediante WebSockets
      {:phoenix_live_view, "~> 0.20"},

      # Recarga de código en caliente (Hot Code Reloading) exclusiva para desarrollo
      {:phoenix_live_reload, "~> 1.2", only: :dev},

      # Compiladores y empaquetadores de assets (JS y CSS Tailwind)
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},

      # Servidor HTTP de alto rendimiento nativo en Elixir (reemplazo moderno de Cowboy)
      {:bandit, "~> 1.2"},

      # Serializador/Decodificador JSON ultra rápido escrito en C embebido
      {:jason, "~> 1.2"}
    ]
  end
end
