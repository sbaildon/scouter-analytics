defmodule Stats.Cldr do
  @moduledoc false
  use Cldr,
    locales: [:en],
    gettext: Stats.Gettext,
    otp_app: :stats,
    providers: [Cldr.Territory]
end
