defmodule Inmobiliaria.Property do
  use GenServer, restart: :temporary

  def start_link(prop) do
    GenServer.start_link(__MODULE__, prop,
      name: {:via, Registry, {Inmobiliaria.PropertyRegistry, prop.id}}
    )
  end

  # Ejecuta una operación (compra/arriendo/reserva) sobre la propiedad.
  # Devuelve {:ok, nuevo_estado} o {:error, razon} sin llamar de vuelta a PropertyManager.
  def operate(id, op, comprador \\ nil) do
    case GenServer.whereis({:via, Registry, {Inmobiliaria.PropertyRegistry, id}}) do
      nil -> {:error, "Propiedad no encontrada"}
      pid -> GenServer.call(pid, {:operate, op, comprador})
    end
  end

  # Aplica cambios de edición (modalidad, estado, precio) sobre la propiedad.
  # Devuelve {:ok, nuevo_estado} sin llamar de vuelta a PropertyManager.
  def editar(id, cambios) do
    case GenServer.whereis({:via, Registry, {Inmobiliaria.PropertyRegistry, id}}) do
      nil -> {:error, "Propiedad no encontrada"}
      pid -> GenServer.call(pid, {:editar, cambios})
    end
  end

  # Sincroniza el estado del proceso Property con un mapa externo (usado por PropertyManager
  # después de persistir, para mantener ambos estados consistentes).
  def sync(id, prop) do
    case GenServer.whereis({:via, Registry, {Inmobiliaria.PropertyRegistry, id}}) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:sync, prop})
    end
  end

  @impl true
  def init(prop), do: {:ok, Map.put_new(prop, :comprador, "")}

  # Maneja operaciones de compra, arriendo y reserva.
  # Actualiza solo su estado interno; NO llama a PropertyManager.
  @impl true
  def handle_call({:operate, op, comprador}, _from, state) do
    result =
      case op do
        "reservar" when state.estado == "disponible" ->
          {:ok, %{state | estado: "reservada"}}

        "compra" when state.estado in ["disponible", "reservada"] ->
          # Al comprar: el cliente pasa a ser propietario
          {:ok, %{state | estado: "vendida", propietario: comprador, comprador: comprador}}

        "arriendo" when state.estado in ["disponible", "reservada"] ->
          # Al arrendar: propietario NO cambia, solo estado y arrendatario referencial
          {:ok, %{state | estado: "arrendada", comprador: comprador}}

        _ ->
          {:error, "Operacion invalida. Estado actual: #{state.estado}"}
      end

    case result do
      {:ok, new_state} ->
        # Solo actualiza su propio estado; PropertyManager se encarga de persistir
        {:reply, {:ok, new_state}, new_state}
      {:error, razon} ->
        {:reply, {:error, razon}, state}
    end
  end

  # Maneja edición de atributos (modalidad, estado, precio).
  # Actualiza solo su estado interno; NO llama a PropertyManager.
  @impl true
  def handle_call({:editar, cambios}, _from, state) do
    new_state = Map.merge(state, cambios)
    # Solo actualiza su propio estado; PropertyManager se encarga de persistir
    {:reply, {:ok, new_state}, new_state}
  end

  # Recibe una sincronización de estado desde PropertyManager (cast, nunca bloquea).
  @impl true
  def handle_cast({:sync, prop}, _state) do
    {:noreply, prop}
  end
end
