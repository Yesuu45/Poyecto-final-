defmodule Inmobiliaria.ClienteMenu do
  @host ~c"localhost"
  @port 4040

  @ciudades ["Armenia", "Bogota", "Cali", "Medellin", "Pereira", "Manizales", "Ibague"]

  # Conecta al servidor TCP e inicia el menú interactivo.
  def iniciar do
    IO.puts("=== Sistema de Gestion Inmobiliaria v1.0 ===")
    IO.puts("=== Universidad del Quindio              ===")

    case :gen_tcp.connect(@host, @port, [:binary, packet: :line, active: false]) do
      {:ok, socket} ->
        leer_respuesta(socket)
        bucle_menu(socket, %{username: nil, rol: nil})
      {:error, razon} ->
        IO.puts("ERROR: No se pudo conectar al servidor: #{razon}")
        IO.puts("Asegurate de que el servidor este corriendo.")
    end
  end

  # Muestra el menú principal en bucle según el estado de sesión del usuario.
  defp bucle_menu(socket, st) do
    IO.puts("\n+------------------------------------------+")
    if st.username do
      IO.puts("|  Usuario: #{st.username}  |  Rol: #{st.rol}")
    else
      IO.puts("|  Sin sesion iniciada")
    end
    IO.puts("+------------------------------------------+")
    mostrar_menu(st.rol)
    opcion = IO.gets("  Seleccione una opcion: ") |> String.trim()
    procesar_opcion(socket, opcion, st)
  end

  # Renderiza el menú para un usuario sin sesión iniciada.
  defp mostrar_menu(nil) do
    IO.puts("""
    +--- MENU PRINCIPAL ----------------------------+
    |  1. Iniciar sesion                           |
    |  2. Registrarse                              |
    |  3. Ver propiedades disponibles              |
    |  4. Ver ranking                              |
    |  5. Salir                                    |
    +----------------------------------------------+
    """)
  end

  # Renderiza el menú para un usuario con rol cliente.
  defp mostrar_menu("cliente") do
    IO.puts("""
    +--- MENU CLIENTE ------------------------------+
    |  1. Cerrar sesion                            |
    |  2. Ver propiedades disponibles              |
    |  3. Ver ranking                              |
    |  4. Ver mis mensajes                         |
    |  5. Enviar mensaje a propietario             |
    |  6. Comprar propiedad                        |
    |  7. Arrendar propiedad                       |
    |  8. Ver mi puntaje                           |
    |  9. Salir                                    |
    +----------------------------------------------+
    """)
  end

  # Renderiza el menú para un usuario con rol vendedor o arrendador.
  defp mostrar_menu(r) when r in ["vendedor", "arrendador"] do
    IO.puts("""
    +--- MENU #{String.upcase(r)} --------------------------+
    |  1. Cerrar sesion                            |
    |  2. Ver propiedades disponibles              |
    |  3. Ver ranking                              |
    |  4. Ver y responder mensajes                 |
    |  5. Publicar propiedad                       |
    |  6. Ver mi puntaje                           |
    |  7. Salir                                    |
    +----------------------------------------------+
    """)
  end

  # Despacha la opción seleccionada por el usuario al flujo de acción correspondiente.
  defp procesar_opcion(socket, op, st) do
    case {op, st.rol} do
      # --- MENU PRINCIPAL (Sin sesion) ---
      {"1", nil} -> iniciar_sesion(socket, st)
      {"2", nil} -> registrarse(socket, st)
      {"3", nil} ->
        listar_propiedades(socket)
        bucle_menu(socket, st)
      {"4", nil} ->
        mostrar_ranking(socket)
        bucle_menu(socket, st)
      {"5", nil} -> cerrar(socket)

      # --- MENU CLIENTE ---
      {"1", "cliente"} ->
        cerrar_sesion(socket)
        bucle_menu(socket, %{username: nil, rol: nil})
      {"2", "cliente"} ->
        listar_propiedades(socket)
        bucle_menu(socket, st)
      {"3", "cliente"} ->
        mostrar_ranking(socket)
        bucle_menu(socket, st)
      {"4", "cliente"} ->
        ver_mensajes_cliente(socket)
        bucle_menu(socket, st)
      {"5", "cliente"} ->
        enviar_mensaje(socket)
        bucle_menu(socket, st)
      {"6", "cliente"} ->
        comprar_propiedad(socket)
        bucle_menu(socket, st)
      {"7", "cliente"} ->
        arrendar_propiedad(socket)
        bucle_menu(socket, st)
      {"8", "cliente"} ->
        ver_puntaje(socket)
        bucle_menu(socket, st)
      {"9", "cliente"} -> cerrar(socket)

      # --- MENU VENDEDOR / ARRENDADOR ---
      {"1", r} when r in ["vendedor", "arrendador"] ->
        cerrar_sesion(socket)
        bucle_menu(socket, %{username: nil, rol: nil})
      {"2", r} when r in ["vendedor", "arrendador"] ->
        listar_propiedades(socket)
        bucle_menu(socket, st)
      {"3", r} when r in ["vendedor", "arrendador"] ->
        mostrar_ranking(socket)
        bucle_menu(socket, st)
      {"4", r} when r in ["vendedor", "arrendador"] ->
        ver_y_responder_mensajes(socket)
        bucle_menu(socket, st)
      {"5", r} when r in ["vendedor", "arrendador"] ->
        publicar_propiedad(socket)
        bucle_menu(socket, st)
      {"6", r} when r in ["vendedor", "arrendador"] ->
        ver_puntaje(socket)
        bucle_menu(socket, st)
      {"7", r} when r in ["vendedor", "arrendador"] -> cerrar(socket)

      _ ->
        IO.puts("  Opcion no valida, intente de nuevo.")
        bucle_menu(socket, st)
    end
  end

  # Solicita credenciales y conecta al usuario.
  defp iniciar_sesion(socket, st) do
    IO.puts("\n--- Iniciar Sesion ----------------------------")
    usuario  = pedir_sin_espacios("  Usuario (sin espacios): ")
    password = pedir("  Contrasena: ")
    enviar(socket, "connect #{usuario} #{password}")
    respuesta = leer_respuesta(socket)
    if String.contains?(respuesta, "[ok]") do
      rol = extraer_entre(respuesta, "(", ")")
      bucle_menu(socket, %{username: usuario, rol: rol})
    else
      IO.puts("  Verifique su usuario y contrasena e intente de nuevo.")
      bucle_menu(socket, st)
    end
  end

  # Guía al usuario para crear una cuenta nueva eligiendo su rol.
  defp registrarse(socket, st) do
    IO.puts("\n--- Registro de Usuario -----------------------")
    IO.puts("  NOTA: Si ya tienes cuenta, usa la opcion 1.")
    usuario  = pedir_sin_espacios("  Nombre de usuario (sin espacios): ")
    password = pedir("  Contrasena: ")
    IO.puts("  Roles disponibles:")
    IO.puts("    1. Cliente    (compra y arrienda)")
    IO.puts("    2. Vendedor   (publica en venta)")
    IO.puts("    3. Arrendador (publica en arriendo)")
    opcion_rol = pedir("  Seleccione rol (1/2/3): ")
    rol = case opcion_rol do
      "2" -> "vendedor"
      "3" -> "arrendador"
      _   -> "cliente"
    end
    enviar(socket, "connect #{usuario} #{password} #{rol}")
    respuesta = leer_respuesta(socket)
    if String.contains?(respuesta, "[ok]") do
      rol_obtenido = extraer_entre(respuesta, "(", ")")
      IO.puts("  Registro exitoso! Conectado como #{usuario} (#{rol_obtenido}).")
      bucle_menu(socket, %{username: usuario, rol: rol_obtenido})
    else
      IO.puts("  Ese usuario ya existe con otra contrasena.")
      IO.puts("  Si es tuyo, usa la opcion 1 para iniciar sesion.")
      bucle_menu(socket, st)
    end
  end

  # Envía el comando de desconexión al servidor.
  defp cerrar_sesion(socket) do
    enviar(socket, "disconnect")
    leer_respuesta(socket)
    IO.puts("  Sesion cerrada correctamente.")
  end

  # Cliente: solo ve sus mensajes, incluyendo respuestas del vendedor
  # Muestra los mensajes del cliente (enviados y recibidos).
  defp ver_mensajes_cliente(socket) do
    IO.puts("\n--- Mis Mensajes ------------------------------")
    IO.puts("  (Aqui veras mensajes recibidos y respuestas de propietarios)")
    enviar(socket, "my_messages")
    leer_respuesta(socket)
  end

  # Vendedor/Arrendador: ve mensajes y puede responder directamente al cliente
  # Muestra los mensajes al vendedor/arrendador y le permite responder directamente a un cliente.
  defp ver_y_responder_mensajes(socket) do
    IO.puts("\n--- Mis Mensajes ------------------------------")
    enviar(socket, "my_messages")
    respuesta_raw = leer_respuesta(socket)

    if String.contains?(respuesta_raw, "[info] No tienes mensajes") do
      IO.puts("  No hay mensajes para responder.")
    else
      responder = pedir("  Desea responder algun mensaje? (s/n): ")
      if String.downcase(responder) == "s" do
        IO.puts("  Ingrese los datos del mensaje a responder:")
        IO.puts("  (El cliente lo vera en su bandeja de mensajes)")
        destinatario = pedir_sin_espacios("  Usuario del cliente a responder: ")
        prop_id      = pedir("  ID de la propiedad (ej: prop_001): ")
        texto        = pedir("  Tu respuesta: ")
        enviar(socket, "reply_message #{destinatario} #{prop_id} #{texto}")
        leer_respuesta(socket)
      end
    end
  end

  # Presenta filtros opcionales y muestra las propiedades que coincidan.
  defp listar_propiedades(socket) do
    IO.puts("\n--- Propiedades Disponibles -------------------")
    IO.puts("  Filtros opcionales:")
    tipo      = pedir_opcion("  Tipo", ["casa", "apartamento", "local", "oficina"])
    modalidad = pedir_opcion("  Modalidad", ["venta", "arriendo"])
    ciudad    = pedir_ciudad()
    filtros =
      [
        (if tipo != "",      do: "tipo=#{tipo}"),
        (if modalidad != "", do: "modalidad=#{modalidad}"),
        (if ciudad != "",    do: "ubicacion=#{ciudad}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
    cmd = if filtros == "", do: "list_properties", else: "list_properties #{filtros}"
    enviar(socket, cmd)
    leer_respuesta(socket)
  end

  # Solicita los datos de la propiedad y la publica en el servidor.
  defp publicar_propiedad(socket) do
    IO.puts("\n--- Publicar Propiedad ------------------------")
    tipo         = pedir_opcion("  Tipo", ["casa", "apartamento", "local", "oficina"])
    modalidad    = pedir_opcion("  Modalidad", ["venta", "arriendo"])
    ciudad       = pedir_ciudad_obligatoria()
    precio       = pedir("  Precio ($): ")
    habitaciones = pedir("  Habitaciones: ")
    area         = pedir("  Area (m2): ")
    enviar(socket, "publish_property tipo=#{tipo} modalidad=#{modalidad} ubicacion=#{ciudad} precio=#{precio} habitaciones=#{habitaciones} area=#{area}")
    leer_respuesta(socket)
  end

  # Muestra propiedades disponibles y procesa la compra de una de ellas con confirmación.
  defp comprar_propiedad(socket) do
    IO.puts("\n--- Comprar Propiedad -------------------------")
    IO.puts("  Filtros opcionales:")
    tipo      = pedir_opcion("  Tipo", ["casa", "apartamento", "local", "oficina"])
    modalidad = pedir_opcion("  Modalidad", ["venta", "arriendo"])
    ciudad    = pedir_ciudad()
    filtros =
      [
        (if tipo != "",      do: "tipo=#{tipo}"),
        (if modalidad != "", do: "modalidad=#{modalidad}"),
        (if ciudad != "",    do: "ubicacion=#{ciudad}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
    cmd = if filtros == "", do: "list_properties", else: "list_properties #{filtros}"
    enviar(socket, cmd)
    respuesta = leer_respuesta(socket)
    if String.contains?(respuesta, "[info] No hay propiedades") do
      IO.puts("  No se encontraron propiedades con esos filtros.")
    else
      id = pedir("  ID de la propiedad a comprar (ej: prop_001): ")
      confirmacion = pedir("  Confirma la compra de #{id}? (s/n): ")
      if String.downcase(confirmacion) == "s" do
        enviar(socket, "buy_property #{id}")
        leer_respuesta(socket)
      else
        IO.puts("  Compra cancelada.")
      end
    end
  end

  # Muestra propiedades disponibles y procesa el arriendo con confirmación.
  defp arrendar_propiedad(socket) do
    IO.puts("\n--- Arrendar Propiedad ------------------------")
    IO.puts("  Filtros opcionales:")
    tipo      = pedir_opcion("  Tipo", ["casa", "apartamento", "local", "oficina"])
    modalidad = pedir_opcion("  Modalidad", ["venta", "arriendo"])
    ciudad    = pedir_ciudad()
    filtros =
      [
        (if tipo != "",      do: "tipo=#{tipo}"),
        (if modalidad != "", do: "modalidad=#{modalidad}"),
        (if ciudad != "",    do: "ubicacion=#{ciudad}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
    cmd = if filtros == "", do: "list_properties", else: "list_properties #{filtros}"
    enviar(socket, cmd)
    respuesta = leer_respuesta(socket)
    if String.contains?(respuesta, "[info] No hay propiedades") do
      IO.puts("  No se encontraron propiedades con esos filtros.")
    else
      id = pedir("  ID de la propiedad a arrendar (ej: prop_001): ")
      confirmacion = pedir("  Confirma el arriendo de #{id}? (s/n): ")
      if String.downcase(confirmacion) == "s" do
        enviar(socket, "rent_property #{id}")
        leer_respuesta(socket)
      else
        IO.puts("  Arriendo cancelado.")
      end
    end
  end

  # Solicita el ID de una propiedad y un texto, y envía el mensaje al propietario.
  defp enviar_mensaje(socket) do
    IO.puts("\n--- Enviar Mensaje a Propietario --------------")
    listar_propiedades(socket)
    id      = pedir("  ID de la propiedad (ej: prop_001): ")
    mensaje = pedir("  Tu mensaje: ")
    enviar(socket, "send_message #{id} #{mensaje}")
    leer_respuesta(socket)
  end

  # Solicita y muestra el ranking global al servidor.
  defp mostrar_ranking(socket) do
    IO.puts("\n--- Ranking Global ----------------------------")
    enviar(socket, "ranking")
    leer_respuesta(socket)
  end

  # Solicita y muestra el puntaje actual del usuario.
  defp ver_puntaje(socket) do
    IO.puts("\n--- Mi Puntaje --------------------------------")
    enviar(socket, "my_score")
    leer_respuesta(socket)
  end

  # Desconecta y cierra el socket TCP.
  defp cerrar(socket) do
    enviar(socket, "disconnect")
    :gen_tcp.close(socket)
    IO.puts("\n  Hasta luego!\n")
  end

  # Presenta una lista numerada de opciones al usuario y obtiene su selección.
  defp pedir_opcion(label, opciones) do
    IO.puts("#{label}:")
    IO.puts("    0. Omitir filtro")
    opciones
    |> Enum.with_index(1)
    |> Enum.each(fn {op, i} -> IO.puts("    #{i}. #{op}") end)
    sel = pedir("  Seleccione (0-#{length(opciones)}): ")
    case Integer.parse(sel) do
      {0, _} -> ""
      {n, _} when n >= 1 and n <= length(opciones) -> Enum.at(opciones, n - 1)
      _ -> ""
    end
  end

  # Muestra la lista de ciudades con opción de omitir el filtro.
  defp pedir_ciudad do
    IO.puts("  Ciudad:")
    IO.puts("    0. Omitir filtro")
    @ciudades
    |> Enum.with_index(1)
    |> Enum.each(fn {c, i} -> IO.puts("    #{i}. #{c}") end)
    sel = pedir("  Seleccione (0-#{length(@ciudades)}): ")
    case Integer.parse(sel) do
      {0, _} -> ""
      {n, _} when n >= 1 and n <= length(@ciudades) -> Enum.at(@ciudades, n - 1)
      _ -> ""
    end
  end

  # Muestra la lista de ciudades sin opción de omitir (campo requerido).
  defp pedir_ciudad_obligatoria do
    IO.puts("  Ciudad:")
    @ciudades
    |> Enum.with_index(1)
    |> Enum.each(fn {c, i} -> IO.puts("    #{i}. #{c}") end)
    sel = pedir("  Seleccione (1-#{length(@ciudades)}): ")
    case Integer.parse(sel) do
      {n, _} when n >= 1 and n <= length(@ciudades) -> Enum.at(@ciudades, n - 1)
      _ ->
        IO.puts("  Opcion invalida, seleccionando Armenia por defecto.")
        "Armenia"
    end
  end

  # Envía un comando al servidor por el socket TCP.
  defp enviar(socket, cmd) do
    :gen_tcp.send(socket, cmd <> "\n")
  end

  # Lee y acumula líneas de respuesta del servidor hasta que se agote el timeout.
  defp leer_respuesta(socket) do
    leer_respuesta(socket, "")
  end

  # Variante interna acumuladora de leer_respuesta.
  defp leer_respuesta(socket, acumulado) do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, linea} ->
        IO.write("  " <> linea)
        leer_respuesta(socket, acumulado <> linea)
      {:error, :timeout} ->
        acumulado
      {:error, _} ->
        acumulado
    end
  end

  # Lee una línea de entrada del usuario desde consola.
  defp pedir(prompt) do
    IO.gets(prompt) |> String.trim()
  end

  # Igual que pedir/1, pero rechaza entradas que contengan espacios.
  defp pedir_sin_espacios(prompt) do
    valor = pedir(prompt)
    if String.contains?(valor, " ") do
      IO.puts("  ERROR: No puede contener espacios. Intente de nuevo.")
      pedir_sin_espacios(prompt)
    else
      valor
    end
  end

  # Extrae el texto que se encuentra entre dos delimitadores dentro de un string.
  defp extraer_entre(texto, inicio, fin_str) do
    case Regex.run(
      ~r/#{Regex.escape(inicio)}([^#{Regex.escape(fin_str)}]+)#{Regex.escape(fin_str)}/,
      texto
    ) do
      [_, captura] -> captura
      _ -> "cliente"
    end
  end
end
