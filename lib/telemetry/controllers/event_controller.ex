defmodule Telemetry.EventController do
  use Telemetry, :controller

  alias Stats.Event
  alias Stats.Services
  alias Telemetry.Context
  alias UAInspector.Result, as: UserAgent

  require Logger

  def record(conn, params) do
    :ok =
      params
      |> Map.put("u", NaiveDateTime.utc_now())
      |> Telemetry.Sink.push(conn.req_headers)

    resp(conn, :ok, "ok")
  end

  def transform(params, headers) do
    case Telemetry.Count.validate(params) do
      {:ok, count} ->
        context = %Context{}
        continue_unless_bot(%{context | count: count, headers: headers})

      {:error, changeset} ->
        Logger.debug(changeset: changeset)
        {:error, :invalid_params}
    end
  end

  defp continue_unless_bot(%{count: %{b: true}}) do
    {:error, :is_bot}
  end

  defp continue_unless_bot(context) do
    case user_agent(context.headers) do
      %UserAgent{} = user_agent ->
        Logger.debug(user_agent: user_agent)
        continue_unless_invalid_service(%{context | user_agent: user_agent})

      %UserAgent.Bot{} ->
        {:error, :is_bot}
    end
  end

  defp continue_unless_invalid_service(context) do
    case Services.get_for_namespace(context.count.o.host) do
      {:ignore, nil} -> {:error, :service_not_registered}
      {_, service} -> geo_step(%{context | service: service})
    end
  end

  def geo_step(context) do
    ip = RemoteIp.from(context.headers, clients: clients())

    case Stats.Geo.lookup(ip) do
      {:ok, geo} ->
        continue(%{context | geo: geo})

      _other ->
        continue(context)
    end
  end

  def continue(context) do
    Logger.debug(origin: context.count.o.host)

    {:ok,
     %Event{
       service_id: TypeID.uuid(context.service.id),
       namespace: context.count.o.host,
       path: context.count.p,
       referrer: context.count.r,
       timestamp: utc_now_s(),
       browser: browser(context.user_agent),
       browser_version: browser_version(context.user_agent),
       operating_system: os(context.user_agent),
       operating_system_version: os_version(context.user_agent),
       country_code: country_code(context.geo),
       subdivision1_code: subdivision1_code(context.geo),
       subdivision2_code: subdivision2_code(context.geo),
       city_geoname_id: city_geoname_id(context.geo),
       utm_medium: utm_medium(context.count.q),
       utm_source: utm_source(context.count.q),
       utm_campaign: utm_campaign(context.count.q),
       utm_content: utm_content(context.count.q),
       utm_term: utm_term(context.count.q)
     }}
  end

  defp utc_now_s, do: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

  defp utm_medium(%{"utm_medium" => value}), do: value
  defp utm_medium(_), do: nil

  defp utm_source(%{"utm_source" => value}), do: value
  defp utm_source(_), do: nil

  defp utm_campaign(%{"utm_campaign" => value}), do: value
  defp utm_campaign(_), do: nil

  defp utm_content(%{"utm_content" => value}), do: value
  defp utm_content(_), do: nil

  defp utm_term(%{"utm_term" => value}), do: value
  defp utm_term(_), do: nil

  defp country_code(%{"country" => %{"iso_code" => country_code}}), do: country_code
  defp country_code(_other), do: nil

  defp subdivision1_code(%{"subdivisions" => [%{"iso_code" => iso_code} | _]}), do: iso_code
  defp subdivision1_code(_), do: nil

  defp subdivision2_code(%{"subdivisions" => [_, %{"iso_code" => iso_code} | []]}), do: iso_code
  defp subdivision2_code(_), do: nil

  defp city_geoname_id(%{"city" => %{"geoname_id" => city_geoname_id}}), do: city_geoname_id
  defp city_geoname_id(_other), do: nil

  defp browser(%UserAgent{browser_family: :unknown}), do: nil
  defp browser(%UserAgent{browser_family: browser}), do: browser

  defp browser_version(%UserAgent{client: :unknown}), do: nil
  defp browser_version(%UserAgent{client: %UserAgent.Client{version: :unknown}}), do: nil
  defp browser_version(%UserAgent{client: %UserAgent.Client{version: version}}), do: version

  defp os(%UserAgent{os_family: :unknown}), do: nil
  defp os(%UserAgent{os_family: os}), do: os

  defp os_version(%UserAgent{os: :unknown}), do: nil
  defp os_version(%UserAgent{os: %UserAgent.OS{version: :unknown}}), do: nil
  defp os_version(%UserAgent{os: %UserAgent.OS{version: version}}), do: version

  defp bot_response(conn), do: resp(conn, :forbidden, "forbidden")
  defp invalid_response(conn), do: resp(conn, :not_found, "not found")

  # allow 127.0.0.1 as client_ip when in development
  if Application.compile_env(:stats, :dev_routes) do
    defp clients, do: ["127.0.0.1"]
  else
    defp clients, do: []
  end

  defp user_agent(headers) do
    {"user-agent", user_agent_header} = List.keyfind(headers, "user-agent", 0)
    UAInspector.parse(user_agent_header)
  end
end
