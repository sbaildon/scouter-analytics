defmodule Scouter.Repo.Migrations.CreateServiceMatchers do
  use Ecto.Migration

  def change do
    create table(:service_matchers, options: "STRICT") do
      add :service_id, references(:services, on_delete: :restrict), null: false
      add :pattern, :string, null: false

      timestamps()
    end

    create unique_index(:service_matchers, [:service_id, :pattern])
  end
end
