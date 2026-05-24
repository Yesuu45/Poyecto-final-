defmodule Inmobiliaria.Listener do
  use GenServer
  @port 4040

  # Inicia el GenServer del listener TCP.
  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # Abre el socket TCP en el puerto 4040 y lanza el loop de aceptación de conexiones.
  @impl true
  def init(_) do
    {:ok, socket} = :gen_tcp.listen(@port, [
    :binary,
    packet: :line,
    active: false,
    reuseaddr: true,
    ip: {0, 0, 0, 0} # <--- Esto permite que Windows se conecte
    ])
    IO.puts("[Servidor] Escuchando en el puerto #{@port}...")
    spawn_link(fn -> accept_loop(socket) end)
    {:ok, socket}
  end

  # Espera conexiones entrantes indefinidamente; por cada cliente que se conecta,
  # crea un proceso ClientHandler bajo el supervisor dinámico y le transfiere el control del socket.
  defp accept_loop(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client_socket} ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Inmobiliaria.ClientSupervisor,
            {Inmobiliaria.ClientHandler, client_socket}
          )

        :gen_tcp.controlling_process(client_socket, pid)
        accept_loop(socket)

      {:error, _} ->
        accept_loop(socket)
    end
  end
end
