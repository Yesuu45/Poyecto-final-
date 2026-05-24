defmodule InmobiliariaWeb.MensajesLive do
  use Phoenix.LiveView
  alias Inmobiliaria.MessageManager

  def mount(params, _session, socket) do
    usuario = Map.get(params, "usuario") || get_connect_params(socket)["usuario"]
    rol     = Map.get(params, "rol") || get_connect_params(socket)["rol"]
    usuario = if(usuario == "", do: nil, else: usuario)
    rol     = if(rol == "", do: nil, else: rol)
    mensajes = if usuario, do: MessageManager.get_messages(usuario), else: []
    {:ok, assign(socket, mensajes: mensajes, usuario: usuario, rol: rol)}
  end

  def handle_event("responder", params, socket) do
    MessageManager.reply_message(socket.assigns.usuario, params["destinatario"], params["prop_id"], params["texto"])
    mensajes = MessageManager.get_messages(socket.assigns.usuario)
    {:noreply, put_flash(assign(socket, mensajes: mensajes), :info, "✓ Mensaje enviado")}
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
      <div class="max-w-3xl mx-auto px-6 py-10 flex flex-col gap-6">

        <%= if Phoenix.Flash.get(@flash, :info) do %>
          <div class="bg-green-500/10 border border-green-500/30 text-green-400 p-4 rounded-xl flex items-center gap-2">
            <span>◆</span> <%= Phoenix.Flash.get(@flash, :info) %>
          </div>
        <% end %>

        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6">
          <h2 class="text-lg font-semibold text-white mb-5 flex items-center gap-2">
            <span class="text-blue-400">✉</span> Mis Mensajes
          </h2>
          <%= if @mensajes == [] do %>
            <p class="text-slate-500 text-sm text-center py-8">No tienes mensajes aún.</p>
          <% else %>
            <div class="flex flex-col gap-3">
              <%= for m <- @mensajes do %>
                <div class="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4">
                  <div class="flex justify-between items-start mb-2">
                    <div class="text-sm">
                      <span class="text-slate-400">De: </span>
                      <span class="text-blue-400 font-medium"><%= m.de %></span>
                      <span class="text-slate-500"> → </span>
                      <span class="text-slate-300"><%= m.para %></span>
                    </div>
                    <span class="text-xs text-slate-500 font-mono"><%= m.fecha %></span>
                  </div>
                  <p class="text-slate-200 text-sm"><%= m.texto %></p>
                  <p class="text-xs text-blue-500/60 font-mono mt-2"><%= m.propiedad %></p>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6">
          <h2 class="text-lg font-semibold text-white mb-5 flex items-center gap-2">
            <span class="text-blue-400">↩</span>
            <%= if @rol in ["vendedor", "arrendador"], do: "Responder a cliente", else: "Enviar mensaje" %>
          </h2>
          <form phx-submit="responder" class="flex flex-col gap-4">
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider">Destinatario</label>
              <input type="text" name="destinatario" placeholder="nombre de usuario"
                     class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors" required/>
            </div>
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider">ID Propiedad</label>
              <input type="text" name="prop_id" placeholder="prop_001"
                     class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-2.5 text-sm font-mono outline-none transition-colors" required/>
            </div>
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider">Mensaje</label>
              <textarea name="texto" placeholder="Escribe tu mensaje..."
                        class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-2.5 text-sm outline-none transition-colors h-28 resize-none" required></textarea>
            </div>
            <button type="submit" class="bg-blue-600 hover:bg-blue-500 text-white py-2.5 rounded-xl font-medium text-sm transition-all btn-glow">
              Enviar mensaje
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
