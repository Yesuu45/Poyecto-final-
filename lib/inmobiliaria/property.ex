defmodule Inmobiliaria.Property do
  use GenServer

  def start_link(prop), do: GenServer.start_link(__MODULE__, prop, name: via(prop.id))

  def operate(id, operacion), do: GenServer.call(via(id), {:operate, operacion})

  @impl true
  def init(prop), do: {:ok, prop}

  @impl true
  def handle_call({:operate, operacion}, _from, prop) do
    cond do
      prop.estado != "disponible" ->
        {:reply, {:error, "Propiedad no disponible (Estado: #{prop.estado})"}, prop}

      operacion == "compra" and prop.modalidad != "venta" ->
        {:reply, {:error, "Propiedad no disponible para compra (Modalidad: #{prop.modalidad})"}, prop}

      operacion == "arriendo" and prop.modalidad != "arriendo" ->
        {:reply, {:error, "Propiedad no disponible para arriendo (Modalidad: #{prop.modalidad})"}, prop}

      true ->
        nuevo_estado = if operacion == "compra", do: "vendida", else: "arrendada"
        updated = %{prop | estado: nuevo_estado}

        # Sincroniza de vuelta al PropertyManager central
        Inmobiliaria.PropertyManager.update(prop.id, nuevo_estado)
        {:reply, {:ok, updated}, updated}
    end
  end

  defp via(id), do: {:via, Registry, {Inmobiliaria.PropertyRegistry, {:property, id}}}
end
