defmodule Revkit.Catalog.Recipe do
  @moduledoc """
  A saved generation snapshot.

  A recipe stores the template, variable values, ordered transform steps,
  target metadata, notes, and curation fields so it can be reopened exactly.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Revkit.Catalog.{Payload, Tag}

  schema "recipes" do
    field :name, :string
    field :description, :string
    field :template, :string, default: ""
    field :variables, :map, default: %{}
    field :steps, {:array, :map}, default: []
    field :notes, :string
    field :favorite, :boolean, default: false
    field :target_os, :string
    field :target_shell, :string
    field :target_tools, {:array, :string}, default: []

    belongs_to :payload, Payload
    many_to_many :tags, Tag, join_through: "recipes_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [
      :name,
      :description,
      :template,
      :variables,
      :steps,
      :notes,
      :favorite,
      :target_os,
      :target_shell,
      :target_tools,
      :payload_id
    ])
    |> update_change(:variables, &normalize_variables/1)
    |> update_change(:steps, &normalize_steps/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:description, max: 500)
    |> validate_variables()
    |> validate_steps()
  end

  defp normalize_variables(variables) when is_map(variables) do
    Map.new(variables, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_variables(variables), do: variables

  defp validate_variables(changeset) do
    case get_field(changeset, :variables) do
      variables when is_map(variables) ->
        if valid_variables?(variables) do
          changeset
        else
          add_error(changeset, :variables, "must map string names to string values")
        end

      _other ->
        add_error(changeset, :variables, "must be a map")
    end
  end

  defp valid_variables?(variables) do
    Enum.all?(variables, fn {key, value} -> is_binary(key) and is_binary(value) end)
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

  @doc false
  def tags_changeset(recipe, tags) do
    recipe
    |> change()
    |> put_assoc(:tags, tags)
  end
end
