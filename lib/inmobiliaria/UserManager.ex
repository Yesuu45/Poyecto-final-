defmodule Inmobiliaria.UserManager do
  use GenServer

  # API Pública
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def conectar_con_rol(username, password, _rol) do
    GenServer.call(__MODULE__, {:conectar, username, password})
  end

  # Callbacks del GenServer
  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:conectar, username, password}, _from, state) do
    case buscar_usuario(username, state) do
      nil ->
        {:reply, {:error, "Usuario no encontrado"}, state}
      user when user.password == password ->
        {:reply, {:ok, user}, state}
      _ ->
        {:reply, {:error, "Contraseña incorrecta"}, state}
    end
  end

  @impl true
  def handle_call({:obtener, username}, _from, state) do
    {:reply, {:ok, Map.get(state, username, %{puntaje: 0})}, state}
  end

  # Función privada para búsqueda interna
  defp buscar_usuario(username, state) do
    Map.get(state, username)
  end

  # Otras funciones
  def sumar_puntos(_u, _p), do: :ok

  # CORRECCIÓN: Definición simple sin "else"
  def ranking(), do: []

  def obtener(username) do
    GenServer.call(__MODULE__, {:obtener, username})
  end
end
