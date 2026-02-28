defmodule Scouter.EventsRepo.Migrations.CreateEvents do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table("events", primary_key: false) do
      add :entity_id, :uuid, null: false
      add :timestamp, :naive_datetime, null: false
      add :type, :string, null: false
      add :properties, :json, null: false
    end

    execute(
      ~S"""
      ALTER TABLE events SET PARTITIONED BY (entity_id, year(timestamp), month(timestamp));
      """,
      ""
    )
  end
end
