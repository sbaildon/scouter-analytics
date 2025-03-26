defmodule ControllerHelpers do
  @moduledoc false

  defmacro is_method(conn, method) do
    quote do
      unquote(conn).method == unquote(method)
    end
  end

  def partial(conn, name, assigns \\ %{}) do
    view = Phoenix.Controller.view_module(conn)

    html =
      view
      |> apply(name, [assigns])
      |> Phoenix.HTML.Safe.to_iodata()
      |> to_string()

    Phoenix.Controller.html(conn, html)
  end
end
