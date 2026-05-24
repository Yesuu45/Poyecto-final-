defmodule InmobiliariaWeb.PublicarLive do
  use Phoenix.LiveView
  alias Inmobiliaria.PropertyManager

  def mount(params, _session, socket) do
    usuario = Map.get(params, "usuario") || get_connect_params(socket)["usuario"]
    rol     = Map.get(params, "rol") || get_connect_params(socket)["rol"]
    {:ok, assign(socket,
      usuario: if(usuario == "", do: nil, else: usuario),
      rol: if(rol == "", do: nil, else: rol)
    )}
  end

  def handle_event("publicar", params, socket) do
    case socket.assigns.rol do
      r when r in ["vendedor", "arrendador"] ->
        attrs = %{"tipo" => params["tipo"], "modalidad" => params["modalidad"],
                  "ubicacion" => params["ubicacion"], "precio" => params["precio"],
                  "habitaciones" => params["habitaciones"], "area" => params["area"]}
        case PropertyManager.publish(socket.assigns.usuario, attrs) do
          {:ok, prop} -> {:noreply, put_flash(socket, :info, "✓ Propiedad #{prop.id} publicada exitosamente")}
          {:error, r} -> {:noreply, put_flash(socket, :error, r)}
        end
      _ -> {:noreply, put_flash(socket, :error, "No tienes permiso para publicar")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <nav class="border-b border-slate-800 bg-slate-900/80 backdrop-blur-md sticky top-0 z-40">
        <div class="max-w-4xl mx-auto px-6 py-4 flex justify-between items-center">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold text-sm glow-sm">IQ</div>
            <span class="text-xl font-bold text-white">Inmobiliaria <span class="text-blue-400">UQ</span></span>
          </div>
          <a href={if @usuario, do: "/?usuario=#{@usuario}&rol=#{@rol}", else: "/"}
             class="text-slate-400 hover:text-blue-400 text-sm transition-colors">← Volver</a>
        </div>
      </nav>
      <div class="max-w-xl mx-auto px-6 py-10">
        <div class="flex items-center gap-3 mb-8">
          <span class="text-blue-400 text-2xl">◆</span>
          <h1 class="text-2xl font-bold text-white">Publicar <span class="text-blue-400">Propiedad</span></h1>
        </div>

        <%= if Phoenix.Flash.get(@flash, :info) do %>
          <div class="bg-green-500/10 border border-green-500/30 text-green-400 p-4 rounded-xl mb-6 flex items-center gap-2">
            <span>◆</span> <%= Phoenix.Flash.get(@flash, :info) %>
          </div>
        <% end %>
        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="bg-red-500/10 border border-red-500/30 text-red-400 p-4 rounded-xl mb-6 flex items-center gap-2">
            <span>◆</span> <%= Phoenix.Flash.get(@flash, :error) %>
          </div>
        <% end %>

        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-8">
          <form phx-submit="publicar" class="flex flex-col gap-5">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs text-slate-400 uppercase tracking-wider">Tipo</label>
                <select name="tipo" class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-200 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors">
                  <option value="casa">Casa</option>
                  <option value="apartamento">Apartamento</option>
                  <option value="local">Local</option>
                  <option value="oficina">Oficina</option>
                </select>
              </div>
              <div>
                <label class="text-xs text-slate-400 uppercase tracking-wider">Modalidad</label>
                <select name="modalidad" class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-200 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors">
                  <option value="venta">Venta</option>
                  <option value="arriendo">Arriendo</option>
                </select>
              </div>
            </div>
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider">Ciudad</label>
              <select name="ubicacion" class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-200 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors">
                <%= for c <- ~w(Armenia Bogota Cali Medellin Pereira Manizales Ibague) do %>
                  <option value={c}><%= c %></option>
                <% end %>
              </select>
            </div>
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider">Precio ($)</label>
              <input type="number" name="precio" placeholder="0"
                     class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors" required/>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs text-slate-400 uppercase tracking-wider">Habitaciones</label>
                <input type="number" name="habitaciones" placeholder="0"
                       class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors" required/>
              </div>
              <div>
                <label class="text-xs text-slate-400 uppercase tracking-wider">Área (m²)</label>
                <input type="number" name="area" placeholder="0"
                       class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors" required/>
              </div>
            </div>
            <button type="submit" class="mt-2 bg-blue-600 hover:bg-blue-500 text-white py-3 rounded-xl font-medium transition-all btn-glow">
              Publicar propiedad
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
