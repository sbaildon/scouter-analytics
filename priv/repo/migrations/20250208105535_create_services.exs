defmodule Stats.Repo.Migrations.CreateServices do
  use Ecto.Migration

  def change do
    create table(:services, options: "STRICT") do
      add :name, :text, null: false
      add :published, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:services, :name)
  end
end
