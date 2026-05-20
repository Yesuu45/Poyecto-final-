defmodule Inmobiliaria.ClienteMenu do
  @host ~c"127.0.0.1"
  @port 4040

  @ciudades ["Armenia", "Bogota", "Cali", "Medellin", "Pereira", "Manizales", "Ibague"]

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

defp mostrar_menu("cliente") do
    IO.puts("""
    +--- MENU CLIENTE ------------------------------+
    |  1. Cerrar sesion                            |
    |  2. Ver propiedades disponibles              |
    |  3. Ver ranking                              |
    |  4. Ver mis mensajes                         |  <-- Nueva opción
    |  5. Enviar mensaje a propietario             |  <-- Desplazada
    |  6. Comprar propiedad                        |  <-- Desplazada
    |  7. Arrendar propiedad                       |  <-- Desplazada
    |  8. Ver mi puntaje                           |  <-- Desplazada
    |  9. Salir                                    |  <-- Desplazada
    +----------------------------------------------+
    """)
  end

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
        IO.puts("\n--- Mis Mensajes Recibidos ---")
        enviar(socket, "my_messages")
        leer_respuesta(socket)
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
        ver_y_responder_mensajes(socket, st)
        bucle_menu(socket, st)
      {"5", r} when r in ["vendedor", "arrendador"] ->
        publicar_propiedad(socket)
        bucle_menu(socket, st)
      {"6", r} when r in ["vendedor", "arrendador"] ->
        ver_puntaje(socket)
        bucle_menu(socket, st)
      {"7", r} when r in ["vendedor", "arrendador"] -> cerrar(socket)

      # --- CASO POR DEFECTO ---
      _ ->
        IO.puts("  Opcion no valida, intente de nuevo.")
        bucle_menu(socket, st)
    end
  end

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
      bucle_menu(socket, st)
    end
  end

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
      if String.contains?(respuesta, "[error]") do
        IO.puts("  Ese usuario ya existe con otra contrasena.")
        IO.puts("  Si es tuyo, usa la opcion 1 para iniciar sesion.")
    end
    bucle_menu(socket, st)
  end

  defp cerrar_sesion(socket) do
    enviar(socket, "disconnect")
    leer_respuesta(socket)
    IO.puts("  Sesion cerrada correctamente.")
  end

  defp listar_propiedades(socket) do
    IO.puts("\n--- Propiedades Disponibles -------------------")
    IO.puts("  Filtros opcionales (Enter para omitir):")

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

  defp comprar_propiedad(socket) do
    IO.puts("\n--- Comprar Propiedad -------------------------")
    listar_propiedades(socket)
    id = pedir("  ID de la propiedad a comprar (ej: prop_001): ")
    confirmacion = pedir("  Confirma la compra de #{id}? (s/n): ")
    if String.downcase(confirmacion) == "s" do
      enviar(socket, "buy_property #{id}")
      leer_respuesta(socket)
    else
      IO.puts("  Compra cancelada.")
    end
  end

  defp arrendar_propiedad(socket) do
    IO.puts("\n--- Arrendar Propiedad ------------------------")
    listar_propiedades(socket)
    id = pedir("  ID de la propiedad a arrendar (ej: prop_001): ")
    confirmacion = pedir("  Confirma el arriendo de #{id}? (s/n): ")
    if String.downcase(confirmacion) == "s" do
      enviar(socket, "rent_property #{id}")
      leer_respuesta(socket)
    else
      IO.puts("  Arriendo cancelado.")
    end
  end

  defp enviar_mensaje(socket) do
    IO.puts("\n--- Enviar Mensaje a Propietario --------------")
    listar_propiedades(socket)
    id      = pedir("  ID de la propiedad (ej: prop_001): ")
    mensaje = pedir("  Tu mensaje: ")
    enviar(socket, "send_message #{id} #{mensaje}")
    leer_respuesta(socket)
  end

  defp ver_y_responder_mensajes(socket, st) do
    IO.puts("\n--- Mis Mensajes ------------------------------")
    enviar(socket, "my_messages")
    leer_respuesta(socket)

    IO.puts("  Desea responder algun mensaje? (s/n)")
    responder = pedir("  > ")

    if String.downcase(responder) == "s" do
      IO.puts("\n  Para responder necesitas el ID de la propiedad del mensaje.")
      IO.puts("  El destinatario recibira tu respuesta en sus mensajes.")
      prop_id  = pedir("  ID de la propiedad sobre la que responde: ")
      respuesta = pedir("  Tu respuesta: ")
      enviar(socket, "send_message #{prop_id} #{st.username} (respuesta): #{respuesta}")
      leer_respuesta(socket)
    end
  end

  defp mostrar_ranking(socket) do
    IO.puts("\n--- Ranking Global ----------------------------")
    enviar(socket, "ranking")
    leer_respuesta(socket)
  end

  defp ver_puntaje(socket) do
    IO.puts("\n--- Mi Puntaje --------------------------------")
    enviar(socket, "my_score")
    leer_respuesta(socket)
  end

  defp cerrar(socket) do
    enviar(socket, "disconnect")
    :gen_tcp.close(socket)
    IO.puts("\n  Hasta luego!\n")
  end

  # ─── Helpers de seleccion ────────────────────────────────────────────────────

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

  defp pedir_ciudad_obligatoria do
    IO.puts("  Ciudad:")
    @ciudades
    |> Enum.with_index(1)
    |> Enum.each(fn {c, i} -> IO.puts("    #{i}. #{c}") end)

    sel = pedir("  Seleccione (1-#{length(@ciudades)}): ")
    case Integer.parse(sel) do
      {n, _} when n >= 1 and n <= length(@ciudades) -> Enum.at(@ciudades, n - 1)
      _ ->
        IO.puts("  Opcion invalida, seleccione Armenia por defecto.")
        "Armenia"
    end
  end

  # ─── Helpers TCP ─────────────────────────────────────────────────────────────

  defp enviar(socket, cmd) do
    :gen_tcp.send(socket, cmd <> "\n")
  end

  defp leer_respuesta(socket) do
    leer_respuesta(socket, "")
  end

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

  defp pedir(prompt) do
    IO.gets(prompt) |> String.trim()
  end

  defp extraer_entre(texto, inicio, fin_str) do
    case Regex.run(~r/#{Regex.escape(inicio)}([^#{Regex.escape(fin_str)}]+)#{Regex.escape(fin_str)}/, texto) do
      [_, captura] -> captura
      _ -> "cliente"
    end
  end

  defp pedir_sin_espacios(prompt) do
    valor = pedir(prompt)
    if String.contains?(valor, " ") do
      IO.puts("  ERROR: El usuario no puede tener espacios. Intente de nuevo.")
      pedir_sin_espacios(prompt)
    else
      valor
    end
  end
end
