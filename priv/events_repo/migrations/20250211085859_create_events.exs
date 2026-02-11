defmodule Scouter.EventsRepo.Migrations.CreateEvents do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table("events", primary_key: false) do
      add :service_id, :uuid, null: false
      add :timestamp, :naive_datetime, null: false
      add :type, :string, null: false
      add :properties, :json, null: false
    end
  end
end
