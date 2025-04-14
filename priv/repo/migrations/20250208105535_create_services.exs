defmodule Scouter.Repo.Migrations.CreateServices do
  use Ecto.Migration

  def change do
    create table(:services, options: "STRICT") do
      add :published, :boolean, null: false, default: true

      timestamps()
    end
  end
end
