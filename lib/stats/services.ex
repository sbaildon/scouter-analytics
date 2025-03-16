defmodule Stats.Services do
  @moduledoc false
  alias Stats.Domain
  alias Stats.Repo

  def register(name) do
    Repo.insert(Domain.changeset(%{name: name}))
  end

  def get_by_name(name) do
    Domain.query()
    |> Domain.where_published()
    |> Domain.where_name(name)
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
