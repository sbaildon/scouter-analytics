defmodule Stats.Repo.Migrations.CreateServiceProviders do
  use Ecto.Migration

  def change do
    create table(:service_providers) do
      add :service_id, references(:services, on_delete: :restrict), null: false
      add :namespace, :string, null: false

      timestamps()
    end

    create unique_index(:service_providers, [:service_id, :namespace])

    alter table(:services) do
      add :primary_provider, references(:service_providers, on_delete: :nilify_all), null: true
    end
  end
end
