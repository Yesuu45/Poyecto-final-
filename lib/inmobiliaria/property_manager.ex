defmodule Inmobiliaria.PropertyManager do
  use GenServer
  alias Inmobiliaria.{Persistence, Property}

  @filename "properties.dat"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def publish(propietario, attrs),
    do: GenServer.call(__MODULE__, {:publish, propietario, attrs})

  def list(filtros \\ %{}), do: GenServer.call(__MODULE__, {:list, filtros})

  def obtener(id), do: GenServer.call(__MODULE__, {:get_property, id})

  def operate(id, cliente, operacion),
    do: GenServer.call(__MODULE__, {:operate, id, cliente, operacion})

  # Actualiza solo el estado (cast asíncrono, usado internamente si no necesita sincronía)
  def update(id, nuevo_estado),
    do: GenServer.cast(__MODULE__, {:update, id, nuevo_estado})

  # Ya no se usa externamente; se mantiene por compatibilidad con código existente.
  # PropertyManager ahora gestiona la persistencia directamente tras cada operación.
  def update_full(prop),
    do: GenServer.cast(__MODULE__, {:update_full, prop})

  # El propietario o arrendatario activo edita su propiedad (modalidad, estado, precio)
  def editar(id, username, cambios),
    do: GenServer.call(__MODULE__, {:editar, id, username, cambios})

  @impl true
  def init(_opts) do
    propiedades = cargar_propiedades()

    propiedades =
      if map_size(propiedades) == 0 do
        seeds = %{
          "prop_001" => %{id: "prop_001", tipo: "casa", modalidad: "venta",
            ubicacion: "Armenia", precio: 250_000, habitaciones: 3,
            area: 120, estado: "disponible", propietario: "admin", comprador: ""},
          "prop_002" => %{id: "prop_002", tipo: "apartamento", modalidad: "arriendo",
            ubicacion: "Bogota", precio: 1_500, habitaciones: 2,
            area: 65, estado: "disponible", propietario: "admin", comprador: ""},
          "prop_003" => %{id: "prop_003", tipo: "casa", modalidad: "venta",
            ubicacion: "Medellin", precio: 180_000, habitaciones: 4,
            area: 200, estado: "disponible", propietario: "admin", comprador: ""},
          "prop_004" => %{id: "prop_004", tipo: "local", modalidad: "arriendo",
            ubicacion: "Cali", precio: 2_000, habitaciones: 0,
            area: 80, estado: "disponible", propietario: "admin", comprador: ""},
          "prop_005" => %{id: "prop_005", tipo: "oficina", modalidad: "venta",
            ubicacion: "Pereira", precio: 120_000, habitaciones: 0,
            area: 55, estado: "disponible", propietario: "admin", comprador: ""}
        }
        guardar_propiedades(seeds)
        seeds
      else
        propiedades
      end

    Enum.each(propiedades, fn {_id, prop} -> start_property_process(prop) end)
    {:ok, propiedades}
  end

  @impl true
  def handle_call({:publish, propietario, attrs}, _from, propiedades) do
    id = generar_id(propiedades)
    prop = %{
      id: id,
      tipo: Map.get(attrs, "tipo", "casa"),
      modalidad: Map.get(attrs, "modalidad", "venta"),
      ubicacion: Map.get(attrs, "ubicacion", "desconocida"),
      precio: parse_int(Map.get(attrs, "precio")),
      habitaciones: parse_int(Map.get(attrs, "habitaciones")),
      area: parse_int(Map.get(attrs, "area")),
      estado: "disponible",
      propietario: propietario,
      comprador: ""
    }
    start_property_process(prop)
    new_state = Map.put(propiedades, id, prop)
    guardar_propiedades(new_state)
    {:reply, {:ok, prop}, new_state}
  end

  @impl true
  def handle_call({:list, filtros}, _from, propiedades) do
    {:reply,
     propiedades |> Map.values() |> Enum.filter(&apply_filters(&1, filtros)),
     propiedades}
  end

  @impl true
  def handle_call({:get_property, id}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil  -> {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      prop -> {:reply, {:ok, prop}, propiedades}
    end
  end

  # Ejecuta una operación (compra/arriendo) delegando la lógica al proceso Property,
  # luego persiste el resultado aquí mismo para evitar llamadas circulares entre GenServers.
  @impl true
  def handle_call({:operate, id, cliente, operacion}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      _prop ->
        case Property.operate(id, operacion, cliente) do
          {:ok, prop_actualizada} ->
            # PropertyManager persiste el resultado; Property NO llama de vuelta aquí
            new_state = Map.put(propiedades, id, prop_actualizada)
            guardar_propiedades(new_state)
            {:reply, {:ok, prop_actualizada}, new_state}
          {:error, razon} ->
            {:reply, {:error, razon}, propiedades}
        end
    end
  end

  # Verifica que el usuario sea propietario O arrendatario activo antes de editar.
  # Delega la lógica de cambio al proceso Property y persiste aquí mismo.
  # Verifica que el usuario sea el propietario principal antes de editar.
  # Delega la lógica de cambio al proceso Property y persiste aquí mismo.
  @impl true
  def handle_call({:editar, id, username, cambios}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil ->
        {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      prop ->
        # Determinar quién es el dueño actual según el estado de la propiedad
        es_dueno_actual =
          if prop.estado == "vendida" do
            prop.comprador == username
          else
            prop.propietario == username
          end

        if es_dueno_actual do
          case Property.editar(id, cambios) do
            {:ok, prop_actualizada} ->
              new_state = Map.put(propiedades, id, prop_actualizada)
              guardar_propiedades(new_state)
              {:reply, {:ok, prop_actualizada}, new_state}
            {:error, r} ->
              {:reply, {:error, r}, propiedades}
          end
        else
          {:reply, {:error, "Acceso denegado: No eres el dueño actual de esta propiedad"}, propiedades}
        end
    end
  end

  # Reemplaza la propiedad completa en el estado y persiste (cast, no bloquea al llamador).
  # Usado como fallback desde código legado o desde Property si fuera necesario.
  @impl true
  def handle_cast({:update_full, prop}, propiedades) do
    new_state = Map.put(propiedades, prop.id, prop)
    guardar_propiedades(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update, id, nuevo_estado}, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:noreply, propiedades}
      prop ->
        actualizada = %{prop | estado: nuevo_estado}
        new_state   = Map.put(propiedades, id, actualizada)
        guardar_propiedades(new_state)
        {:noreply, new_state}
    end
  end

  defp start_property_process(prop) do
    DynamicSupervisor.start_child(Inmobiliaria.PropertySupervisor, {Property, prop})
  end

  defp apply_filters(prop, filtros) do
    Enum.all?(filtros, fn
      {"tipo",       v} -> prop.tipo == v
      {"modalidad",  v} -> prop.modalidad == v
      {"ubicacion",  v} -> String.downcase(prop.ubicacion) == String.downcase(v)
      {"estado",     v} -> prop.estado == v
      {"precio_min", v} -> prop.precio >= parse_int(v)
      {"precio_max", v} -> prop.precio <= parse_int(v)
      _                 -> true
    end)
  end

  defp cargar_propiedades do
    Persistence.read_lines(@filename)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(String.trim(line), "|") do
        [id, tipo, mod, ubi, prec, hab, area, est, prop | resto] ->
          comprador = resto |> List.first("") |> String.trim()
          Map.put(acc, String.trim(id), %{
            id:           String.trim(id),
            tipo:         String.trim(tipo),
            modalidad:    String.trim(mod),
            ubicacion:    String.trim(ubi),
            precio:       String.to_integer(String.trim(prec)),
            habitaciones: String.to_integer(String.trim(hab)),
            area:         String.to_integer(String.trim(area)),
            estado:       String.trim(est),
            propietario:  String.trim(prop),
            comprador:    comprador
          })
        _ -> acc
      end
    end)
  end

  defp guardar_propiedades(props) do
    Persistence.write_lines(@filename, Enum.map(props, fn {_id, p} ->
      comprador = Map.get(p, :comprador, "")
      "#{p.id}|#{p.tipo}|#{p.modalidad}|#{p.ubicacion}|#{p.precio}|#{p.habitaciones}|#{p.area}|#{p.estado}|#{p.propietario}|#{comprador}"
    end))
  end

  defp generar_id(propiedades),
    do: "prop_#{String.pad_leading(Integer.to_string(map_size(propiedades) + 1), 3, "0")}"

  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) do
    case Integer.parse("#{v}") do
      {n, _} -> n
      :error -> 0
    end
  end
end
