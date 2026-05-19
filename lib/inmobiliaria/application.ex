defmodule Inmobiliaria.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Inmobiliaria.Persistence.init_files()

    children = [
      {Registry, keys: :unique, name: Inmobiliaria.PropertyRegistry},
      {DynamicSupervisor, name: Inmobiliaria.PropertySupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Inmobiliaria.ClientSupervisor, strategy: :one_for_one},
      Inmobiliaria.UserManager,
      Inmobiliaria.PropertyManager,
      Inmobiliaria.MessageManager,
      Inmobiliaria.Listener
    ]

    opts = [strategy: :one_for_one, name: Inmobiliaria.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
