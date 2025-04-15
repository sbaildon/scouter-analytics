defmodule Scouter.Events.GroupingID do
  @moduledoc false
  defmacro group_id(:namespace), do: 0b01111111111111111
  defmacro group_id(:path), do: 0b10111111111111111
  defmacro group_id(:referrer), do: 0b11011111111111111
  defmacro group_id(:referrer_source), do: 0b11101111111111111
  defmacro group_id(:utm_medium), do: 0b11110111111111111
  defmacro group_id(:utm_source), do: 0b11111011111111111
  defmacro group_id(:utm_campaign), do: 0b11111101111111111
  defmacro group_id(:utm_content), do: 0b11111110111111111
  defmacro group_id(:utm_term), do: 0b11111111011111111
  defmacro group_id(:country_code), do: 0b11111111101111111
  defmacro group_id(:subdivision1_code), do: 0b11111111110111111
  defmacro group_id(:subdivision2_code), do: 0b11111111111011111
  defmacro group_id(:city_geoname_id), do: 0b11111111111101111
  defmacro group_id(:operating_system), do: 0b11111111111110111
  defmacro group_id(:operating_system_version), do: 0b11111111111111011
  defmacro group_id(:browser), do: 0b11111111111111101
  defmacro group_id(:browser_version), do: 0b11111111111111110
end
