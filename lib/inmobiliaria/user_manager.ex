defmodule Inmobiliaria.UserManager do
  use GenServer

  @data_file "data/users.dat"
  @sep ";"

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def conectar(username, password) do
    GenServer.call(__MODULE__, {:conectar, username, password})
  end

  def conectar_con_rol(username, password, rol) do
    GenServer.call(__MODULE__, {:conectar_con_rol, username, password, rol})
  end

  def obtener(username) do
    GenServer.call(__MODULE__, {:obtener, username})
  end

  def sumar_puntos(username, puntos) do
    GenServer.cast(__MODULE__, {:sumar_puntos, username, puntos})
  end

  def ranking do
    GenServer.call(__MODULE__, :ranking)
  end

  @impl true
  def init(_) do
    usuarios = cargar_usuarios()
    {:ok, usuarios}
  end

  @impl true
  def handle_call({:conectar, username, password}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        nuevo = %{rol: "cliente", password: password, puntaje: 0}
        nuevos_usuarios = Map.put(usuarios, username, nuevo)
        guardar_usuarios(nuevos_usuarios)
        {:reply, {:ok, nuevo}, nuevos_usuarios}

      usuario ->
        if usuario.password == password do
          {:reply, {:ok, usuario}, usuarios}
        else
          {:reply, {:error, "Contrasena incorrecta"}, usuarios}
        end
    end
  end

  @impl true
  def handle_call({:conectar_con_rol, username, password, rol}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        nuevo = %{rol: rol, password: password, puntaje: 0}
        nuevos_usuarios = Map.put(usuarios, username, nuevo)
        guardar_usuarios(nuevos_usuarios)
        {:reply, {:ok, nuevo}, nuevos_usuarios}

      usuario ->
        if usuario.password == password do
          {:reply, {:ok, usuario}, usuarios}
        else
          {:reply, {:error, "Contrasena incorrecta"}, usuarios}
        end
    end
  end

  @impl true
  def handle_call({:obtener, username}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil -> {:reply, {:error, "Usuario no encontrado"}, usuarios}
      user -> {:reply, {:ok, user}, usuarios}
    end
  end

  @impl true
  def handle_call(:ranking, _from, usuarios) do
    lista =
      usuarios
      |> Enum.map(fn {u, datos} -> {u, datos.puntaje, datos.rol} end)
      |> Enum.sort_by(fn {_, puntaje, _} -> puntaje end, :desc)
    {:reply, lista, usuarios}
  end

  @impl true
  def handle_cast({:sumar_puntos, username, puntos}, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        {:noreply, usuarios}

      usuario ->
        actualizado = Map.update!(usuario, :puntaje, &(&1 + puntos))
        nuevos = Map.put(usuarios, username, actualizado)
        guardar_usuarios(nuevos)
        {:noreply, nuevos}
    end
  end

  defp cargar_usuarios do
    File.mkdir_p!(Path.dirname(@data_file))
    case File.read(@data_file) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n", trim: true)
        |> Enum.reduce(%{}, fn linea, acc ->
          case String.split(linea, @sep) do
            [username, rol, password, puntaje] ->
              Map.put(acc, username, %{
                rol: rol,
                password: password,
                puntaje: String.to_integer(puntaje)
              })
            _ -> acc
          end
        end)
      {:error, _} -> %{}
    end
  end

  defp guardar_usuarios(usuarios) do
    File.mkdir_p!(Path.dirname(@data_file))
    contenido =
      usuarios
      |> Enum.map(fn {username, datos} ->
        "#{username}#{@sep}#{datos.rol}#{@sep}#{datos.password}#{@sep}#{datos.puntaje}"
      end)
      |> Enum.join("\n")
    File.write!(@data_file, contenido <> "\n")
  end
end

defmodule Inmobiliaria.PropertyManager do
  use GenServer
  alias Inmobiliaria.{Persistence, Property}

  @filename "properties.dat"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def publish(propietario, attrs), do: GenServer.call(__MODULE__, {:publish, propietario, attrs})

  def list(filtros \\ %{}), do: GenServer.call(__MODULE__, {:list, filtros})

  def obtener(id), do: GenServer.call(__MODULE__, {:get_property, id})

  def operate(id, cliente, operacion), do: GenServer.call(__MODULE__, {:operate, id, cliente, operacion})

  def update(id, nuevo_estado), do: GenServer.cast(__MODULE__, {:update, id, nuevo_estado})

  @impl true
  def init(_opts) do
    propiedades = cargar_propiedades()
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
      propietario: propietario
    }

    start_property_process(prop)
    new_state = Map.put(propiedades, id, prop)
    guardar_propiedades(new_state)
    {:reply, {:ok, prop}, new_state}
  end

  @impl true
  def handle_call({:list, filtros}, _from, propiedades) do
    resultado = propiedades |> Map.values() |> Enum.filter(&apply_filters(&1, filtros))
    {:reply, resultado, propiedades}
  end

  @impl true
  def handle_call({:get_property, id}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      prop -> {:reply, {:ok, prop}, propiedades}
    end
  end

  @impl true
  def handle_call({:operate, id, _cliente, operacion}, _from, propiedades) do
    case Map.get(propiedades, id) do
      nil ->
        {:reply, {:error, "Propiedad no encontrada"}, propiedades}
      _prop ->
        case Property.operate(id, operacion) do
          {:ok, prop_actualizada} ->
            new_state = Map.put(propiedades, id, prop_actualizada)
            guardar_propiedades(new_state)
            {:reply, {:ok, prop_actualizada}, new_state}
          {:error, razon} ->
            {:reply, {:error, razon}, propiedades}
        end
    end
  end

  @impl true
  def handle_cast({:update, id, nuevo_estado}, propiedades) do
    case Map.get(propiedades, id) do
      nil -> {:noreply, propiedades}
      prop ->
        actualizada = %{prop | estado: nuevo_estado}
        new_state = Map.put(propiedades, id, actualizada)
        guardar_propiedades(new_state)
        {:noreply, new_state}
    end
  end

  defp start_property_process(prop) do
    DynamicSupervisor.start_child(Inmobiliaria.PropertySupervisor, {Property, prop})
  end

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

  defp cargar_propiedades do
    Persistence.read_lines(@filename)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, "|") do
        [id, tipo, modalidad, ubicacion, precio, habitaciones, area, estado, propietario] ->
          prop = %{
            id: id,
            tipo: tipo,
            modalidad: modalidad,
            ubicacion: ubicacion,
            precio: String.to_integer(precio),
            habitaciones: String.to_integer(habitaciones),
            area: String.to_integer(area),
            estado: estado,
            propietario: propietario
          }
          Map.put(acc, id, prop)
        _ -> acc
      end
    end)
  end

  defp guardar_propiedades(props) do
    lines = Enum.map(props, fn {_id, prop} ->
      "#{prop.id}|#{prop.tipo}|#{prop.modalidad}|#{prop.ubicacion}|#{prop.precio}|#{prop.habitaciones}|#{prop.area}|#{prop.estado}|#{prop.propietario}"
    end)
    Persistence.write_lines(@filename, lines)
  end

  defp generar_id(propiedades) do
    n = map_size(propiedades) + 1
    "prop_#{String.pad_leading(Integer.to_string(n), 3, "0")}"
  end

  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {num, _} -> num
      :error -> 0
    end
  end
  defp parse_int(_), do: 0
end

defmodule Inmobiliaria.MessageManager do
  use GenServer
  alias Inmobiliaria.{Persistence, PropertyManager}

  @filename "messages.dat"
  @sep "|"

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def send_message(de, prop_id, texto), do: GenServer.cast(__MODULE__, {:send, de, prop_id, texto})

  def get_messages(username), do: GenServer.call(__MODULE__, {:get_messages, username})

  @impl true
  def init(_) do
    {:ok, load_messages()}
  end

  @impl true
  def handle_cast({:send, de, prop_id, texto}, mensajes) do
    propietario = obtener_propietario(prop_id)
    fecha = Date.utc_today() |> Date.to_string()

    mensaje = %{fecha: fecha, de: de, para: propietario, propiedad: prop_id, texto: texto}
    Persistence.write_line(@filename, format_message(mensaje))
    {:noreply, [mensaje | mensajes]}
  end

  @impl true
  def handle_call({:get_messages, username}, _from, mensajes) do
    filtrados = mensajes |> Enum.filter(&(&1.para == username)) |> Enum.sort_by(& &1.fecha, :desc)
    {:reply, filtrados, mensajes}
  end

  defp format_message(m), do: "#{m.fecha}#{@sep}#{m.de}#{@sep}#{m.para}#{@sep}#{m.propiedad}#{@sep}#{m.texto}"

  defp load_messages do
    Persistence.read_lines(@filename)
    |> Enum.map(&parse_message_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_message_line(line) do
    case String.split(line, @sep) do
      [fecha, de, para, propiedad | texto_parts] ->
        %{fecha: fecha, de: de, para: para, propiedad: propiedad, texto: Enum.join(texto_parts, @sep)}
      _ -> nil
    end
  end

  defp obtener_propietario(id_propiedad) do
    case PropertyManager.obtener(id_propiedad) do
      {:ok, prop} -> prop.propietario
      {:error, _} -> "desconocido"
    end
  end
end
