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

  def import_map(assigns) do
    ~H"""
    <script type="importmap">
      <%= raw(Phoenix.json_library().encode_to_iodata!(imports())) %>
    </script>
    """
  end

  defp imports do
    %{
      "imports" => %{
        "@hotwired/stimulus" => "#{Dashboard.Endpoint.url()}/js/@hotwired/stimulus@3.2.2.js",
        "@github/hotkey" => "#{Dashboard.Endpoint.url()}/js/@github/hotkey@3.1.1/index.js",
        "controllers/service" => "#{Dashboard.Endpoint.url()}/js/dashboard/service_controller.js",
        "controllers/hotkey" => "#{Dashboard.Endpoint.url()}/js/dashboard/hotkey_controller.js"
      }
    }
  end

  attr :endpoint, :any, required: true

  def base(assigns) do
    assigns = assign(assigns, :href, struct(URI, apply(assigns.endpoint, :config, [:url])))

    ~H"""
    <base href={@href} />
    """
  end
end
