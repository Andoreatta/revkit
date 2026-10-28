defmodule Revkit.Catalog.Recipe do
  @moduledoc """
  A named, ordered chain of transforms.

  Steps are stored as JSON so a recipe can reference any transform module by
  key without a database migration. Each step has the shape
  `%{"key" => "base64_encode", "options" => %{}}`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Revkit.Catalog.Payload

  schema "recipes" do
    field :name, :string
    field :description, :string
    field :steps, {:array, :map}, default: []

    has_many :payloads, Payload

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:name, :description, :steps])
    |> update_change(:steps, &normalize_steps/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:description, max: 500)
    |> validate_steps()
  end

  defp normalize_steps(steps) when is_list(steps), do: Enum.map(steps, &normalize_step/1)
  defp normalize_steps(steps), do: steps

  defp normalize_step(%{"key" => key} = step) when is_binary(key) do
    %{"key" => key, "options" => normalize_options(Map.get(step, "options", %{}))}
  end

  defp normalize_step(%{key: key} = step) when is_atom(key) do
    %{"key" => Atom.to_string(key), "options" => normalize_options(Map.get(step, :options, %{}))}
  end

  defp normalize_step(step), do: step

  defp normalize_options(options) when is_map(options) do
    Map.new(options, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_options(options), do: options

  defp validate_steps(changeset) do
    steps = get_field(changeset, :steps) || []

    if is_list(steps) and Enum.all?(steps, &valid_step?/1) do
      changeset
    else
      add_error(changeset, :steps, "must be a list of steps with a string key and an options map")
    end
  end

  defp valid_step?(%{"key" => key, "options" => options})
       when is_binary(key) and key != "" and is_map(options),
       do: true

  defp valid_step?(_step), do: false
end
