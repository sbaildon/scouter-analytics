defmodule Stats.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table("sites", options: "STRICT") do
      add :published, :boolean, null: false, default: true
      timestamps()
    end
  end
end
