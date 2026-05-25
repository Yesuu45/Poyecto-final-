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
      mensaje_prop_id: nil
    )}
  end

  # Aplica filtros de tipo y ciudad sobre las propiedades.
  def handle_event("filtrar", params, socket) do
    filtros = %{} |> maybe_put("tipo", params["tipo"]) |> maybe_put("ubicacion", params["ciudad"])
    props = PropertyManager.list(filtros)
    {:noreply, assign(socket, props: props, filtro_tipo: params["tipo"], filtro_ciudad: params["ciudad"])}
  end

  # Alterna entre la vista de propiedades disponibles y las adquiridas.
  def handle_event("cambiar_vista", %{"vista" => v}, socket), do: {:noreply, assign(socket, vista: v)}
  # Abre el modal de envío de mensaje para una propiedad.
  def handle_event("abrir_mensaje", %{"id" => id}, socket), do: {:noreply, assign(socket, mensaje_prop_id: id)}
  # Cierra el modal de mensaje.
  def handle_event("cerrar_mensaje", _, socket), do: {:noreply, assign(socket, mensaje_prop_id: nil)}

  # Envía un mensaje al propietario de la propiedad seleccionada.
  def handle_event("enviar_mensaje", %{"texto" => texto}, socket) do
    MessageManager.send_message(socket.assigns.usuario, socket.assigns.mensaje_prop_id, texto)
    {:noreply, socket |> assign(mensaje_prop_id: nil) |> put_flash(:info, "✓ Mensaje enviado al propietario")}
  end

  # Procesa la compra de una propiedad y suma puntos al cliente y al propietario.
  def handle_event("comprar", %{"id" => id}, socket) do
    case socket.assigns.rol do
      "cliente" ->
        case PropertyManager.operate(id, socket.assigns.usuario, "compra") do
          {:ok, prop} ->
            Inmobiliaria.UserManager.sumar_puntos(socket.assigns.usuario, 10)
            Inmobiliaria.UserManager.sumar_puntos(prop.propietario, 15)
            {:noreply, put_flash(assign(socket, props: PropertyManager.list(%{})), :info, "✓ Compra exitosa — +10 pts")}
          {:error, r} -> {:noreply, put_flash(socket, :error, r)}
        end
      _ -> {:noreply, put_flash(socket, :error, "Solo clientes pueden comprar")}
    end
  end

  # Procesa el arriendo de una propiedad y suma puntos.
  def handle_event("arrendar", %{"id" => id}, socket) do
    case socket.assigns.rol do
      "cliente" ->
        case PropertyManager.operate(id, socket.assigns.usuario, "arriendo") do
          {:ok, prop} ->
            Inmobiliaria.UserManager.sumar_puntos(socket.assigns.usuario, 10)
            Inmobiliaria.UserManager.sumar_puntos(prop.propietario, 15)
            {:noreply, put_flash(assign(socket, props: PropertyManager.list(%{})), :info, "✓ Arriendo exitoso — +10 pts")}
          {:error, r} -> {:noreply, put_flash(socket, :error, r)}
        end
      _ -> {:noreply, put_flash(socket, :error, "Solo clientes pueden arrendar")}
    end
  end

  # Helpers para construir el mapa de filtros ignorando valores vacíos.
  defp maybe_put(map, _k, ""), do: map
  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  # Filtra las disponibles para la pestaña principal
  defp props_disponibles(props) do
    Enum.filter(props, fn p -> p.estado == "disponible" end)
  end

  # Evalúa que seas el dueño actual (comprador/arrendatario)
  defp props_adquiridas(props, usuario) do
    Enum.filter(props, fn p -> p.propietario == usuario and p.estado in ["vendida", "arrendada"] end)
  end

  # UNIFICADO: Devuelve la clase CSS correspondiente al estado de una propiedad.
  defp badge("disponible"), do: "badge-disponible"
  defp badge("vendida"),    do: "badge-vendida"
  defp badge("arrendada"),  do: "badge-arrendada"
  defp badge(_),            do: "badge-default"

  # Renderiza la vista principal de propiedades con filtros, tarjetas y acciones.
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">

      <%= if @mensaje_prop_id do %>
        <div class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50 backdrop-blur-sm">
          <div class="bg-slate-900 border border-blue-500/30 rounded-2xl shadow-2xl glow p-8 w-full max-w-md">
            <h3 class="text-lg font-semibold text-blue-300 mb-1">✉ Enviar mensaje</h3>
            <p class="text-sm text-slate-400 mb-4">Propiedad: <span class="text-blue-400 font-mono"><%= @mensaje_prop_id %></span></p>
            <form phx-submit="enviar_mensaje" class="flex flex-col gap-4">
              <textarea name="texto" placeholder="Escribe tu consulta al propietario..."
                        class="bg-slate-800 border border-slate-600 focus:border-blue-500 rounded-xl p-3 text-sm text-slate-100 placeholder-slate-500 h-32 w-full outline-none resize-none transition-colors" required></textarea>
              <div class="flex gap-3">
                <button type="submit" class="flex-1 bg-blue-600 hover:bg-blue-500 text-white py-2 rounded-xl text-sm font-medium transition-all btn-glow">
                  Enviar
                </button>
                <button type="button" phx-click="cerrar_mensaje" class="flex-1 bg-slate-700 hover:bg-slate-600 text-slate-300 py-2 rounded-xl text-sm transition-colors">
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

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
              <a href="/login" class="bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded-lg text-sm font-medium transition-all btn-glow">
                Iniciar sesión
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <div class="max-w-7xl mx-auto px-6 py-8">

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

        <%= if @usuario && @rol == "cliente" do %>
          <div class="flex gap-2 mb-6">
            <button phx-click="cambiar_vista" phx-value-vista="disponibles"
                    class={"px-5 py-2 rounded-xl text-sm font-medium transition-all " <>
                      if(@vista == "disponibles",
                        do: "bg-blue-600 text-white glow-sm",
                        else: "bg-slate-800 text-slate-400 hover:text-white border border-slate-700")}>
              Disponibles
            </button>
            <button phx-click="cambiar_vista" phx-value-vista="mis_propiedades"
                    class={"px-5 py-2 rounded-xl text-sm font-medium transition-all " <>
                      if(@vista == "mis_propiedades",
                        do: "bg-blue-600 text-white glow-sm",
                        else: "bg-slate-800 text-slate-400 hover:text-white border border-slate-700")}>
              Mis Propiedades
            </button>
          </div>
        <% end %>

        <%= if @vista == "disponibles" do %>
          <div class="bg-slate-900 border border-slate-800 rounded-2xl p-5 mb-6">
            <form phx-change="filtrar" class="flex gap-6 flex-wrap items-center">
              <div class="flex items-center gap-3">
                <label class="text-xs font-medium text-slate-400 uppercase tracking-wider">Tipo</label>
                <select name="tipo" class="bg-slate-800 border border-slate-700 text-slate-200 rounded-lg px-3 py-2 text-sm outline-none focus:border-blue-500 transition-colors">
                  <option value="">Todos</option>
                  <option value="casa">Casa</option>
                  <option value="apartamento">Apartamento</option>
                  <option value="local">Local</option>
                  <option value="oficina">Oficina</option>
                </select>
              </div>
              <div class="flex items-center gap-3">
                <label class="text-xs font-medium text-slate-400 uppercase tracking-wider">Ciudad</label>
                <select name="ciudad" class="bg-slate-800 border border-slate-700 text-slate-200 rounded-lg px-3 py-2 text-sm outline-none focus:border-blue-500 transition-colors">
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
              <div class="bg-slate-900 border border-slate-800 rounded-2xl p-5 flex flex-col gap-3 card-hover cursor-default">
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
                <%= if @usuario != nil and @rol == "cliente" do %>
                  <div class="flex gap-2 mt-1">
                    <%= if p.estado == "disponible" and p.modalidad == "venta" do %>
                      <button phx-click="comprar" phx-value-id={p.id}
                              class="flex-1 bg-blue-600/20 hover:bg-blue-600 border border-blue-500/40 hover:border-blue-500 text-blue-400 hover:text-white py-2 rounded-xl text-xs font-medium transition-all">
                        Comprar
                      </button>
                    <% end %>
                    <%= if p.estado == "disponible" and p.modalidad == "arriendo" do %>
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
              </div>
            <% end %>
          </div>

        <% else %>
          <h2 class="text-lg font-semibold text-slate-200 mb-4 flex items-center gap-2">
            <span class="text-blue-400">◆</span> Propiedades adquiridas
          </h2>
          <% adquiridas = props_adquiridas(@props, @usuario) %>
          <%= if adquiridas == [] do %>
            <div class="bg-slate-900 border border-slate-800 rounded-2xl p-12 text-center text-slate-500">
              Aún no has adquirido ninguna propiedad.
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              <%= for p <- adquiridas do %>
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
                    <span>Vendedor: <span class="text-slate-400"><%= p.propietario %></span></span>
                    <span class="font-mono text-blue-500/70"><%= p.id %></span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
