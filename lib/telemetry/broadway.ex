defmodule Telemetry.Broadway do
  @moduledoc false
  use Broadway

  alias Scouter.Events

  require Logger

  def start_link(opts) do
    {name, _opts} = Keyword.pop!(opts, :name)
    Broadway.start_link(__MODULE__, [{:name, name} | config(name: name)])
  end

  @impl Broadway
  def process_name({:via, module, {registry_name, key}}, basename) do
    {:via, module, {registry_name, {key, basename}}}
  end

  defp config(opts) do
    {:via, Registry, {instance, _}} = Keyword.fetch!(opts, :name)

    [
      producer: [
        module: {Telemetry.Sink, []},
        concurrency: 1,
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: 1, max_demand: max_demand(), min_demand: min_demand()]
      ],
      batchers: [
        default: [batch_size: batch_size(), batch_timeout: batch_timeout_ms()]
      ],
      context: %{instance: instance}
    ]
  end

  def transform(event, _opts) do
    %Broadway.Message{
      data: event,
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  @impl Broadway
  def handle_message(_processor, %{data: data} = message, %{instance: instance}) do
    {params, headers} = data

    case Telemetry.EventController.transform(instance, params, headers) do
      {:ok, event} ->
        Broadway.Message.put_data(message, event)

      {:error, reason} ->
        Logger.info("couldn't transform event #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_batch(_batcher, messages, _batch_info, %{instance: instance}) do
    messages
    |> Enum.map(&Events.prepare_record_all(&1.data))
    |> then(fn events ->
      Events.record_all(instance, events)
    end)

    messages
  end

  @impl Broadway
  def handle_failed([message | _] = messages, _context) do
    {:failed, reason} = message.status
    Logger.info("failed #{Enum.count(messages)} message(s), first failed for #{inspect(reason)}")

    messages
  end

  defp batch_size, do: 1000
  defp batch_timeout_ms, do: 2000

  defp max_demand, do: 1000
  defp min_demand, do: 200
end
