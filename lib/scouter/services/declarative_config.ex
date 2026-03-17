defmodule Scouter.Services.DeclarativeConfig do
  @moduledoc """
  Reads declarative service configuration from INI files in:
  - /usr/share/scouter/analytics.d/*.conf
  - /etc/scouter/analytics.d/*.conf

  Files in /etc override those with the same name in /usr/share.
  Services are created only if they don't already exist (one-time migration style).
  """

  alias Scouter.Services

  require Logger

  defp usr_dir, do: "/usr/share/scouter/analytics/services.d"
  defp etc_dir, do: "/etc/scouter/analytics/services.d"

  @doc """
  Main entry point for the Task child.
  Loads declarative configurations for the main instance.
  """
  def initialize do
    # Check if main instance is registered and running
    case Registry.lookup(Scouter.InstanceRegistry, "main") do
      [] ->
        Logger.warning("No main instance found, skipping service loading")
        :ok

      _ ->
        load_declarative_configs()
    end
  end

  defp load_declarative_configs do
    configs = read_all_configs()

    Enum.each(configs, fn {filename, config} ->
      case parse_service_config(config) do
        {:ok, service_params, matchers} ->
          create_service_if_not_exists("main", service_params, matchers, filename)

        {:error, reason} ->
          Logger.error("Failed to parse #{filename}: #{reason}")
      end
    end)
  end

  defp read_all_configs do
    usr_files = read_directory(usr_dir())
    etc_files = read_directory(etc_dir())

    # Merge with /etc taking precedence for same-named files
    usr_files
    |> Map.merge(etc_files)
    |> Enum.to_list()
  end

  defp read_directory(dir) do
    if File.dir?(dir) do
      dir
      |> Path.join("*.conf")
      |> Path.wildcard()
      |> Enum.reduce(%{}, fn path, acc ->
        filename = Path.basename(path)

        case ConfigParser.parse_file(path) do
          {:ok, config} ->
            Map.put(acc, filename, config)

          {:error, reason} ->
            Logger.error("Failed to read #{path}: #{inspect(reason)}")
            acc
        end
      end)
    else
      %{}
    end
  end

  defp parse_service_config(config) do
    with {:ok, service_section} <- fetch_section(config, "Service"),
         {:ok, name} <- fetch_key(service_section, "Name") do
      published = parse_boolean(Map.get(service_section, "published", "true"))
      matchers = parse_matchers(config)
      {:ok, %{name: name, published: published}, matchers}
    end
  end

  defp fetch_section(config, section) do
    case Map.get(config, section) do
      nil -> {:error, "Missing [#{section}] section"}
      section_data -> {:ok, section_data}
    end
  end

  defp fetch_key(section, key) do
    case Map.get(section, key) do
      nil -> {:error, "Missing required key '#{key}' in [Service] section"}
      value -> {:ok, value}
    end
  end

  defp parse_boolean("true"), do: true
  defp parse_boolean("yes"), do: true
  defp parse_boolean("1"), do: true
  defp parse_boolean(true), do: true
  defp parse_boolean(_), do: false

  defp parse_matchers(config) do
    # Extract all [Matcher] sections - ConfigParser returns them as separate entries
    # or as a list if multiple sections have the same name
    case Map.get(config, "Matcher") do
      nil ->
        []

      matcher when is_list(matcher) ->
        Enum.flat_map(matcher, &parse_matcher_section/1)

      matcher ->
        parse_matcher_section(matcher)
    end
  end

  defp parse_matcher_section(section) do
    type_str = Map.get(section, "Type")
    value = Map.get(section, "Value")

    with true <- type_str != nil,
         true <- value != nil,
         {:ok, type} <- parse_matcher_type(type_str) do
      [{type, value}]
    else
      _ ->
        Logger.warning("Invalid matcher section: #{inspect(section)}")
        []
    end
  end

  defp parse_matcher_type("regex"), do: {:ok, :regex}
  defp parse_matcher_type("exact"), do: {:ok, :exact}
  defp parse_matcher_type("wildcard"), do: {:ok, :wildcard}
  defp parse_matcher_type(other), do: {:error, "Invalid matcher type: #{other}"}

  defp create_service_if_not_exists(instance, service_params, matchers, filename) do
    case Services.fetch_by_name(instance, service_params.name) do
      {:ok, _existing_service} ->
        Logger.debug("Service '#{service_params.name}' already exists, skipping (from #{filename})")
        :ok

      :error ->
        case Services.register(instance, service_params) do
          {:ok, service} ->
            Logger.info("Created service '#{service_params.name}' from #{filename}")
            create_matchers(instance, service.id, matchers)

          {:error, reason} ->
            Logger.error("Failed to create service '#{service_params.name}': #{inspect(reason)}")
        end
    end
  end

  defp create_matchers(_instance, _service_id, []), do: :ok

  defp create_matchers(instance, service_id, [{type, value} | rest]) do
    case Services.add_matcher(instance, service_id, type, value) do
      {:ok, _matcher} ->
        Logger.debug("Added #{type} matcher '#{value}' to service #{service_id}")
        create_matchers(instance, service_id, rest)

      {:error, reason} ->
        Logger.error("Failed to add matcher '#{value}' (#{type}): #{inspect(reason)}")
        create_matchers(instance, service_id, rest)
    end
  end
end
