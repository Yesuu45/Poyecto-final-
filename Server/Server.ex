defmodule Inmobiliaria.Server do
  use GenServer

  alias Inmobiliaria.{UserManager, PropertyManager, MessageManager, Persistence}

  # ─── API pública ────────────────────────────────────────────────────────────

  # Inicia el GenServer del servidor en modo consola.
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # ─── Init ───────────────────────────────────────────────────────────────────

  # Muestra el banner de bienvenida y lanza un proceso separado para leer comandos de la entrada estándar.
  @impl true
  def init(_) do
    IO.puts("""
    ╔══════════════════════════════════════════════╗
    ║     Sistema de Gestión Inmobiliaria v1.0     ║
    ║           Universidad del Quindío            ║
    ╚══════════════════════════════════════════════╝
    Escribe 'help' para ver los comandos disponibles.
    """)

    # Arrancar el loop de lectura en un proceso separado
    # para no bloquear el GenServer
    server_pid = self()
    spawn_link(fn -> input_loop(server_pid) end)

    {:ok, %{sesiones: %{}}}
  end

  # ─── Manejo de mensajes del loop ────────────────────────────────────────────

  # Recibe una línea de texto desde el loop de lectura y la despacha.
  @impl true
  def handle_info({:comando, linea}, state) do
    parts = String.split(String.trim(linea), " ", trim: true)
    new_state = dispatch(parts, state)
    {:noreply, new_state}
  end

  # ─── Dispatcher de comandos ─────────────────────────────────────────────────

  # connect username password [rol]
  # Procesa el comando de conexión/registro de usuario.
  defp dispatch(["connect", username, password | resto], state) do
    rol = List.first(resto) || "cliente"

    case UserManager.connect(username, password, rol) do
      {:ok, user} ->
        IO.puts("[✓] Bienvenido #{username} (#{user.rol}) — puntaje: #{user.puntaje}")
        sesiones = Map.put(state.sesiones, username, user.rol)
        %{state | sesiones: sesiones}

      {:error, razon} ->
        IO.puts("[✗] #{razon}")
        state
    end
  end

  # disconnect username
  # Desconecta a un usuario de la sesión activa.
  defp dispatch(["disconnect", username], state) do
    UserManager.disconnect(username)
    IO.puts("[✓] #{username} desconectado.")
    sesiones = Map.delete(state.sesiones, username)
    %{state | sesiones: sesiones}
  end

  # publish_property username tipo=X modalidad=X ubicacion=X precio=X habitaciones=X area=X
  # Publica una nueva propiedad validando el rol del usuario.
  defp dispatch(["publish_property", username | attrs_raw], state) do
    case verificar_rol(state, username, ["vendedor", "arrendador"]) do
      :ok ->
        attrs = parse_attrs(attrs_raw)
        case PropertyManager.publish(username, attrs) do
          {:ok, prop} ->
            IO.puts("[✓] Propiedad publicada: #{prop.id} — #{prop.tipo} en #{prop.ubicacion} ($#{prop.precio})")
          {:error, razon} ->
            IO.puts("[✗] #{razon}")
        end

      {:error, msg} ->
        IO.puts("[✗] #{msg}")
    end
    state
  end

  # list_properties [filtros opcionales]
  # Ejemplos:
  #   list_properties
  #   list_properties tipo=casa
  #   list_properties modalidad=venta ubicacion=Armenia
  # Lista propiedades con filtros opcionales.
  defp dispatch(["list_properties" | filtros_raw], state) do
    filtros = parse_attrs(filtros_raw)
    props = PropertyManager.list(filtros)

    if props == [] do
      IO.puts("[i] No hay propiedades que coincidan con los filtros.")
    else
      IO.puts("\n══════════════ Propiedades disponibles ══════════════")
      Enum.each(props, &print_property/1)
      IO.puts("═════════════════════════════════════════════════════\n")
    end
    state
  end

  # buy_property username prop_id
  # Procesa la compra de una propiedad y asigna puntos.
  defp dispatch(["buy_property", username, prop_id], state) do
    case verificar_rol(state, username, ["cliente"]) do
      :ok ->
        case PropertyManager.operate(prop_id, username, "compra") do
          {:ok, prop} ->
            UserManager.add_points(username, 10)
            UserManager.add_points(prop.propietario, 15)
            registrar_operacion(username, prop, "compra")
            IO.puts("[✓] ¡Compra exitosa! #{username} compró #{prop_id}.")
            IO.puts("    +10 pts para #{username} | +15 pts para #{prop.propietario}")

          {:error, razon} ->
            IO.puts("[✗] #{razon}")
        end

      {:error, msg} ->
        IO.puts("[✗] #{msg}")
    end
    state
  end

  # rent_property username prop_id
  # Procesa el arriendo de una propiedad y asigna puntos.
  defp dispatch(["rent_property", username, prop_id], state) do
    case verificar_rol(state, username, ["cliente"]) do
      :ok ->
        case PropertyManager.operate(prop_id, username, "arriendo") do
          {:ok, prop} ->
            UserManager.add_points(username, 10)
            UserManager.add_points(prop.propietario, 15)
            registrar_operacion(username, prop, "arriendo")
            IO.puts("[✓] ¡Arriendo exitoso! #{username} arrendó #{prop_id}.")
            IO.puts("    +10 pts para #{username} | +15 pts para #{prop.propietario}")

          {:error, razon} ->
            IO.puts("[✗] #{razon}")
        end

      {:error, msg} ->
        IO.puts("[✗] #{msg}")
    end
    state
  end

  # send_message username prop_id mensaje...
  # Envía un mensaje sobre una propiedad al propietario.
  defp dispatch(["send_message", username, prop_id | palabras], state) do
    texto = Enum.join(palabras, " ")

    case PropertyManager.get_property(prop_id) do
      {:ok, prop} ->
        MessageManager.send_message(username, prop_id, prop.propietario, texto)
        IO.puts("[✓] Mensaje enviado a #{prop.propietario} sobre #{prop_id}.")

      {:error, razon} ->
        IO.puts("[✗] #{razon}")
    end
    state
  end

  # my_messages username
  # Muestra los mensajes del usuario especificado.
  defp dispatch(["my_messages", username], state) do
    msgs = MessageManager.get_messages(username)

    if msgs == [] do
      IO.puts("[i] No tienes mensajes.")
    else
      IO.puts("\n══════════════ Mensajes de #{username} ══════════════")
      Enum.each(msgs, fn m ->
        IO.puts("  [#{m.fecha}] #{m.de} → #{m.para} (#{m.prop_id}): #{m.texto}")
      end)
      IO.puts("═══════════════════════════════════════════════════\n")
    end
    state
  end

  # ranking
  # Muestra el ranking global de puntajes.
  defp dispatch(["ranking"], state) do
    ranking = UserManager.ranking()
    IO.puts("\n══════════════ Ranking Global ══════════════")
    ranking
    |> Enum.with_index(1)
    |> Enum.each(fn {{username, puntaje, rol}, pos} ->
      IO.puts("  #{pos}. #{username} (#{rol}) — #{puntaje} pts")
    end)
    IO.puts("════════════════════════════════════════════\n")
    state
  end

  # my_score username
  # Muestra el puntaje del usuario especificado.
  defp dispatch(["my_score", username], state) do
    case UserManager.get_user(username) do
      {:ok, user} -> IO.puts("[i] #{username} tiene #{user.puntaje} puntos.")
      {:error, r} -> IO.puts("[✗] #{r}")
    end
    state
  end

  # help
  # Muestra todos los comandos disponibles.
  defp dispatch(["help"], state) do
    IO.puts("""

    ╔══════════════════════════════════════════════════════════════════╗
    ║                     COMANDOS DISPONIBLES                        ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ CONEXIÓN                                                        ║
    ║   connect <user> <pass> [rol]     Conectar o registrar          ║
    ║   disconnect <user>               Desconectar                   ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ PROPIEDADES                                                     ║
    ║   publish_property <user> tipo=X modalidad=X ubicacion=X        ║
    ║                    precio=X habitaciones=X area=X               ║
    ║   list_properties [tipo=X] [modalidad=X] [ubicacion=X]          ║
    ║                   [precio_min=X] [precio_max=X] [estado=X]      ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ OPERACIONES                                                     ║
    ║   buy_property <user> <prop_id>   Comprar propiedad             ║
    ║   rent_property <user> <prop_id>  Arrendar propiedad            ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ MENSAJES                                                        ║
    ║   send_message <user> <prop_id> <mensaje>                       ║
    ║   my_messages <user>              Ver mis mensajes              ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ RANKING                                                         ║
    ║   ranking                         Ver ranking global            ║
    ║   my_score <user>                 Ver mi puntaje                ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    state
  end

  defp dispatch([], state), do: state

  defp dispatch([cmd | _], state) do
    IO.puts("[✗] Comando desconocido: '#{cmd}'. Escribe 'help' para ver los comandos.")
    state
  end

  # ─── Loop de lectura de stdin ────────────────────────────────────────────────

  # Lee líneas de la entrada estándar en un proceso separado y las envía al GenServer.
  defp input_loop(server_pid) do
    case IO.gets("") do
      :eof ->
        IO.puts("EOF alcanzado, cerrando...")

      {:error, reason} ->
        IO.puts("Error leyendo input: #{reason}")

      linea ->
        send(server_pid, {:comando, linea})
        input_loop(server_pid)
    end
  end

  # ─── Helpers ─────────────────────────────────────────────────────────────────

  # Parsea lista ["tipo=casa", "precio=300000"] → %{"tipo" => "casa", "precio" => "300000"}
  # Convierte argumentos en formato clave=valor a un mapa.
  defp parse_attrs(lista) do
    Enum.reduce(lista, %{}, fn item, acc ->
      case String.split(item, "=", parts: 2) do
        [k, v] -> Map.put(acc, k, v)
        _       -> acc
      end
    end)
  end

  # Comprueba que un usuario esté conectado y tenga el rol requerido.
  defp verificar_rol(state, username, roles_permitidos) do
    case Map.get(state.sesiones, username) do
      nil ->
        {:error, "#{username} no está conectado. Usa: connect #{username} <password>"}

      rol ->
        if rol in roles_permitidos do
          :ok
        else
          {:error, "#{username} tiene rol '#{rol}'. Esta acción requiere: #{Enum.join(roles_permitidos, " o ")}"}
        end
    end
  end

  # Imprime en consola los datos de una propiedad con formato.
  defp print_property(p) do
    IO.puts("""
      ID: #{p.id} | #{String.upcase(p.tipo)} en #{String.upcase(p.modalidad)}
      Ubicación: #{p.ubicacion} | Precio: $#{p.precio}
      Habitaciones: #{p.habitaciones} | Área: #{p.area} m²
      Estado: #{p.estado} | Publicado por: #{p.propietario}
    """)
  end

  # Escribe en results.log el registro de una operación completada.
  defp registrar_operacion(cliente, prop, tipo_op) do
    fecha = Date.utc_today() |> Date.to_string()
    estado_final = if tipo_op == "compra", do: "vendida", else: "arrendada"

    linea =
      "#{fecha}; cliente=#{cliente}; responsable=#{prop.propietario}; " <>
      "propiedad=#{prop.id}; operacion=#{tipo_op}; ubicacion=#{prop.ubicacion}; " <>
      "precio=#{prop.precio}; status=Completada; estado_final=#{estado_final}"

    Persistence.append_line("results.log", linea)
  end
end
