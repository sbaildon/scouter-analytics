defmodule Stats.Events do
  @moduledoc false
  use Agent

  alias Stats.Event
  alias Stats.EventsRepo

  require Logger

  def start_link(_) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def hourly do
    Event.query()
    |> Event.hourly()
    |> EventsRepo.all()
  end

  def retrieve(count_by, filters \\ []) do
    Event.query()
    |> Event.count_by(count_by)
    |> filter(filters)
    |> EventsRepo.all()
  end

  defp filter(query, []), do: query

  defp filter(query, [{_, nil} | rest]) do
    filter(query, rest)
  end

  defp filter(query, [{_, []} | rest]) do
    filter(query, rest)
  end

  defp filter(query, [{:operating_systems, values} | rest]) do
    filter(Event.where_in(query, :operating_system, values), rest)
  end

  defp filter(query, [{:operating_system_versions, values} | rest]) do
    filter(Event.where_in(query, :operating_system_version, values), rest)
  end

  defp filter(query, [{:browsers, values} | rest]) do
    filter(Event.where_in(query, :browser, values), rest)
  end

  defp filter(query, [{:browser_versions, values} | rest]) do
    filter(Event.where_in(query, :browser_version, values), rest)
  end

  defp filter(query, [{:paths, values} | rest]) do
    filter(Event.where_in(query, :path, values), rest)
  end

  defp filter(query, [_ | rest]) do
    filter(query, rest)
  end

  def record(event) do
    Agent.get(__MODULE__, &record(&1, event))
  end

  def record(_context, %Event{} = event) do
    now = NaiveDateTime.utc_now()

    events =
      for _i <- 1..100 do
        ua = random_ua()

        event
        |> Map.replace(:operating_system, ua.os.name)
        |> Map.replace(:operating_system_version, ua.os.version)
        |> Map.replace(:browser, ua.browser_family)
        |> Map.replace(:browser_version, ua.client.version)
        |> Map.replace(:site_id, TypeID.new("site"))
        |> Map.replace(:timestamp, now)
        |> Map.from_struct()
        |> Map.delete(:__meta__)
      end

    EventsRepo.insert_all(Event, events)
  end

  def load(event) when is_list(event) do
    fields = Event.__schema__(:fields)

    fields
    |> Enum.zip(event)
    |> Map.new()
    |> Map.replace_lazy(:timestamp, fn {d, {h, m, s, us}} ->
      NaiveDateTime.from_erl!({d, {h, m, s}}, us)
    end)
    |> Event.changeset()
    |> Ecto.Changeset.apply_action!(:validate)
  end

  defp random_ua, do: user_agents() |> Enum.random() |> UAInspector.parse()

  defp user_agents do
    [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.3",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Safari/605.1.1",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.1",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.",
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.3",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Mobile/15E148 Safari/604.",
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/27.0 Chrome/125.0.0.0 Mobile Safari/537.3",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/132.0.6834.100 Mobile/15E148 Safari/604.",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604."
    ]
  end
end
