defmodule Stats.Events.GroupingID do
  @moduledoc false
  defmacro group_id(:host), do: 0b0111111111111111
  defmacro group_id(:path), do: 0b1011111111111111
  defmacro group_id(:referrer), do: 0b1101111111111111
  defmacro group_id(:utm_medium), do: 0b1110111111111111
  defmacro group_id(:utm_source), do: 0b1111011111111111
  defmacro group_id(:utm_campaign), do: 0b1111101111111111
  defmacro group_id(:utm_content), do: 0b1111110111111111
  defmacro group_id(:utm_term), do: 0b1111111011111111
  defmacro group_id(:country_code), do: 0b1111111101111111
  defmacro group_id(:subdivision1_code), do: 0b1111111110111111
  defmacro group_id(:subdivision2_code), do: 0b1111111111011111
  defmacro group_id(:city_geoname_id), do: 0b1111111111101111
  defmacro group_id(:operating_system), do: 0b1111111111110111
  defmacro group_id(:operating_system_version), do: 0b1111111111111011
  defmacro group_id(:browser), do: 0b1111111111111101
  defmacro group_id(:browser_version), do: 0b1111111111111110
end
