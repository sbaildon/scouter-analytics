defmodule Telemetry.Broadway do
  @moduledoc false
  use Broadway

  alias Stats.Events

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__, [{:name, __MODULE__} | config()])
  end

  defp config do
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
      ]
    ]
  end

  def transform(event, _opts) do
    %Broadway.Message{
      data: event,
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  @impl Broadway
  def handle_message(_processor, %{data: data} = message, _context) do
    {params, headers} = data

    case Telemetry.EventController.transform(params, headers) do
      {:ok, data} ->
        Broadway.Message.put_data(message, data)

      {:error, reason} ->
        Logger.info("couldn't transform event #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
    |> Enum.map(&Events.prepare_insert_all(&1.data))
    |> Events.record()

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
