defmodule Telemetry.EventController do
  use Telemetry, :controller

  alias Scouter.Event
  alias Scouter.Services
  alias Telemetry.Context
  alias UAInspector.Result, as: UserAgent

  require Logger

  def call(conn, _params) do
    :ok =
      conn.params
      |> Map.put("u", NaiveDateTime.utc_now())
      |> Telemetry.Ingest.push(conn.req_headers, conn.private.scouter_instance)

    resp(conn, :ok, "ok")
  end

  def transform(instance, params, headers) do
    case Telemetry.Count.validate(params) do
      {:ok, count} ->
        context = %Context{instance: instance}
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
        continue_unless_spammer(%{context | user_agent: user_agent})

      %UserAgent.Bot{} ->
        {:error, :is_bot}
    end
  end

  defp continue_unless_spammer(context) when is_map(context.count.o) do
    if ReferrerBlocklist.is_spammer?(context.count.o.host) do
      {:error, :spam_host}
    else
      continue_unless_invalid_service(context)
    end
  end

  defp continue_unless_spammer(context) do
    continue_unless_invalid_service(context)
  end

  defp continue_unless_invalid_service(context) when is_map(context.count.o) do
    case Services.fetch(context.instance, context.count.i) do
      {:ok, service} -> continue_if_pattern_match(%{context | service: service})
      {:error, :not_found} -> {:error, :service_not_found}
    end
  end

  defp continue_unless_invalid_service(_context) do
    {:error, :no_origin}
  end

  defp continue_if_pattern_match(%{instance: instance, service: service, count: count} = context) do
    callback = fn ->
      Enum.find_value(service.matchers, {:ok, nil}, fn matcher ->
        Regex.match?(matcher.regex, count.o.host) && {:ok, matcher.id}
      end)
    end

    case ConCache.fetch_or_store(Scouter.Instances.get_cache(instance), count.o.host, callback) do
      {:ok, nil} -> {:error, :no_pattern_match}
      {:ok, _} -> country_code_step(context)
    end
  end

  defp country_code_step(context) do
    case Map.fetch(Cldr.Timezone.territories_by_timezone(), context.count.z) do
      {:ok, country_code} -> continue(%{context | country_code: country_code})
      :error -> continue(context)
    end
  end

  def continue(context) do
    Logger.debug(origin: context.count.o.host)

    {:ok,
     %Event{
       entity_id: Identifier.uuid(context.service.id),
       type: "pageview",
       timestamp: utc_now_s(context.count.u),
       properties: %{
         namespace: context.count.o.host,
         path: context.count.p,
         referrer: referrer(context.count.r),
         referrer_source: referrer_source(context.count.r),
         browser: browser(context.user_agent),
         browser_version: browser_version(context.user_agent),
         operating_system: os(context.user_agent),
         operating_system_version: os_version(context.user_agent),
         country_code: context.country_code,
         utm_medium: utm_medium(context.count.q),
         utm_source: utm_source(context.count.q),
         utm_campaign: utm_campaign(context.count.q),
         utm_content: utm_content(context.count.q)
       }
     }}
  end

  defp referrer(nil), do: nil
  defp referrer(%{scheme: nil, host: nil, path: nil}), do: nil
  defp referrer(%{scheme: nil, host: nil, path: path}), do: path
  defp referrer(%{host: host}), do: host

  defp referrer_source(nil), do: nil

  defp referrer_source(%URI{} = uri),
    do: uri |> URI.to_string() |> RefInspector.parse() |> Map.fetch!(:source) |> nil_if_unknown()

  defp referrer_source(_other), do: nil

  defp nil_if_unknown(:unknown), do: nil
  defp nil_if_unknown(other), do: other

  defp utc_now_s(naivedatetime), do: NaiveDateTime.truncate(naivedatetime, :second)

  defp utm_medium(%{"utm_medium" => value}), do: value
  defp utm_medium(_), do: nil

  defp utm_source(%{"utm_source" => value}), do: value
  defp utm_source(_), do: nil

  defp utm_campaign(%{"utm_campaign" => value}), do: value
  defp utm_campaign(_), do: nil

  defp utm_content(%{"utm_content" => value}), do: value
  defp utm_content(_), do: nil

  defp browser(%UserAgent{browser_family: :unknown}), do: nil
  defp browser(%UserAgent{browser_family: browser}), do: browser

  defp browser_version(%UserAgent{client: :unknown}), do: nil
  defp browser_version(%UserAgent{client: %UserAgent.Client{version: :unknown}}), do: nil
  defp browser_version(%UserAgent{client: %UserAgent.Client{version: version}}), do: version

  defp os(%UserAgent{os_family: :unknown}), do: nil
  defp os(%UserAgent{os_family: "Mac"}), do: "macOS"
  defp os(%UserAgent{os_family: os}), do: os

  defp os_version(%UserAgent{os: :unknown}), do: nil
  defp os_version(%UserAgent{os: %UserAgent.OS{version: :unknown}}), do: nil
  defp os_version(%UserAgent{os: %UserAgent.OS{version: version}}), do: version

  defp user_agent(headers) do
    {"user-agent", user_agent_header} = List.keyfind(headers, "user-agent", 0)
    UAInspector.parse(user_agent_header)
  end
end
