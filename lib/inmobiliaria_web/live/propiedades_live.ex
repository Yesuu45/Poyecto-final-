defmodule InmobiliariaWeb.PropiedadesLive do
  use Phoenix.LiveView
  alias Inmobiliaria.PropertyManager
  alias Inmobiliaria.MessageManager

  # Carga las propiedades y el estado del usuario al montar la vista.
  def mount(params, _session, socket) do
    usuario = Map.get(params, "usuario") || get_connect_params(socket)["usuario"]
    rol     = Map.get(params, "rol") || get_connect_params(socket)["rol"]
    props   = PropertyManager.list(%{})
    {:ok, assign(socket,
      props: props,
      usuario: if(usuario == "", do: nil, else: usuario),
      rol: if(rol == "", do: nil, else: rol),
      filtro_tipo: "", filtro_ciudad: "",
      vista: "disponibles",
      mensaje_prop_id: nil,
      editar_prop_id: nil
    )}
  end

  # Aplica filtros de tipo y ciudad sobre las propiedades.
  def handle_event("filtrar", params, socket) do
    filtros = %{} |> maybe_put("tipo", params["tipo"]) |> maybe_put("ubicacion", params["ciudad"])
    props = PropertyManager.list(filtros)
    {:noreply, assign(socket, props: props, filtro_tipo: params["tipo"], filtro_ciudad: params["ciudad"])}
  end

  # Alterna entre vistas.
  def handle_event("cambiar_vista", %{"vista" => v}, socket),
    do: {:noreply, assign(socket, vista: v)}

  # Abre el modal de mensaje.
  def handle_event("abrir_mensaje", %{"id" => id}, socket),
    do: {:noreply, assign(socket, mensaje_prop_id: id)}

  # Cierra el modal de mensaje.
  def handle_event("cerrar_mensaje", _, socket),
    do: {:noreply, assign(socket, mensaje_prop_id: nil)}

  # Abre el modal de edición.
  def handle_event("abrir_editar", %{"id" => id}, socket),
    do: {:noreply, assign(socket, editar_prop_id: id)}

  # Cierra el modal de edición.
  def handle_event("cerrar_editar", _, socket),
    do: {:noreply, assign(socket, editar_prop_id: nil)}

  # Envía un mensaje al propietario de la propiedad seleccionada.
  def handle_event("enviar_mensaje", %{"texto" => texto}, socket) do
    MessageManager.send_message(socket.assigns.usuario, socket.assigns.mensaje_prop_id, texto)
    {:noreply, socket |> assign(mensaje_prop_id: nil) |> put_flash(:info, "✓ Mensaje enviado al propietario")}
  end

  # El propietario o arrendatario activo edita modalidad, estado y/o precio de su propiedad.
  def handle_event("editar_prop", params, socket) do
    id      = params["id"]
    cambios = %{}
    cambios = if params["modalidad"] != "", do: Map.put(cambios, :modalidad, params["modalidad"]), else: cambios
    cambios = if params["estado"] != "",    do: Map.put(cambios, :estado,    params["estado"]),    else: cambios
    cambios = if params["precio"]  != "",   do: Map.put(cambios, :precio,    parse_precio(params["precio"])), else: cambios

    case PropertyManager.editar(id, socket.assigns.usuario, cambios) do
      {:ok, _prop} ->
        {:noreply,
         socket
         |> assign(props: PropertyManager.list(%{}), editar_prop_id: nil)
         |> put_flash(:info, "✓ Propiedad actualizada correctamente")}
      {:error, r} ->
        {:noreply, put_flash(socket, :error, r)}
    end
  end

  # Procesa la compra: el cliente pasa a ser propietario.
  # Suma puntos al comprador (+10) y al propietario anterior (+15).
  def handle_event("comprar", %{"id" => id}, socket) do
    case socket.assigns.rol do
      "cliente" ->
        # Obtenemos el propietario ANTES de operar para sumarle los puntos correctamente
        propietario_anterior =
          case PropertyManager.obtener(id) do
            {:ok, p} -> p.propietario
            _        -> nil
          end

        case PropertyManager.operate(id, socket.assigns.usuario, "compra") do
          {:ok, _prop} ->
            Inmobiliaria.UserManager.sumar_puntos(socket.assigns.usuario, 10)
            if propietario_anterior, do: Inmobiliaria.UserManager.sumar_puntos(propietario_anterior, 15)
            props = PropertyManager.list(%{})
            {:noreply, put_flash(assign(socket, props: props), :info,
              "✓ Compra exitosa — +10 pts. ¡Ahora eres el propietario y puedes gestionar esta propiedad!")}
          {:error, r} ->
            {:noreply, put_flash(socket, :error, r)}
        end
      _ ->
        {:noreply, put_flash(socket, :error, "Solo clientes pueden comprar")}
    end
  end

  # Procesa el arriendo: el propietario no cambia, pero el arrendatario queda
  # registrado en :comprador para poder gestionar el lugar arrendado.
  def handle_event("arrendar", %{"id" => id}, socket) do
    case socket.assigns.rol do
      "cliente" ->
        case PropertyManager.operate(id, socket.assigns.usuario, "arriendo") do
          {:ok, prop} ->
            Inmobiliaria.UserManager.sumar_puntos(socket.assigns.usuario, 10)
            Inmobiliaria.UserManager.sumar_puntos(prop.propietario, 15)
            props = PropertyManager.list(%{})
            {:noreply, put_flash(assign(socket, props: props), :info,
              "✓ Arriendo exitoso — +10 pts. Puedes gestionar tu arriendo en 'Mis Arrendamientos'.")}
          {:error, r} ->
            {:noreply, put_flash(socket, :error, r)}
        end
      _ ->
        {:noreply, put_flash(socket, :error, "Solo clientes pueden arrendar")}
    end
  end

  # Helpers para construir el mapa de filtros ignorando valores vacíos.
  defp maybe_put(map, _k, ""),  do: map
  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v),    do: Map.put(map, k, v)

  # Propiedades disponibles para la pestaña principal.
  defp props_disponibles(props) do
    Enum.filter(props, fn p -> p.estado == "disponible" end)
  end

  # Propiedades que el cliente tiene arrendadas (registrado como comprador/arrendatario).
  defp props_arrendadas(props, usuario) do
    Enum.filter(props, fn p ->
      Map.get(p, :comprador, "") == usuario and p.estado == "arrendada"
    end)
  end

  # Propiedades publicadas por el usuario o que compró (ahora es propietario).
  defp mis_publicaciones(props, usuario) do
    Enum.filter(props, fn p -> p.propietario == usuario end)
  end

  # Verdadero si el usuario tiene al menos una propiedad a su nombre (publicada o comprada).
  defp tiene_propiedades_gestionables?(props, usuario) do
    Enum.any?(props, fn p -> p.propietario == usuario end)
  end

  # Verdadero si el usuario tiene al menos un arriendo activo como arrendatario.
  defp tiene_arrendamientos?(props, usuario) do
    Enum.any?(props, fn p ->
      Map.get(p, :comprador, "") == usuario and p.estado == "arrendada"
    end)
  end

  defp puede_editar?(prop, usuario) do
    if prop.estado == "vendida" do
      # Si ya se vendió, el nuevo dueño es quien la compró
      prop.comprador == usuario
    else
      # Si está disponible o arrendada, solo la edita el dueño original (arrendador/vendedor)
      prop.propietario == usuario
    end
  end

  # Clase CSS del badge de estado.
  defp badge("disponible"), do: "badge-disponible"
  defp badge("vendida"),    do: "badge-vendida"
  defp badge("arrendada"),  do: "badge-arrendada"
  defp badge(_),            do: "badge-default"

  # Parsea precio de forma segura.
  defp parse_precio(v) do
    case Integer.parse("#{v}") do
      {n, _} -> n
      :error -> 0
    end
  end

  # Renderiza la vista completa de propiedades con modales, filtros y pestañas por rol.
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">

      <%!-- Modal: enviar mensaje --%>
      <%= if @mensaje_prop_id do %>
        <div class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50 backdrop-blur-sm">
          <div class="bg-slate-900 border border-blue-500/30 rounded-2xl shadow-2xl glow p-8 w-full max-w-md">
            <h3 class="text-lg font-semibold text-blue-300 mb-1">✉ Enviar mensaje</h3>
            <p class="text-sm text-slate-400 mb-4">Propiedad: <span class="text-blue-400 font-mono"><%= @mensaje_prop_id %></span></p>
            <form phx-submit="enviar_mensaje" class="flex flex-col gap-4">
              <textarea name="texto" placeholder="Escribe tu consulta al propietario..."
                        class="bg-slate-800 border border-slate-600 focus:border-blue-500 rounded-xl p-3 text-sm text-slate-100 placeholder-slate-500 h-32 w-full outline-none resize-none transition-colors" required></textarea>
              <div class="flex gap-3">
                <button type="submit"
                        class="flex-1 bg-blue-600 hover:bg-blue-500 text-white py-2 rounded-xl text-sm font-medium transition-all btn-glow">
                  Enviar
                </button>
                <button type="button" phx-click="cerrar_mensaje"
                        class="flex-1 bg-slate-700 hover:bg-slate-600 text-slate-300 py-2 rounded-xl text-sm transition-colors">
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- Modal: editar propiedad --%>
      <%= if @editar_prop_id do %>
        <% prop_editar = Enum.find(@props, fn p -> p.id == @editar_prop_id end) %>
        <%= if prop_editar do %>
          <div class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50 backdrop-blur-sm">
            <div class="bg-slate-900 border border-yellow-500/30 rounded-2xl shadow-2xl p-8 w-full max-w-md">
              <h3 class="text-lg font-semibold text-yellow-300 mb-1">✏ Editar propiedad</h3>
              <p class="text-sm text-slate-400 mb-4 font-mono"><%= prop_editar.id %> · <%= prop_editar.tipo %> · <%= prop_editar.ubicacion %></p>
              <form phx-submit="editar_prop" class="flex flex-col gap-4">
                <input type="hidden" name="id" value={prop_editar.id}/>
                <div>
                  <label class="text-xs text-slate-400 uppercase tracking-wider">Modalidad</label>
                  <select name="modalidad"
                          class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-yellow-500 text-slate-200 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors">
                    <option value="venta"    selected={prop_editar.modalidad == "venta"}>Venta</option>
                    <option value="arriendo" selected={prop_editar.modalidad == "arriendo"}>Arriendo</option>
                  </select>
                </div>
                <div>
                  <label class="text-xs text-slate-400 uppercase tracking-wider">Estado</label>
                  <select name="estado"
                          class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-yellow-500 text-slate-200 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors">
                    <option value="disponible" selected={prop_editar.estado == "disponible"}>Disponible</option>
                    <option value="reservada"  selected={prop_editar.estado == "reservada"}>Reservada</option>
                    <option value="vendida"    selected={prop_editar.estado == "vendida"}>Vendida</option>
                    <option value="arrendada"  selected={prop_editar.estado == "arrendada"}>Arrendada</option>
                  </select>
                </div>
                <div>
                  <label class="text-xs text-slate-400 uppercase tracking-wider">Precio ($)</label>
                  <input type="number" name="precio" value={prop_editar.precio}
                         class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-yellow-500 text-slate-100 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors"/>
                </div>
                <div class="flex gap-3 mt-2">
                  <button type="submit"
                          class="flex-1 bg-yellow-600 hover:bg-yellow-500 text-white py-2 rounded-xl text-sm font-medium transition-all">
                    Guardar cambios
                  </button>
                  <button type="button" phx-click="cerrar_editar"
                          class="flex-1 bg-slate-700 hover:bg-slate-600 text-slate-300 py-2 rounded-xl text-sm transition-colors">
                    Cancelar
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>
      <% end %>

      <%!-- Navbar --%>
      <nav class="border-b border-slate-800 bg-slate-900/80 backdrop-blur-md sticky top-0 z-40">
        <div class="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold text-sm glow-sm">IQ</div>
            <span class="text-xl font-bold text-white">Inmobiliaria <span class="text-blue-400">UQ</span></span>
          </div>
          <div class="flex gap-6 items-center text-sm">
            <a href="/" class="text-slate-300 hover:text-blue-400 transition-colors">Propiedades</a>
            <a href={if @usuario, do: "/ranking?usuario=#{@usuario}&rol=#{@rol}", else: "/ranking"}
               class="text-slate-300 hover:text-blue-400 transition-colors">Ranking</a>
            <%= if @usuario do %>
              <a href={"/mensajes?usuario=#{@usuario}&rol=#{@rol}"}
                 class="text-slate-300 hover:text-blue-400 transition-colors">Mensajes</a>
              <%= if @rol in ["vendedor", "arrendador"] do %>
                <a href={"/publicar?usuario=#{@usuario}&rol=#{@rol}"}
                   class="text-slate-300 hover:text-blue-400 transition-colors">Publicar</a>
              <% end %>
              <div class="flex items-center gap-3 pl-4 border-l border-slate-700">
                <div class="text-right">
                  <p class="text-white font-medium text-xs"><%= @usuario %></p>
                  <p class="text-blue-400 text-xs capitalize"><%= @rol %></p>
                </div>
                <button onclick="cerrarSesion()"
                        class="bg-red-500/20 hover:bg-red-500/40 text-red-400 border border-red-500/30 px-3 py-1.5 rounded-lg text-xs font-medium transition-all">
                  Salir
                </button>
              </div>
            <% else %>
              <a href="/login"
                 class="bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded-lg text-sm font-medium transition-all btn-glow">
                Iniciar sesión
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <div class="max-w-7xl mx-auto px-6 py-8">

        <%!-- Flash messages --%>
        <%= if Phoenix.Flash.get(@flash, :info) do %>
          <div class="bg-green-500/10 border border-green-500/30 text-green-400 p-4 rounded-xl mb-6 flex items-center gap-2">
            <span class="text-green-400">◆</span> <%= Phoenix.Flash.get(@flash, :info) %>
          </div>
        <% end %>
        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="bg-red-500/10 border border-red-500/30 text-red-400 p-4 rounded-xl mb-6 flex items-center gap-2">
            <span>◆</span> <%= Phoenix.Flash.get(@flash, :error) %>
          </div>
        <% end %>

        <%!-- Pestañas según rol y propiedades del usuario --%>
        <%= if @usuario do %>
          <div class="flex gap-2 mb-6 flex-wrap">

            <%!-- Siempre visible --%>
            <button phx-click="cambiar_vista" phx-value-vista="disponibles"
                    class={"px-5 py-2 rounded-xl text-sm font-medium transition-all " <>
                      if(@vista == "disponibles",
                        do: "bg-blue-600 text-white glow-sm",
                        else: "bg-slate-800 text-slate-400 hover:text-white border border-slate-700")}>
              Disponibles
            </button>

            <%!-- Visible si el usuario tiene propiedades a su nombre (publicadas o compradas) --%>
            <%= if tiene_propiedades_gestionables?(@props, @usuario) do %>
              <button phx-click="cambiar_vista" phx-value-vista="mis_propiedades"
                      class={"px-5 py-2 rounded-xl text-sm font-medium transition-all " <>
                        if(@vista == "mis_propiedades",
                          do: "bg-blue-600 text-white glow-sm",
                          else: "bg-slate-800 text-slate-400 hover:text-white border border-slate-700")}>
                Mis Propiedades
              </button>
            <% end %>

            <%!-- Visible si el usuario tiene arrendamientos activos como arrendatario --%>
            <%= if tiene_arrendamientos?(@props, @usuario) do %>
              <button phx-click="cambiar_vista" phx-value-vista="mis_arrendamientos"
                      class={"px-5 py-2 rounded-xl text-sm font-medium transition-all " <>
                        if(@vista == "mis_arrendamientos",
                          do: "bg-green-600 text-white",
                          else: "bg-slate-800 text-slate-400 hover:text-white border border-slate-700")}>
                Mis Arrendamientos
              </button>
            <% end %>

            <%!-- Solo para vendedor/arrendador --%>
            <%= if @rol in ["vendedor", "arrendador"] do %>
              <button phx-click="cambiar_vista" phx-value-vista="mis_publicaciones"
                      class={"px-5 py-2 rounded-xl text-sm font-medium transition-all " <>
                        if(@vista == "mis_publicaciones",
                          do: "bg-yellow-600 text-white",
                          else: "bg-slate-800 text-slate-400 hover:text-white border border-slate-700")}>
                Mis Publicaciones
              </button>
            <% end %>

          </div>
        <% end %>

        <%!-- Vista: disponibles --%>
        <%= if @vista == "disponibles" do %>
          <div class="bg-slate-900 border border-slate-800 rounded-2xl p-5 mb-6">
            <form phx-change="filtrar" class="flex gap-6 flex-wrap items-center">
              <div class="flex items-center gap-3">
                <label class="text-xs font-medium text-slate-400 uppercase tracking-wider">Tipo</label>
                <select name="tipo"
                        class="bg-slate-800 border border-slate-700 text-slate-200 rounded-lg px-3 py-2 text-sm outline-none focus:border-blue-500 transition-colors">
                  <option value="">Todos</option>
                  <option value="casa">Casa</option>
                  <option value="apartamento">Apartamento</option>
                  <option value="local">Local</option>
                  <option value="oficina">Oficina</option>
                </select>
              </div>
              <div class="flex items-center gap-3">
                <label class="text-xs font-medium text-slate-400 uppercase tracking-wider">Ciudad</label>
                <select name="ciudad"
                        class="bg-slate-800 border border-slate-700 text-slate-200 rounded-lg px-3 py-2 text-sm outline-none focus:border-blue-500 transition-colors">
                  <option value="">Todas</option>
                  <%= for c <- ~w(Armenia Bogota Cali Medellin Pereira Manizales Ibague) do %>
                    <option value={c}><%= c %></option>
                  <% end %>
                </select>
              </div>
            </form>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            <%= for p <- props_disponibles(@props) do %>
              <div class="bg-slate-900 border border-slate-800 rounded-2xl p-5 flex flex-col gap-3 card-hover">
                <div class="flex justify-between items-start">
                  <span class="font-semibold text-white capitalize text-lg"><%= p.tipo %></span>
                  <span class={"px-2.5 py-1 rounded-lg text-xs font-medium " <> badge(p.estado)}>
                    <%= p.estado %>
                  </span>
                </div>
                <div class="flex items-center gap-2 text-slate-400 text-sm">
                  <span class="text-blue-400">◎</span> <%= p.ubicacion %>
                </div>
                <div class="text-blue-400 font-bold text-2xl">$<%= p.precio %></div>
                <div class="grid grid-cols-3 gap-2 text-xs text-slate-400 bg-slate-800/50 rounded-xl p-3">
                  <div class="text-center">
                    <div class="text-slate-200 font-medium"><%= p.habitaciones %></div>
                    <div>habitac.</div>
                  </div>
                  <div class="text-center border-x border-slate-700">
                    <div class="text-slate-200 font-medium"><%= p.area %> m²</div>
                    <div>área</div>
                  </div>
                  <div class="text-center">
                    <div class="text-slate-200 font-medium capitalize"><%= p.modalidad %></div>
                    <div>modalidad</div>
                  </div>
                </div>
                <div class="flex justify-between text-xs text-slate-500">
                  <span>Por: <span class="text-slate-400"><%= p.propietario %></span></span>
                  <span class="font-mono text-blue-500/70"><%= p.id %></span>
                </div>

                <%!-- Acciones para cliente --%>
                <%= if @usuario != nil and @rol == "cliente" do %>
                  <div class="flex gap-2 mt-1">
                    <%= if p.modalidad == "venta" do %>
                      <button phx-click="comprar" phx-value-id={p.id}
                              class="flex-1 bg-blue-600/20 hover:bg-blue-600 border border-blue-500/40 hover:border-blue-500 text-blue-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                        Comprar
                      </button>
                    <% end %>
                    <%= if p.modalidad == "arriendo" do %>
                      <button phx-click="arrendar" phx-value-id={p.id}
                              class="flex-1 bg-green-600/20 hover:bg-green-600 border border-green-500/40 hover:border-green-500 text-green-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                        Arrendar
                      </button>
                    <% end %>
                    <button phx-click="abrir_mensaje" phx-value-id={p.id}
                            class="flex-1 bg-yellow-600/20 hover:bg-yellow-600 border border-yellow-500/40 hover:border-yellow-500 text-yellow-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                      Mensaje
                    </button>
                  </div>
                <% end %>

                <%!-- Botón editar: visible para cualquier usuario que sea propietario o arrendatario activo --%>
                <%= if @usuario != nil and puede_editar?(p, @usuario) do %>
                  <button phx-click="abrir_editar" phx-value-id={p.id}
                          class="w-full mt-1 bg-yellow-600/20 hover:bg-yellow-600 border border-yellow-500/40 hover:border-yellow-500 text-yellow-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                    ✏ Editar propiedad
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>

        <% else %>

          <%!-- Vista: mis propiedades (cualquier usuario que sea propietario, incluyendo clientes que compraron) --%>
          <%= if @vista == "mis_propiedades" do %>
            <h2 class="text-lg font-semibold text-slate-200 mb-1 flex items-center gap-2">
              <span class="text-blue-400">◆</span> Mis Propiedades
            </h2>
            <p class="text-xs text-slate-500 mb-4">Propiedades a tu nombre — puedes venderlas, arrendarlas o editarlas.</p>
            <% mis_props = mis_publicaciones(@props, @usuario) %>
            <%= if mis_props == [] do %>
              <div class="bg-slate-900 border border-slate-800 rounded-2xl p-12 text-center text-slate-500">
                No tienes propiedades a tu nombre aún.
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                <%= for p <- mis_props do %>
                  <div class="bg-slate-900 border border-blue-500/20 rounded-2xl p-5 flex flex-col gap-3 card-hover">
                    <div class="flex justify-between items-start">
                      <span class="font-semibold text-white capitalize text-lg"><%= p.tipo %></span>
                      <span class={"px-2.5 py-1 rounded-lg text-xs font-medium " <> badge(p.estado)}>
                        <%= p.estado %>
                      </span>
                    </div>
                    <div class="flex items-center gap-2 text-slate-400 text-sm">
                      <span class="text-blue-400">◎</span> <%= p.ubicacion %>
                    </div>
                    <div class="text-blue-400 font-bold text-2xl">$<%= p.precio %></div>
                    <div class="grid grid-cols-3 gap-2 text-xs text-slate-400 bg-slate-800/50 rounded-xl p-3">
                      <div class="text-center">
                        <div class="text-slate-200 font-medium"><%= p.habitaciones %></div>
                        <div>habitac.</div>
                      </div>
                      <div class="text-center border-x border-slate-700">
                        <div class="text-slate-200 font-medium"><%= p.area %> m²</div>
                        <div>área</div>
                      </div>
                      <div class="text-center">
                        <div class="text-slate-200 font-medium capitalize"><%= p.modalidad %></div>
                        <div>modalidad</div>
                      </div>
                    </div>
                    <div class="flex justify-between text-xs text-slate-500">
                      <span class="text-green-400/70 font-medium">✓ Tu propiedad</span>
                      <span class="font-mono text-blue-500/70"><%= p.id %></span>
                    </div>
                    <button phx-click="abrir_editar" phx-value-id={p.id}
                            class="w-full mt-1 bg-yellow-600/20 hover:bg-yellow-600 border border-yellow-500/40 hover:border-yellow-500 text-yellow-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                      ✏ Gestionar (editar / vender / arrendar)
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

          <%!-- Vista: mis arrendamientos (cliente arrendatario activo) --%>
          <% else %>
            <%= if @vista == "mis_arrendamientos" do %>
              <h2 class="text-lg font-semibold text-slate-200 mb-1 flex items-center gap-2">
                <span class="text-green-400">◆</span> Mis Arrendamientos
              </h2>
              <p class="text-xs text-slate-500 mb-4">Propiedades que tienes arrendadas — puedes editar sus atributos.</p>
              <% arrendadas = props_arrendadas(@props, @usuario) %>
              <%= if arrendadas == [] do %>
                <div class="bg-slate-900 border border-slate-800 rounded-2xl p-12 text-center text-slate-500">
                  No tienes arrendamientos activos.
                </div>
              <% else %>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                  <%= for p <- arrendadas do %>
                    <div class="bg-slate-900 border border-green-500/20 rounded-2xl p-5 flex flex-col gap-3 card-hover">
                      <div class="flex justify-between items-start">
                        <span class="font-semibold text-white capitalize text-lg"><%= p.tipo %></span>
                        <span class={"px-2.5 py-1 rounded-lg text-xs font-medium " <> badge(p.estado)}>
                          <%= p.estado %>
                        </span>
                      </div>
                      <div class="flex items-center gap-2 text-slate-400 text-sm">
                        <span class="text-green-400">◎</span> <%= p.ubicacion %>
                      </div>
                      <div class="text-blue-400 font-bold text-2xl">$<%= p.precio %></div>
                      <div class="grid grid-cols-3 gap-2 text-xs text-slate-400 bg-slate-800/50 rounded-xl p-3">
                        <div class="text-center">
                          <div class="text-slate-200 font-medium"><%= p.habitaciones %></div>
                          <div>habitac.</div>
                        </div>
                        <div class="text-center border-x border-slate-700">
                          <div class="text-slate-200 font-medium"><%= p.area %> m²</div>
                          <div>área</div>
                        </div>
                        <div class="text-center">
                          <div class="text-slate-200 font-medium capitalize"><%= p.modalidad %></div>
                          <div>modalidad</div>
                        </div>
                      </div>
                      <div class="flex justify-between text-xs text-slate-500">
                        <span class="text-green-400/70 font-medium">✓ Arrendado</span>
                        <span class="font-mono text-blue-500/70"><%= p.id %></span>
                      </div>
                      <%!-- El arrendatario puede editar atributos del lugar que arrienda --%>
                      <button phx-click="abrir_editar" phx-value-id={p.id}
                              class="w-full mt-1 bg-green-600/20 hover:bg-green-600 border border-green-500/40 hover:border-green-500 text-green-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                        ✏ Editar mi arriendo
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>

            <%!-- Vista: mis publicaciones (vendedor/arrendador) --%>
            <% else %>
              <h2 class="text-lg font-semibold text-slate-200 mb-4 flex items-center gap-2">
                <span class="text-yellow-400">◆</span> Mis publicaciones
              </h2>
              <% publicadas = mis_publicaciones(@props, @usuario) %>
              <%= if publicadas == [] do %>
                <div class="bg-slate-900 border border-slate-800 rounded-2xl p-12 text-center text-slate-500">
                  No has publicado ninguna propiedad aún.
                  <a href={"/publicar?usuario=#{@usuario}&rol=#{@rol}"}
                     class="block mt-3 text-blue-400 hover:text-blue-300 text-sm">
                    → Publicar ahora
                  </a>
                </div>
              <% else %>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                  <%= for p <- publicadas do %>
                    <div class="bg-slate-900 border border-yellow-500/20 rounded-2xl p-5 flex flex-col gap-3 card-hover">
                      <div class="flex justify-between items-start">
                        <span class="font-semibold text-white capitalize text-lg"><%= p.tipo %></span>
                        <span class={"px-2.5 py-1 rounded-lg text-xs font-medium " <> badge(p.estado)}>
                          <%= p.estado %>
                        </span>
                      </div>
                      <div class="flex items-center gap-2 text-slate-400 text-sm">
                        <span class="text-yellow-400">◎</span> <%= p.ubicacion %>
                      </div>
                      <div class="text-blue-400 font-bold text-2xl">$<%= p.precio %></div>
                      <div class="grid grid-cols-3 gap-2 text-xs text-slate-400 bg-slate-800/50 rounded-xl p-3">
                        <div class="text-center">
                          <div class="text-slate-200 font-medium"><%= p.habitaciones %></div>
                          <div>habitac.</div>
                        </div>
                        <div class="text-center border-x border-slate-700">
                          <div class="text-slate-200 font-medium"><%= p.area %> m²</div>
                          <div>área</div>
                        </div>
                        <div class="text-center">
                          <div class="text-slate-200 font-medium capitalize"><%= p.modalidad %></div>
                          <div>modalidad</div>
                        </div>
                      </div>
                      <div class="flex justify-between text-xs text-slate-500">
                        <span>Propietario: <span class="text-slate-400"><%= p.propietario %></span></span>
                        <span class="font-mono text-blue-500/70"><%= p.id %></span>
                      </div>
                      <button phx-click="abrir_editar" phx-value-id={p.id}
                              class="w-full mt-1 bg-yellow-600/20 hover:bg-yellow-600 border border-yellow-500/40 hover:border-yellow-500 text-yellow-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                        ✏ Editar propiedad
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          <% end %>
        <% end %>

      </div>
    </div>
    """
  end
end
