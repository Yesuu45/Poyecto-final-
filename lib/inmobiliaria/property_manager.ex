defmodule Inmobiliaria.PropertyManager do
  use GenServer
  alias Inmobiliaria.{Persistence, Property}

  @filename "properties.dat"

  # Inicia el GenServer de propiedades.
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  # Publica una nueva propiedad asociada a un propietario.
  def publish(propietario, attrs), do: GenServer.call(__MODULE__, {:publish, propietario, attrs})

  # Lista todas las propiedades, opcionalmente aplicando filtros.
  def list(filtros \\ %{}), do: GenServer.call(__MODULE__, {:list, filtros})

  # Busca una propiedad por su ID.
  def obtener(id), do: GenServer.call(__MODULE__, {:get_property, id})

  # Ejecuta una operación (compra o arriendo) sobre una propiedad.
  def operate(id, cliente, operacion), do: GenServer.call(__MODULE__, {:operate, id, cliente, operacion})

  # Actualiza el estado de una propiedad de forma asíncrona.
  def update(id, nuevo_estado), do: GenServer.cast(__MODULE__, {:update, id, nuevo_estado})

  # Carga las propiedades desde el archivo e inicia un proceso individual por cada una.
  @impl true
  def init(_opts) do
    propiedades = cargar_propiedades()
    Enum.each(propiedades, fn {_id, prop} -> start_property_process(prop) end)
    {:ok, propiedades}
  end

  # Maneja la creación de una nueva propiedad, genera su ID, inicia su proceso y persiste.
  @impl true
  def handle_call({:publish, propietario, attrs}, _from, propiedades) do
    id = generar_id(propiedades)
    prop = %{id: id, tipo: Map.get(attrs, "tipo", "casa"), modalidad: Map.get(attrs, "modalidad", "venta"),
             ubicacion: Map.get(attrs, "ubicacion", "desconocida"), precio: parse_int(Map.get(attrs, "precio")),
             habitaciones: parse_int(Map.get(attrs, "habitaciones")), area: parse_int(Map.get(attrs, "area")),
             estado: "disponible", propietario: propietario}
    start_property_process(prop)
    new_state = Map.put(propiedades, id, prop)
    guardar_propiedades(new_state)
    {:reply, {:ok, prop}, new_state}
  end

  # Maneja el listado de propiedades aplicando los filtros recibidos.
  @impl true
  def handle_call({:list, filtros}, _from, propiedades) do
    {:reply, propiedades |> Map.values() |> Enum.filter(&apply_filters(&1, filtros)), propiedades}
  end

  # Maneja la búsqueda de una propiedad por ID.
  @impl true
  def handle_call({:get_property, id}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      prop -> {:reply, {:ok, prop}, propiedades}
    end
  end

  # Maneja la operación sobre una propiedad delegando al proceso individual de la misma.
  @impl true
  def handle_call({:operate, id, _cliente, operacion}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      _prop ->
        case Property.operate(id, operacion) do
          {:ok, prop_actualizada} ->
            new_state = Map.put(propiedades, id, prop_actualizada)
            guardar_propiedades(new_state)
            {:reply, {:ok, prop_actualizada}, new_state}
          {:error, razon} -> {:reply, {:error, razon}, propiedades}
        end
    end
  end

  # Maneja la actualización asíncrona del estado de una propiedad y la persiste.
  @impl true
  def handle_cast({:update, id, nuevo_estado}, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:noreply, propiedades}
      prop ->
        actualizada = %{prop | estado: nuevo_estado}
        guardar_propiedades(Map.put(propiedades, id, actualizada))
        {:noreply, Map.put(propiedades, id, actualizada)}
    end
  end

  # Lanza un proceso hijo individual para una propiedad bajo el supervisor dinámico.
  defp start_property_process(prop) do
    DynamicSupervisor.start_child(Inmobiliaria.PropertySupervisor, {Property, prop})
  end

  # Evalúa si una propiedad cumple con todos los filtros especificados.
  defp apply_filters(prop, filtros) do
    Enum.all?(filtros, fn
      {"tipo", v} -> prop.tipo == v
      {"modalidad", v} -> prop.modalidad == v
      {"ubicacion", v} -> String.downcase(prop.ubicacion) == String.downcase(v)
      {"estado", v} -> prop.estado == v
      {"precio_min", v} -> prop.precio >= parse_int(v)
      {"precio_max", v} -> prop.precio <= parse_int(v)
      _ -> true
    end)
  end

  # Lee y parsea el archivo properties.dat para reconstruir el mapa de propiedades.
  defp cargar_propiedades do
    Persistence.read_lines(@filename)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, "|") do
        [id, tipo, mod, ubi, prec, hab, area, est, prop] ->
          Map.put(acc, id, %{id: id, tipo: tipo, modalidad: mod, ubicacion: ubi,
            precio: String.to_integer(prec), habitaciones: String.to_integer(hab),
            area: String.to_integer(area), estado: est, propietario: prop})
        _ -> acc
      end
    end)
  end

  # Serializa y escribe todas las propiedades en properties.dat.
  defp guardar_propiedades(props) do
    Persistence.write_lines(@filename, Enum.map(props, fn {_id, p} ->
      "#{p.id}|#{p.tipo}|#{p.modalidad}|#{p.ubicacion}|#{p.precio}|#{p.habitaciones}|#{p.area}|#{p.estado}|#{p.propietario}"
    end))
  end

  # Genera un ID único para una nueva propiedad con formato prop_XXX.
  defp generar_id(propiedades), do: "prop_#{String.pad_leading(Integer.to_string(map_size(propiedades) + 1), 3, "0")}"

  # Convierte un valor a entero de forma segura.
  defp parse_int(v), do: if(is_integer(v), do: v, else: (case Integer.parse("#{v}") do {n, _} -> n; :error -> 0 end))
end
