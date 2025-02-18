defmodule Stats.Aggregates.GroupingId do
  @moduledoc false
  defmacro host, do: quote(do: 0b0111111111111111)
  defmacro country_code, do: quote(do: 0b1111111101111111)
  defmacro referrer, do: quote(do: 0b1101111111111111)
end
