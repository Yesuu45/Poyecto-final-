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
    # CORRECCIÓN: Filtramos tanto por quien envía como por quien recibe
    filtrados =
      mensajes
      |> Enum.filter(fn m -> m.para == username or m.de == username end)
      |> Enum.sort_by(& &1.fecha, :desc)

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
