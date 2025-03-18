defmodule Stats.Services do
  @moduledoc false
  alias Stats.Repo
  alias Stats.Service

  def register(name) do
    Repo.insert(Service.changeset(%{name: name}))
  end

  def get_by_name(name) do
    Service.query()
    |> Service.where_published()
    |> Service.where_name(name)
    |> EctoHelpers.one()
  end

  def list do
    Repo.all(Service)
  end

  def list_published do
    Service.query()
    |> Service.where_published()
    |> Repo.all()
  end
end
