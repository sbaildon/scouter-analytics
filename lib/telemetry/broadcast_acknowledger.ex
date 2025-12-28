defmodule Telemetry.BroadcastAcknowledger do
  @moduledoc false
  @behaviour Broadway.Acknowledger

  @doc """
  Returns the acknowledger metadata.
  """
  @spec init(instance :: atom()) :: Broadway.Message.acknowledger()
  def init(instance) do
    {__MODULE__, instance, nil}
  end

  @impl Broadway.Acknowledger
  def ack(instance, successful, _failed) do
    Phoenix.PubSub.broadcast(Scouter.PubSub, "telemetry", {instance, length(successful)})
  end
end
