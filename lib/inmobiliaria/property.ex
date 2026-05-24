defmodule Inmobiliaria.Property do
  use GenServer, restart: :temporary

  # --- API Pública ---

  # Inicia el proceso GenServer de una propiedad individual, registrándolo en el Registry por su ID.
  def start_link(prop) do
    GenServer.start_link(__MODULE__, prop,
      name: {:via, Registry, {Inmobiliaria.PropertyRegistry, prop.id}}
    )
  end

  # Localiza el proceso de una propiedad y le envía una operación (compra, arriendo, reserva).
  def operate(id, op) do
    case GenServer.whereis({:via, Registry, {Inmobiliaria.PropertyRegistry, id}}) do
      nil -> {:error, "Propiedad no encontrada"}
      pid -> GenServer.call(pid, {:operate, op})
    end
  end

  # --- Callbacks ---

  # Inicializa el estado del proceso con los datos de la propiedad.
  @impl true
  def init(prop) do
    {:ok, prop}
  end

  # Aplica la operación recibida según el estado actual de la propiedad y notifica al PropertyManager para que persista el cambio.
  @impl true
  def handle_call({:operate, op}, _from, state) do
    result =
      case op do
        "reservar" when state.estado == "disponible" ->
          {:ok, %{state | estado: "reservada"}}

        "compra" when state.estado == "disponible" ->
          {:ok, %{state | estado: "vendida"}}

        "compra" when state.estado == "reservada" ->
          {:ok, %{state | estado: "vendida"}}

        "arriendo" when state.estado == "disponible" ->
          {:ok, %{state | estado: "arrendada"}}

        "arriendo" when state.estado == "reservada" ->
          {:ok, %{state | estado: "arrendada"}}

        _ ->
          {:error, "Operacion invalida. Estado actual: #{state.estado}"}
      end

    case result do
      {:ok, new_state} ->
        # Notificamos al PropertyManager para que persista el cambio en el archivo
        Inmobiliaria.PropertyManager.update(new_state.id, new_state.estado)
        {:reply, {:ok, new_state}, new_state}

      {:error, razon} ->
        {:reply, {:error, razon}, state}
    end
  end
end
