defmodule InmobiliariaWeb.LoginLive do
  use Phoenix.LiveView
  alias Inmobiliaria.UserManager

  # Inicializa la vista de login sin errores.
  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil)}
  end

  # Autentica al usuario y redirige al inicio si tiene éxito.
  def handle_event("login", %{"usuario" => u, "password" => p, "rol" => r}, socket) do
    case UserManager.conectar_con_rol(u, p, r) do
      {:ok, user} ->
        {:noreply, push_navigate(socket, to: "/?usuario=#{user.username}&rol=#{user.rol}")}
      {:error, razon} ->
        {:noreply, assign(socket, error: razon)}
    end
  end

  # Renderiza el formulario de inicio de sesión/registro.
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center px-4">
      <div class="w-full max-w-md">
        <div class="text-center mb-8">
          <div class="w-16 h-16 bg-blue-600 rounded-2xl flex items-center justify-center text-white font-bold text-2xl mx-auto mb-4 glow">IQ</div>
          <h1 class="text-3xl font-bold text-white">Inmobiliaria <span class="text-blue-400">UQ</span></h1>
          <p class="text-slate-400 mt-2 text-sm">Accede a tu cuenta o regístrate</p>
        </div>
        <div class="bg-slate-900 border border-slate-800 rounded-2xl p-8 glow-sm">
          <%= if @error do %>
            <div class="bg-red-500/10 border border-red-500/30 text-red-400 p-3 rounded-xl mb-5 text-sm">
              ◆ <%= @error %>
            </div>
          <% end %>
          <form phx-submit="login" class="flex flex-col gap-4">
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider font-medium">Usuario</label>
              <input type="text" name="usuario" placeholder="tu_usuario"
                     class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-3 text-sm outline-none transition-colors" required/>
            </div>
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider font-medium">Contraseña</label>
              <input type="password" name="password" placeholder="••••••••"
                     class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-100 placeholder-slate-600 rounded-xl px-4 py-3 text-sm outline-none transition-colors" required/>
            </div>
            <div>
              <label class="text-xs text-slate-400 uppercase tracking-wider font-medium">Rol</label>
              <select name="rol" class="w-full mt-1.5 bg-slate-800 border border-slate-700 focus:border-blue-500 text-slate-200 rounded-xl px-4 py-3 text-sm outline-none transition-colors">
                <option value="cliente">Cliente</option>
                <option value="vendedor">Vendedor</option>
                <option value="arrendador">Arrendador</option>
              </select>
            </div>
            <button type="submit" class="mt-2 bg-blue-600 hover:bg-blue-500 text-white py-3 rounded-xl font-medium transition-all btn-glow">
              Entrar / Registrarse
            </button>
          </form>
          <p class="text-xs text-slate-600 mt-5 text-center">
            Si el usuario no existe, se registrará automáticamente.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
