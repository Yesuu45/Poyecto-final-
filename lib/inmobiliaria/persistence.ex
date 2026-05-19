defmodule Inmobiliaria.Persistence do
  @data_dir "data"
  @files ["users.dat", "properties.dat", "results.log", "messages.dat", "locations.dat"]

  @default_location "Armenia\nBogota\nCali\nMedellin\nPereira\nManizales\nIbague"

  def init_files do
    File.mkdir_p!(@data_dir)
    Enum.each(@files, fn file ->
      path = Path.join(@data_dir, file)
      unless File.exists?(path) do
        initial = if file == "locations.dat", do: @default_location, else: ""
        File.write!(path, initial)
      end
    end)
  end

  def read_lines(filename) do
    path = Path.join(@data_dir, filename)
    case File.read(path) do
      {:ok, content} -> content |> String.split("\n", trim: true) |> Enum.reject(&(&1 == ""))
      {:error, _} -> []
    end
  end

  def write_line(filename, line) do
    path = Path.join(@data_dir, filename)
    File.mkdir_p!(@data_dir)
    File.write!(path, line <> "\n", [:append])
  end

  def write_lines(filename, lines) do
    path = Path.join(@data_dir, filename)
    File.mkdir_p!(@data_dir)
    File.write!(path, Enum.join(lines, "\n") <> "\n")
  end
end
