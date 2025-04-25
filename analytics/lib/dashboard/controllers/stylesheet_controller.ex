defmodule Dashboard.StylesheetController do
  use Dashboard, :controller

  def css(conn, _params) do
    case List.keyfind(conn.req_headers, header(), 0) do
      {_, custom_css} ->
        send_css(conn, custom_css)

      nil ->
        no_content(conn)
    end
  end

  defp send_css(conn, header) do
    conn
    |> put_resp_content_type("text/css")
    |> put_root_layout(false)
    |> send_resp(200, header |> stylesheet_urls() |> body())
  end

  defp body(stylesheet_urls) do
    Enum.map(stylesheet_urls, fn stylesheet_url ->
      [?@, "import", ?\s, ?", stylesheet_url, ?", ?\s, "layer(custom)", ?\n]
    end)
  end

  defp stylesheet_urls(header) do
    header
    |> String.trim()
    |> String.trim(";")
    |> String.split(";", trim: true)
  end

  defp header, do: "x-custom-css"

  defp no_content(conn), do: conn |> put_resp_content_type("text/css") |> send_resp(204, "")
end
