defmodule InmobiliariaWeb.ErrorHTML do
  use Phoenix.Component

  # Renderiza una página HTML simple cuando una ruta no es encontrada.
  def render("404.html", assigns) do
    ~H"""
    <div style="text-align:center; padding: 50px;">
      <h1>404 - Pagina no encontrada</h1>
      <a href="/">Volver al inicio</a>
    </div>
    """
  end

  # Renderiza una página HTML simple cuando ocurre un error interno del servidor.
  def render("500.html", assigns) do
    ~H"""
    <div style="text-align:center; padding: 50px;">
      <h1>500 - Error interno del servidor</h1>
      <a href="/">Volver al inicio</a>
    </div>
    """
  end
end
