defmodule Telemetry.Broadway do
  @moduledoc false
  use Broadway

  alias Scouter.Events

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__, [{:name, __MODULE__} | config()])
  end

  defp config do
    [
      producer: [
        module: {Telemetry.Ingest, []},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: 1,
          max_demand: max_demand(),
          min_demand: min_demand(),
          partition_by: &partition_by/1
        ]
      ],
      batchers: [
        default: [batch_size: batch_size(), batch_timeout: batch_timeout()]
      ]
    ]
  end

  def partition_by(%{metadata: %{instance: instance}}) do
    :erlang.phash2(instance)
  end

  @impl Broadway
  def handle_message(_processor, message, _context) do
    {params, headers} = message.data
    %{instance: instance} = message.metadata

    case Telemetry.EventController.transform(instance, params, headers) do
      {:ok, event} ->
        event
        |> Events.for_insert_all()
        |> then(&Broadway.Message.put_data(message, &1))
        |> Broadway.Message.put_batch_key(instance)

      {:error, reason} ->
        Logger.info("couldn't transform event #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  # would like to match on ^size, but at the moment, record_all always returns {1, [_]}
  @impl Broadway
  def handle_batch(_batcher, messages, %{batch_key: instance, size: size}, _context) do
    {_, _} =
      messages
      |> Enum.map(fn %{data: event} -> event end)
      |> then(fn events -> Events.record_all(instance, events) end)

    messages
  end

  @impl Broadway
  def handle_failed([message | _] = messages, _context) do
    {:failed, reason} = message.status
    Logger.info("failed #{Enum.count(messages)} message(s), first failed for reason: #{inspect(reason)}")

    messages
  end

  defp batch_size, do: 1000
  defp batch_timeout, do: to_timeout(second: 2)

  defp max_demand, do: 1000
  defp min_demand, do: 200
end
