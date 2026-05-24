defmodule InmobiliariaWeb.Layouts do
  use Phoenix.Component

  # Renderiza el layout base de toda la aplicación web. Carga Tailwind CSS, Phoenix y LiveView
  # desde CDN, gestiona la sesión del usuario en localStorage (leyendo y guardando usuario/rol
  # desde la URL), inicializa el socket de LiveView con los parámetros de sesión, y expone
  # la función global cerrarSesion() para limpiar la sesión del navegador.
  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="es">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()}/>
        <title>Inmobiliaria UQ</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.14/priv/static/phoenix.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.20.17/priv/static/phoenix_live_view.min.js"></script>
        <script>
          window.addEventListener("DOMContentLoaded", () => {
            let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

            // Guardar sesion en localStorage cuando viene en la URL
            let params = new URLSearchParams(window.location.search);
            if (params.get("usuario")) {
              localStorage.setItem("usuario", params.get("usuario"));
              localStorage.setItem("rol", params.get("rol"));
            }

            let usuario = localStorage.getItem("usuario") || "";
            let rol = localStorage.getItem("rol") || "";

            let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
              params: {
                _csrf_token: csrfToken,
                usuario: usuario,
                rol: rol
              }
            });

            liveSocket.connect();
            window.liveSocket = liveSocket;

            // Exponer funcion para cerrar sesion
            window.cerrarSesion = () => {
              localStorage.removeItem("usuario");
              localStorage.removeItem("rol");
              window.location.href = "/";
            };
          });
        </script>
      </head>
      <body class="bg-gray-100 text-gray-800">
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end
