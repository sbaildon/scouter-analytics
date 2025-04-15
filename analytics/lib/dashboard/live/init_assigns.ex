defmodule Dashboard.InitAssigns do
  @moduledoc false
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    {:cont, authorize(socket, Map.get(session, "authorization"))}
  end

  defp authorize(socket, nil) do
    assign(socket, :caveats, [])
  end

  defp authorize(socket, scheme_and_parameters) do
    {scheme, parameters} = decode_authorization(scheme_and_parameters)

    apply_authorization_scheme(socket, scheme, parameters)
  end

  defp apply_authorization_scheme(socket, "Plain-Text", plain_text) do
    assign(socket, :caveats, decode_plain_text(plain_text))
  end

  defp apply_authorization_scheme(socket, "Bearer", token) do
    assign(socket, :caveats, decode_bearer_token(token))
  end

  defp decode_bearer_token(token) do
    token
    |> verify!()
    |> decode_plain_text()
  end

  defp decode_plain_text(plain_text) do
    plain_text
    |> String.trim()
    |> String.trim(";")
    |> String.split(";", trim: true)
  end

  defp decode_authorization(scheme_and_parameters) do
    scheme_and_parameters
    |> String.split(" ")
    |> List.to_tuple()
  end

  defp verify!(token) do
    case Phoenix.Token.verify(signing_secret(), signing_salt(), token, max_age: token_max_age()) do
      {:ok, data} -> data
      _ -> raise "unable to authorize"
    end
  end

  defp signing_secret, do: System.fetch_env!("IAM_SECRET")
  defp signing_salt, do: System.fetch_env!("IAM_SIGNING_SALT")
  defp token_max_age, do: 20
end
