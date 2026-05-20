defmodule Inmobiliaria.Persistence do
  @base_path "data"

  def init_files do
    File.mkdir_p!(@base_path)

    Enum.each(["users.dat", "properties.dat", "messages.dat"], fn f ->
      file = Path.join(@base_path, f)
      unless File.exists?(file), do: File.write!(file, "")
    end)
  end

  # CORRECCIÓN: read_lines devuelve lista vacía si el archivo no existe
  def read_lines(f) do
    path = Path.join(@base_path, f)
    File.mkdir_p!(@base_path)

    case File.read(path) do
      {:ok, contenido} -> String.split(contenido, "\n", trim: true)
      {:error, _} -> []
    end
  end

  def write_line(f, l) do
    File.mkdir_p!(@base_path)
    File.write!(Path.join(@base_path, f), l <> "\n", [:append])
  end

  def write_lines(f, ls) do
    File.mkdir_p!(@base_path)
    File.write!(Path.join(@base_path, f), Enum.join(ls, "\n") <> "\n")
  end
end
