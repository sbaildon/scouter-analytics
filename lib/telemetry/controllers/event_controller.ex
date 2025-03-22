defmodule Telemetry.EventController do
  use Telemetry, :controller

  alias Stats.Event
  alias Stats.Events
  alias Stats.Services
  alias Telemetry.Context
  alias UAInspector.Result, as: UserAgent

  require Logger

  def record(conn, params) do
    Logger.debug(params: params)
    Logger.debug(headrs: conn.req_headers)
    validate_or_fail(conn, %Context{}, params)
  end

  def validate_or_fail(conn, context, params) do
    case Telemetry.Count.validate(params) do
      {:ok, count} ->
        continue_unless_bot(conn, %{context | count: count})

      {:error, changeset} ->
        Logger.debug(changeset: changeset)
        resp(conn, :bad_request, "bad request")
    end
  end

  defp continue_unless_bot(conn, %{count: %{b: true}}) do
    bot_response(conn)
  end

  defp continue_unless_bot(conn, context) do
    case user_agent(conn.req_headers) do
      %UserAgent{} = user_agent ->
        Logger.debug(user_agent: user_agent)
        continue_unless_invalid_service(conn, %{context | user_agent: user_agent})

      %UserAgent.Bot{} ->
        bot_response(conn)
    end
  end

  defp continue_unless_invalid_service(conn, context) do
    case Services.get_for_namespace(context.count.o.host) do
      {:ignore, nil} -> invalid_response(conn)
      {_, service} -> geo_step(conn, %{context | service: service})
    end
  end

  def geo_step(conn, context) do
    ip = RemoteIp.from(conn.req_headers, clients: clients())

    case Stats.Geo.lookup(ip) do
      {:ok, geo} ->
        continue(conn, %{context | geo: geo})

      _other ->
        continue(conn, context)
    end
  end

  def continue(conn, context) do
    Logger.debug(origin: context.count.o.host)

    {1, _} =
      Events.record(%Event{
        site_id: TypeID.uuid(context.service.id),
        host: context.count.o.host,
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
      })

    resp(conn, :ok, "ok")
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
