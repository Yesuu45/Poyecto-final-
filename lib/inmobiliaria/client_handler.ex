defmodule Inmobiliaria.ClientHandler do
  use GenServer
  alias Inmobiliaria.{UserManager, PropertyManager, MessageManager, Persistence}
  defstruct socket: nil, username: nil, rol: nil

  def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

  @impl true
  def init(socket) do
    send(self(), :bienvenida)
    {:ok, %__MODULE__{socket: socket}}
  end

  @impl true
  def handle_info(:bienvenida, state) do
    enviar(state.socket, "Bienvenido al Sistema Inmobiliaria\nEscribe help para ver comandos\n")
    send(self(), :leer)
    {:noreply, state}
  end

  @impl true
  def handle_info(:leer, state) do
    case :gen_tcp.recv(state.socket, 0) do
      {:ok, linea} ->
        nuevo_estado = dispatch(String.trim(linea), state)
        send(self(), :leer)
        {:noreply, nuevo_estado}
      {:error, _} ->
        if state.username, do: UserManager.sumar_puntos(state.username, 0)
        {:stop, :normal, state}
    end
  end

  defp dispatch("connect " <> resto, state) do
    case String.split(String.trim(resto), " ", trim: true) do
      [username, password | rol_lista] ->
        rol = List.first(rol_lista) || "cliente"
        case UserManager.conectar_con_rol(username, password, rol) do
          {:ok, user} ->
            enviar(state.socket, "[ok] Bienvenido #{username} (#{user.rol}) puntaje: #{user.puntaje}\n")
            %{state | username: username, rol: user.rol}
          {:error, razon} ->
            enviar(state.socket, "[error] #{razon}\n")
            state
        end
      _ ->
        enviar(state.socket, "[error] Uso: connect usuario contrasena rol\n")
        state
    end
  end

  defp dispatch("disconnect", state) do
    if state.username do
      enviar(state.socket, "[ok] Hasta luego #{state.username}\n")
      %{state | username: nil, rol: nil}
    else
      enviar(state.socket, "[error] No estas conectado\n")
      state
    end
  end

  defp dispatch("publish_property " <> resto, state) do
    with :ok <- require_login(state), :ok <- require_rol(state, ["vendedor", "arrendador"]) do
      attrs = parse_attrs(String.split(String.trim(resto), " ", trim: true))
      case PropertyManager.publish(state.username, attrs) do
        {:ok, prop} ->
          enviar(state.socket, "[ok] Propiedad publicada: #{prop.id} #{prop.tipo} en #{prop.ubicacion} $#{prop.precio}\n")
        {:error, r} ->
          enviar(state.socket, "[error] #{r}\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  defp dispatch("list_properties" <> resto, state) do
    filtros = parse_attrs(String.split(String.trim(resto), " ", trim: true))
    props = PropertyManager.list(filtros)
    if props == [] do
      enviar(state.socket, "[info] No hay propiedades\n")
    else
      enviar(state.socket, "=== Propiedades ===\n")
      Enum.each(props, fn p ->
        enviar(state.socket, "#{p.id} | #{p.tipo} | #{p.modalidad} | #{p.ubicacion} | $#{p.precio} | #{p.estado} | #{p.propietario}\n")
      end)
      enviar(state.socket, "===================\n")
    end
    state
  end

  defp dispatch("buy_property " <> prop_id, state) do
    with :ok <- require_login(state), :ok <- require_rol(state, ["cliente"]) do
      case PropertyManager.operate(String.trim(prop_id), state.username, "compra") do
        {:ok, prop} ->
          UserManager.sumar_puntos(state.username, 10)
          UserManager.sumar_puntos(prop.propietario, 15)
          registrar_operacion(state.username, prop, "compra")
          enviar(state.socket, "[ok] Compra exitosa! +10 pts para ti, +15 pts para #{prop.propietario}\n")
        {:error, r} ->
          enviar(state.socket, "[error] #{r}\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  defp dispatch("rent_property " <> prop_id, state) do
    with :ok <- require_login(state), :ok <- require_rol(state, ["cliente"]) do
      case PropertyManager.operate(String.trim(prop_id), state.username, "arriendo") do
        {:ok, prop} ->
          UserManager.sumar_puntos(state.username, 10)
          UserManager.sumar_puntos(prop.propietario, 15)
          registrar_operacion(state.username, prop, "arriendo")
          enviar(state.socket, "[ok] Arriendo exitoso! +10 pts para ti, +15 pts para #{prop.propietario}\n")
        {:error, r} ->
          enviar(state.socket, "[error] #{r}\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  defp dispatch("send_message " <> resto, state) do
    with :ok <- require_login(state) do
      case String.split(String.trim(resto), " ", parts: 2) do
        [prop_id, texto] ->
          case PropertyManager.obtener(prop_id) do
            {:ok, prop} ->
              MessageManager.send_message(state.username, prop_id, texto)
              enviar(state.socket, "[ok] Mensaje enviado sobre #{prop_id} (dueno: #{prop.propietario})\n")
            {:error, r} ->
              enviar(state.socket, "[error] #{r}\n")
          end
        _ ->
          enviar(state.socket, "[error] Uso: send_message prop_id mensaje\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  # NUEVO: reply_message destinatario prop_id texto
  # Permite que el vendedor/arrendador responda directamente a un cliente
  defp dispatch("reply_message " <> resto, state) do
    with :ok <- require_login(state) do
      case String.split(String.trim(resto), " ", parts: 3) do
        [destinatario, prop_id, texto] ->
          MessageManager.reply_message(state.username, destinatario, prop_id, texto)
          enviar(state.socket, "[ok] Respuesta enviada a #{destinatario} sobre #{prop_id}\n")
        _ ->
          enviar(state.socket, "[error] Uso: reply_message destinatario prop_id mensaje\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  defp dispatch("my_messages", state) do
    with :ok <- require_login(state) do
      msgs = MessageManager.get_messages(state.username)
      if msgs == [] do
        enviar(state.socket, "[info] No tienes mensajes\n")
      else
        enviar(state.socket, "=== Mensajes ===\n")
        Enum.each(msgs, fn m ->
          enviar(state.socket, "[#{m.fecha}] De: #{m.de} | Prop: #{m.propiedad} | #{m.texto}\n")
        end)
        enviar(state.socket, "================\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  defp dispatch("ranking", state) do
    ranking = UserManager.ranking()
    enviar(state.socket, "=== Ranking Global ===\n")
    ranking
    |> Enum.with_index(1)
    |> Enum.each(fn {{u, p, r}, pos} ->
      enviar(state.socket, "#{pos}. #{u} (#{r}) #{p} pts\n")
    end)
    enviar(state.socket, "=====================\n")
    state
  end

  defp dispatch("my_score", state) do
    with :ok <- require_login(state) do
      case UserManager.obtener(state.username) do
        {:ok, user} -> enviar(state.socket, "[info] Tienes #{user.puntaje} puntos\n")
        {:error, r} -> enviar(state.socket, "[error] #{r}\n")
      end
    else
      {:error, msg} -> enviar(state.socket, "[error] #{msg}\n")
    end
    state
  end

  defp dispatch("help", state) do
    enviar(state.socket, """
    === Comandos ===
    connect <user> <pass> [rol]        roles: cliente vendedor arrendador
    disconnect
    publish_property tipo=X modalidad=X ubicacion=X precio=X habitaciones=X area=X
    list_properties [tipo=X] [modalidad=X] [ubicacion=X]
    buy_property <prop_id>
    rent_property <prop_id>
    send_message <prop_id> <mensaje>
    reply_message <destinatario> <prop_id> <mensaje>
    my_messages
    ranking
    my_score
    ================
    """)
    state
  end

  defp dispatch("", state), do: state
  defp dispatch(cmd, state) do
    enviar(state.socket, "[error] Comando desconocido: #{cmd}. Escribe help\n")
    state
  end

  defp enviar(socket, mensaje), do: :gen_tcp.send(socket, mensaje)

  defp require_login(%{username: nil}),
    do: {:error, "No estas conectado. Usa: connect usuario contrasena"}
  defp require_login(_), do: :ok

  defp require_rol(%{rol: rol}, roles) do
    if rol in roles,
      do: :ok,
      else: {:error, "Tu rol es #{rol}. Se requiere: #{Enum.join(roles, " o ")}"}
  end

  defp parse_attrs(lista) do
    Enum.reduce(lista, %{}, fn item, acc ->
      case String.split(item, "=", parts: 2) do
        [k, v] -> Map.put(acc, k, v)
        _ -> acc
      end
    end)
  end

  defp registrar_operacion(cliente, prop, tipo_op) do
    fecha = Date.utc_today() |> Date.to_string()
    linea =
      "#{fecha}; cliente=#{cliente}; responsable=#{prop.propietario}; " <>
      "propiedad=#{prop.id}; operacion=#{tipo_op}; ubicacion=#{prop.ubicacion}; " <>
      "precio=#{prop.precio}; status=Completada"
    Persistence.write_line("results.log", linea)
  end
end
