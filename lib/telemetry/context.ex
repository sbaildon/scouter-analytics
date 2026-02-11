defmodule Telemetry.Context do
  @moduledoc false
  use Ecto.Schema

  alias UAInspector.Result, as: UserAgent

  defstruct [
    :instance,
    :count,
    :service,
    :user_agent,
    :country_code,
    :headers
  ]

  @type t :: %__MODULE__{
          instance: atom(),
          count: %Telemetry.Count{},
          service: %Scouter.Service{},
          user_agent: UserAgent.t(),
          country_code: atom(),
          headers: [String.t()]
        }
end
