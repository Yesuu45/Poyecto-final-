defmodule Inmobiliaria.UserManager do
  use GenServer

  alias Inmobiliaria.Persistence

  @filename "users.dat"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def conectar_con_rol(username, password, rol) do
    GenServer.call(__MODULE__, {:conectar, username, password, rol})
  end

  def sumar_puntos(username, puntos) do
    GenServer.call(__MODULE__, {:sumar_puntos, username, puntos})
  end

  def ranking do
    GenServer.call(__MODULE__, :ranking)
  end

  def obtener(username) do
    GenServer.call(__MODULE__, {:obtener, username})
  end

  @impl true
  def init(_) do
    {:ok, cargar_usuarios()}
  end

  @impl true
  def handle_call({:conectar, username, password, rol}, _from, state) do
    case Map.get(state, username) do
      nil ->
        user = %{username: username, password: password, rol: rol, puntaje: 0}
        new_state = Map.put(state, username, user)
        guardar_usuarios(new_state)
        {:reply, {:ok, user}, new_state}

      user when user.password == password ->
        {:reply, {:ok, user}, state}

      _ ->
        {:reply, {:error, "Contraseña incorrecta"}, state}
    end
  end

  @impl true
  def handle_call({:sumar_puntos, username, puntos}, _from, state) do
    case Map.get(state, username) do
      nil ->
        {:reply, :ok, state}

      user ->
        updated = %{user | puntaje: user.puntaje + puntos}
        new_state = Map.put(state, username, updated)
        guardar_usuarios(new_state)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:ranking, _from, state) do
    ranking =
      state
      |> Map.values()
      |> Enum.sort_by(& &1.puntaje, :desc)
      |> Enum.map(fn u -> {u.username, u.puntaje, u.rol} end)

    {:reply, ranking, state}
  end

  @impl true
  def handle_call({:obtener, username}, _from, state) do
    {:reply, {:ok, Map.get(state, username, %{puntaje: 0})}, state}
  end

  defp cargar_usuarios do
    Persistence.read_lines(@filename)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(String.trim(line), ";") do
        [username, rol, password, puntaje] ->
          user = %{
            username: username,
            rol: rol,
            password: password,
            puntaje: parse_int(puntaje)
          }

          Map.put(acc, username, user)

        _ ->
          acc
      end
    end)
  end

  defp parse_int(valor) do
    case Integer.parse(String.trim(valor)) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp guardar_usuarios(usuarios) do
    lineas =
      usuarios
      |> Map.values()
      |> Enum.map(fn u -> "#{u.username};#{u.rol};#{u.password};#{u.puntaje}" end)

    Persistence.write_lines(@filename, lineas)
  end
end
