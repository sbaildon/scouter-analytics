defmodule LiveHelpers do
  @moduledoc false
  defmacro is_connected(socket) do
    quote do
      unquote(socket).transport_pid != nil
    end
  end
end
