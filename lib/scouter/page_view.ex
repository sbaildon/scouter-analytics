defmodule Scouter.PageView do
  import Ecto.Query

  defp named_binding, do: :event

  def query do
    from("web_analytics", as: ^named_binding())
  end

  def typed_aggregate_query(query) do
    query
    |> then(fn query ->
      from([{^named_binding(), e}] in query,
        select: %{
          count: selected_as(count(), :count),
          grouping_id:
            selected_as(
              fragment(
                "GROUPING (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) :: UINTEGER",
                e.namespace,
                e.path,
                e.referrer,
                e.referrer_source,
                e.utm_medium,
                e.utm_source,
                e.utm_campaign,
                e.utm_content,
                e.utm_term,
                e.country_code,
                e.operating_system,
                e.operating_system_version,
                e.browser,
                e.browser_version
              ),
              :grouping_id
            ),
          value:
            selected_as(
              fragment(
                "CASE ?
                  WHEN '0b01111111111111' THEN ?
                  WHEN '0b10111111111111' THEN ?
                  WHEN '0b11011111111111' THEN ?
                  WHEN '0b11101111111111' THEN ?
                  WHEN '0b11110111111111' THEN ?
                  WHEN '0b11111011111111' THEN ?
                  WHEN '0b11111101111111' THEN ?
                  WHEN '0b11111110111111' THEN ?
                  WHEN '0b11111111011111' THEN ?
                  WHEN '0b11111111101111' THEN ?
                  WHEN '0b11111111110111' THEN ?
                  WHEN '0b11111111111011' THEN ?
                  WHEN '0b11111111111101' THEN ?
                  WHEN '0b11111111111110' THEN ? END",
                selected_as(:grouping_id),
                e.namespace,
                e.path,
                e.referrer,
                e.referrer_source,
                e.utm_medium,
                e.utm_source,
                e.utm_campaign,
                e.utm_content,
                e.utm_term,
                e.country_code,
                e.operating_system,
                e.operating_system_version,
                e.browser,
                e.browser_version
              ),
              :value
            ),
          max:
            selected_as(
              over(max(selected_as(:count)), partition_by: selected_as(:grouping_id)),
              :max
            )
        }
      )
    end)
    |> then(fn query ->
      from([{^named_binding(), e}] in query,
        group_by:
          fragment(
            "GROUPING SETS((?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?))",
            e.namespace,
            e.path,
            e.referrer,
            e.referrer_source,
            e.utm_medium,
            e.utm_source,
            e.utm_campaign,
            e.utm_content,
            e.utm_term,
            e.country_code,
            e.operating_system,
            e.operating_system_version,
            e.browser,
            e.browser_version
          )
      )
    end)
    |> then(fn query ->
      from([{^named_binding(), event}] in query,
        order_by: [asc: selected_as(:grouping_id), desc: selected_as(:count)]
      )
    end)
  end
end
