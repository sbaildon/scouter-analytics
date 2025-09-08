defmodule Dashboard.ArrowChannel do
  @moduledoc false
  use Dashboard, :channel

  import Scouter.Events.GroupingID

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S
  require Logger

  def join("arrow", _message, socket) do
    {:ok, _} = Registry.register(Dashboard.ArrowChannelRegistry, :erlang.phash2(socket.transport_pid), socket.channel_pid)

    {:ok, group_id_to_input_map(), socket}
  end

  def handle_cast({:push, dataframes}, socket) do
    Enum.each(dataframes, fn {group_id, df} ->
      {:ok, arrow} = Explorer.DataFrame.dump_ipc_stream(df)

      # send 32bit length group_id so it can be understood on the other side
      push(socket, "receive", {:binary, <<group_id::32>> <> arrow})
    end)

    {:noreply, socket}
  end

  defp group_id_to_input_map do
    %{
      group_id(:namespace) => :namespaces,
      group_id(:path) => :paths,
      group_id(:referrer) => :referrers,
      group_id(:referrer_source) => :referrers,
      group_id(:utm_medium) => :utm_mediums,
      group_id(:utm_source) => :utm_sources,
      group_id(:utm_campaign) => :utm_campaigns,
      group_id(:utm_term) => :utm_terms,
      group_id(:country_code) => :country_codes,
      group_id(:operating_system) => :operating_systems,
      group_id(:operating_system_version) => :operating_system_versions,
      group_id(:browser) => :browsers,
      group_id(:browser_version) => :browser_versions
    }
  end
end
