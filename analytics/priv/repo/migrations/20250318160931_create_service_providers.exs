defmodule Scouter.Repo.Migrations.CreateServiceProviders do
  use Ecto.Migration

  def change do
    create table(:service_providers) do
      add :service_id, references(:services, on_delete: :restrict), null: false
      add :namespace, :string, null: false

      timestamps()
    end

    create unique_index(:service_providers, [:namespace])

    alter table(:services) do
      add :primary_provider_id,
          references(:service_providers, with: [service_id: :id], on_delete: :delete_all),
          null: true
    end
  end
end
