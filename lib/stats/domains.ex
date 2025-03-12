defmodule Stats.Domains do
  @moduledoc false
  alias Stats.Domain
  alias Stats.Repo

  def register(host) do
    Repo.insert(Domain.changeset(%{host: host}))
  end

  def get_by_host(host) do
    Domain.query()
    |> Domain.where_published()
    |> Domain.where_host(host)
    |> EctoHelpers.one()
  end

  def list do
    Repo.all(Domain)
  end

  def list_published do
    Domain.query()
    |> Domain.where_published()
    |> Repo.all()
  end
end
