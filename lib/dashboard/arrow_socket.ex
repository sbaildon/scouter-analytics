defmodule Dashboard.ArrowSocket do
  use Phoenix.LiveView.Socket

  channel "arrow", Dashboard.ArrowChannel
end
