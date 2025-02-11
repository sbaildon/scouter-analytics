defmodule Stats.Domains do
  @moduledoc false
  alias Stats.Domain
  alias Stats.Repo

  def register(host) do
    Repo.insert(Domain.changeset(%{host: host}))
  end

  def list do
    Repo.all(Domain)
  end
end
