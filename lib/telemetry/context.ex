defmodule Telemetry.Context do
  @moduledoc false
  use Ecto.Schema

  alias UAInspector.Result, as: UserAgent

  defstruct [
    :instance,
    :count,
    :service,
    :user_agent,
    :geo,
    :headers
  ]

  @type t :: %__MODULE__{
          instance: atom(),
          count: %Telemetry.Count{},
          service: %Scouter.Service{},
          user_agent: UserAgent.t(),
          geo: Map.t(),
          headers: [String.t()]
        }
end
