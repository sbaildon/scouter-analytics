defmodule Dashboard.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use Dashboard, :controller` and
  `use Dashboard, :live_view`.
  """
  use Dashboard, :html

  embed_templates "layouts/*"

  attr :conn, Plug.Conn, required: true

  def import_map(assigns) do
    ~H"""
    <script type="importmap">
      <%= raw(Phoenix.json_library().encode_to_iodata!(imports(@conn))) %>
    </script>
    """
  end

  defp imports(conn) do
    %{
      "imports" => %{
        "@hotwired/stimulus" => static_url(conn, "/js/@hotwired/stimulus@3.2.2.js"),
        "@github/hotkey" => static_url(conn, "/js/@github/hotkey@3.1.1/index.js"),
        "controllers/service" => static_url(conn, "/js/dashboard/service_controller.js"),
        "controllers/hotkey" => static_url(conn, "/js/dashboard/hotkey_controller.js"),
        "phoenix_live_view" => static_url(conn, "/js/phoenix_live_view.esm.js"),
        "phoenix" => static_url(conn, "/js/phoenix.mjs"),
        "topbar" => static_url(conn, "/js/topbar.js")
      }
    }
  end

  attr :endpoint, :any, required: true

  def base(assigns) do
    assigns = assign(assigns, :href, struct(URI, assigns.endpoint.config(:url)))

    ~H"""
    <base href={@href} />
    """
  end

  attr :headers, :list, required: true
  attr :stylesheets, :list, required: false

  def stylesheets(assigns) do
    {_, header} = List.keyfind(assigns.headers, stylesheet_header(), 0, {nil, ""})

    assigns = assign(assigns, :stylesheets, stylesheet_urls(header))

    ~H"""
    <link :for={stylesheet <- @stylesheets} rel="stylesheet" href={stylesheet} />
    """
  end

  defp stylesheet_header, do: "x-custom-stylesheets"

  defp stylesheet_urls(header) do
    header
    |> String.trim()
    |> String.trim(";")
    |> String.split(";", trim: true)
  end

  attr :conn, Plug.Conn, required: true

  if Application.compile_env(:scouter, :dev_routes) do
    defp development_scripts(assigns),
      do: ~H|<script phx-track-static defer src={static_url(@conn, "/js/development.js")}></script>|
  else
    def development_scripts(assigns), do: nil
  end
end
