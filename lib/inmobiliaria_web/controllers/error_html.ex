defmodule InmobiliariaWeb.ErrorHTML do
  use Phoenix.Component

  def render("404.html", assigns) do
    ~H"""
    <div style="text-align:center; padding: 50px;">
      <h1>404 - Pagina no encontrada</h1>
      <a href="/">Volver al inicio</a>
    </div>
    """
  end

  def render("500.html", assigns) do
    ~H"""
    <div style="text-align:center; padding: 50px;">
      <h1>500 - Error interno del servidor</h1>
      <a href="/">Volver al inicio</a>
    </div>
    """
  end
end
