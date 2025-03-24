defmodule Mix.Tasks.GeneratePageviews do
  @moduledoc false
  use Mix.Task

  defp default_host, do: "https://" <> System.fetch_env!("TELEMETRY_HOST")
  defp default_path, do: "/"
  defp default_ip, do: "127.0.0.1"
  defp default_origin, do: System.fetch_env!("DASHBOARD_HOST")

  defp default_user_agent,
    do:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284"

  defp default_query_params, do: ""

  defp default_referrer, do: "https://com.apple.terminal"

  @options [
    ip: :string,
    user_agent: :string,
    domain: :string,
    path: :string,
    referrer: :string,
    host: :string,
    query_params: :string,
    origin: :string
  ]

  @impl Mix.Task
  def run(args) do
    Application.ensure_started(:telemetry)

    Finch.start_link(
      name: Stats.Finch,
      pools: %{
        default_host() => [
          conn_opts: [
            transport_opts: [
              verify: :verify_none
            ]
          ]
        ]
      }
    )

    {parsed, _, invalid} = OptionParser.parse(args, strict: @options)

    case invalid do
      [] ->
        send(parsed)

      [invalid_option | _] ->
        IO.inspect(invalid_option)
        IO.puts(usage())
    end
  end

  def send(opts) do
    to = Keyword.get(opts, :host, default_host())
    # can't use without some proxy configuration
    # https://hexdocs.pm/remote_ip/RemoteIp.html
    _ip = Keyword.get(opts, :ip, default_ip())
    user_agent = Keyword.get(opts, :user_agent, default_user_agent())

    headers = [
      {"user-agent", user_agent},
      {"Content-Type", "application/json"}
    ]

    bot = "0"

    body = %{
      b: bot,
      p: Keyword.get(opts, :path, default_path()),
      q: Keyword.get(opts, :query_params, default_query_params()),
      r: Keyword.get(opts, :referrer, default_referrer()),
      o: Keyword.get(opts, :origin, default_origin())
    }

    opts = []

    req = Finch.build("POST", to <> "/telemetry", headers, JSON.encode!(body), opts)

    Finch.request(req, Stats.Finch)
  end

  defp usage do
    """
    usage: $ mix send_pageview [--domain domain] [--ip ip_address]"
    options: #{inspect(@options, pretty: true)}
    """
  end
end
