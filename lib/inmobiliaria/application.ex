defmodule Inmobiliaria.Application do
  use Application

  # Punto de entrada de la aplicación. Inicializa los archivos de datos, detecta si corre
  # en modo cliente o servidor, y arranca todos los procesos supervisados.
  @impl true
  def start(_type, _args) do
    Inmobiliaria.Persistence.init_files()

    es_cliente = System.get_env("MODO") == "cliente"

    children = [
      {Phoenix.PubSub, name: Inmobiliaria.PubSub},
      {Registry, keys: :unique, name: Inmobiliaria.PropertyRegistry},
      {DynamicSupervisor, name: Inmobiliaria.PropertySupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Inmobiliaria.ClientSupervisor, strategy: :one_for_one},
      Inmobiliaria.UserManager,
      Inmobiliaria.PropertyManager,
      Inmobiliaria.MessageManager,
      InmobiliariaWeb.Endpoint
    ] ++ if es_cliente, do: [], else: [Inmobiliaria.Listener]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
