defmodule InmobiliariaWeb.RankingLive do
  use Phoenix.LiveView
  alias Inmobiliaria.UserManager

  # Carga el ranking global al montar la vista.
  def mount(params, _session, socket) do
    usuario = Map.get(params, "usuario") || get_connect_params(socket)["usuario"]
    rol     = Map.get(params, "rol") || get_connect_params(socket)["rol"]
    ranking = UserManager.ranking()
    {:ok, assign(socket,
      ranking: ranking,
      usuario: if(usuario == "", do: nil, else: usuario),
      rol: if(rol == "", do: nil, else: rol)
    )}
  end

  # Renderiza la lista del ranking con estilos diferenciados para los primeros tres puestos.
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
      <div class="max-w-2xl mx-auto px-6 py-10">
        <div class="flex items-center gap-3 mb-8">
          <span class="text-3xl">🏆</span>
          <h1 class="text-2xl font-bold text-white">Ranking <span class="text-blue-400">Global</span></h1>
        </div>
        <div class="flex flex-col gap-3">
          <%= for {{usuario, puntaje, rol}, pos} <- Enum.with_index(@ranking, 1) do %>
            <div class={"bg-slate-900 border rounded-2xl p-5 flex items-center justify-between card-hover " <>
              if(pos == 1, do: "border-yellow-500/40", else: if(pos == 2, do: "border-slate-500/40", else: if(pos == 3, do: "border-orange-600/40", else: "border-slate-800")))}>
              <div class="flex items-center gap-4">
                <div class={"w-10 h-10 rounded-xl flex items-center justify-center font-bold text-sm " <>
                  if(pos == 1, do: "bg-yellow-500/20 text-yellow-400 border border-yellow-500/30",
                  else: if(pos == 2, do: "bg-slate-500/20 text-slate-300 border border-slate-500/30",
                  else: if(pos == 3, do: "bg-orange-600/20 text-orange-400 border border-orange-600/30",
                  else: "bg-slate-800 text-slate-500 border border-slate-700")))}>
                  <%= pos %>
                </div>
                <div>
                  <p class="font-semibold text-white"><%= usuario %></p>
                  <p class="text-xs text-slate-500 capitalize"><%= rol %></p>
                </div>
              </div>
              <div class="text-right">
                <div class="text-blue-400 font-bold text-lg"><%= puntaje %></div>
                <div class="text-xs text-slate-500">puntos</div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
