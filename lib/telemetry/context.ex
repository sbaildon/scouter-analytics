defmodule Telemetry.Context do
  @moduledoc false
  use Ecto.Schema

  alias UAInspector.Result, as: UserAgent

  @primary_key false
  embedded_schema do
    embeds_one :count, Telemetry.Count
    embeds_one :service, Scouter.Service
    embeds_one :user_agent, UserAgent
    embeds_one :geo, :map
    field :headers, {:array, :string}
  end
end
