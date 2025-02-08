defmodule Stats.Repo.Migrations.CreateDomains do
  use Ecto.Migration

  def change do
    create table("domains", options: "STRICT") do
      add :host, :string, null: false
      timestamps()
    end

    create unique_index("domains", :host)
  end
end
