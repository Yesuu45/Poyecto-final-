defmodule Inmobiliaria.MessageManager do
  use GenServer
  alias Inmobiliaria.{Persistence, PropertyManager}

  @filename "messages.dat"
  @sep "|"

  # Inicia el GenServer de mensajes.
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # Envía un mensaje de un usuario a la propiedad indicada; resuelve automáticamente al propietario como destinatario.
  def send_message(de, prop_id, texto), do: GenServer.cast(__MODULE__, {:send, de, prop_id, texto})

  # Obtiene todos los mensajes donde el usuario sea remitente o destinatario.
  def get_messages(username), do: GenServer.call(__MODULE__, {:get_messages, username})

  # NUEVO: respuesta directa de vendedor/arrendador a un cliente
  # Envía una respuesta directa de un vendedor/arrendador a un cliente específico.
  def reply_message(de, para, prop_id, texto) do
    GenServer.cast(__MODULE__, {:reply, de, para, prop_id, texto})
  end

  # Carga los mensajes desde el archivo messages.dat al iniciar.
  @impl true
  def init(_) do
    {:ok, load_messages()}
  end

  # Maneja internamente el envío de un mensaje, lo persiste y lo agrega al estado.
  @impl true
  def handle_cast({:send, de, prop_id, texto}, mensajes) do
    propietario = obtener_propietario(prop_id)
    fecha = Date.utc_today() |> Date.to_string()
    mensaje = %{fecha: fecha, de: de, para: propietario, propiedad: prop_id, texto: texto}
    Persistence.write_line(@filename, format_message(mensaje))
    {:noreply, [mensaje | mensajes]}
  end

  # NUEVO: maneja la respuesta directa al cliente
  # Maneja internamente el envío de una respuesta directa entre usuarios.
  @impl true
  def handle_cast({:reply, de, para, prop_id, texto}, mensajes) do
    fecha = Date.utc_today() |> Date.to_string()
    mensaje = %{fecha: fecha, de: de, para: para, propiedad: prop_id, texto: texto}
    Persistence.write_line(@filename, format_message(mensaje))
    {:noreply, [mensaje | mensajes]}
  end

  # Maneja la consulta de mensajes filtrando por usuario.
  @impl true
  def handle_call({:get_messages, username}, _from, mensajes) do
    filtrados =
      mensajes
      |> Enum.filter(fn m -> m.para == username or m.de == username end)
      |> Enum.sort_by(& &1.fecha, :desc)
    {:reply, filtrados, mensajes}
  end

  # Convierte un mensaje a formato de texto para ser almacenado en el archivo.
  defp format_message(m) do
    "#{m.fecha}#{@sep}#{m.de}#{@sep}#{m.para}#{@sep}#{m.propiedad}#{@sep}#{m.texto}"
  end

  # Lee y parsea el archivo messages.dat para cargar los mensajes al estado.
  defp load_messages do
    Persistence.read_lines(@filename)
    |> Enum.map(&parse_message_line/1)
    |> Enum.reject(&is_nil/1)
  end

  # Parsea una línea del archivo y la convierte en un mapa de mensaje.
  defp parse_message_line(line) do
    case String.split(line, @sep) do
      [fecha, de, para, propiedad | texto_parts] ->
        %{fecha: fecha, de: de, para: para, propiedad: propiedad, texto: Enum.join(texto_parts, @sep)}
      _ -> nil
    end
  end

  # Consulta al PropertyManager para obtener el propietario de una propiedad.
  defp obtener_propietario(id_propiedad) do
    case PropertyManager.obtener(id_propiedad) do
      {:ok, prop} -> prop.propietario
      {:error, _} -> "desconocido"
    end
  end
end
