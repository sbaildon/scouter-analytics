defmodule Scouter.Release do
  @moduledoc false
  def configure_ref_inspector do
    priv_dir = Application.app_dir(:scouter, "priv/ref_inspector")
    Application.put_env(:ref_inspector, :database_path, priv_dir)
  end

  def configure_ua_inspector do
    priv_dir = Application.app_dir(:scouter, "priv/ua_inspector")
    Application.put_env(:ua_inspector, :database_path, priv_dir)
  end
end
