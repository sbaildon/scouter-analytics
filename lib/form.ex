defmodule Form do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Phoenix.Component, only: [to_form: 1, to_form: 2]

      alias Phoenix.HTML

      @primary_key false

      def new, do: new(struct(__MODULE__), %{}, [])
      def new(form) when is_struct(form), do: new(form, %{}, [])
      def new(form, opts) when is_struct(form), do: new(form, %{}, opts)
      def new(params) when is_map(params), do: new(struct(__MODULE__), params, [])
      def new(params, opts) when is_map(params), do: new(struct(__MODULE__), params, opts)
      def new(form, params, opts), do: form |> changeset(params) |> to_form(opts)

      @spec validate(struct :: __MODULE__, params :: map()) ::
              {:ok, form :: __MODULE__} | {:error, phx_form :: HTML.Form.t()}
      def validate(struct, params) do
        struct
        |> changeset(params)
        |> apply_action(:validate)
        |> case do
          {:ok, form} -> {:ok, form}
          {:error, changeset} -> {:error, to_form(changeset)}
        end
      end

      @spec validate(params :: map()) ::
              {:ok, form :: __MODULE__} | {:error, phx_form :: HTML.Form.t()}
      def validate(params) do
        __MODULE__
        |> struct()
        |> validate(params)
      end
    end
  end
end
