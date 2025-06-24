defmodule Scouter.Cldr do
  @moduledoc false
  use Cldr,
    locales: [:en],
    gettext: Scouter.Gettext,
    otp_app: :scouter,
    providers: [Cldr.Territory, Cldr.Number]
end
