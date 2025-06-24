defmodule Dashboard.RateLimit do
  @moduledoc false
  use Hammer,
    backend: :ets,
    algorithm: :fix_window
end
