defmodule Revkit.Catalog.Recipe do
  @moduledoc """
  A saved generation snapshot.

  A recipe stores the template, variable values, ordered transform steps,
  target metadata, notes, and curation fields so it can be reopened exactly.
  Public recipes have no owner; private editions carry an `owner_id` and point
  at their public source through `source_recipe_id`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Revkit.Catalog.{Payload, Tag}
  alias Revkit.Limits

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
    field :owner_id, :string

    belongs_to :payload, Payload
    belongs_to :source_recipe, __MODULE__, foreign_key: :source_recipe_id
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
    |> validate_length(:name, min: 1, max: Limits.max_name())
    |> validate_length(:description, max: Limits.max_description())
    |> validate_length(:template, max: Limits.max_template())
    |> validate_length(:notes, max: Limits.max_notes())
    |> validate_length(:target_os, max: Limits.max_target())
    |> validate_length(:target_shell, max: Limits.max_target())
    |> validate_variables()
    |> validate_steps()
    |> validate_tools()
    |> unique_constraint(:source_recipe_id,
      name: :recipes_owner_id_source_recipe_id_index
    )
  end

  defp normalize_variables(variables) when is_map(variables) do
    Map.new(variables, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_variables(variables), do: variables

  defp validate_variables(changeset) do
    case get_field(changeset, :variables) do
      variables when is_map(variables) ->
        cond do
          not valid_variables?(variables) ->
            add_error(changeset, :variables, "must map string names to string values")

          map_size(variables) > Limits.max_variables() ->
            add_error(changeset, :variables, "may contain at most %{count} variables",
              count: Limits.max_variables()
            )

          Enum.any?(variables, &invalid_variable?/1) ->
            add_error(
              changeset,
              :variables,
              "names must be at most %{name} characters and values at most %{value} characters",
              name: Limits.max_variable_name(),
              value: Limits.max_variable_value()
            )

          true ->
            changeset
        end

      _other ->
        add_error(changeset, :variables, "must be a map")
    end
  end

  defp valid_variables?(variables) do
    Enum.all?(variables, fn {key, value} -> is_binary(key) and is_binary(value) end)
  end

  defp invalid_variable?({key, value}) do
    byte_size(key) > Limits.max_variable_name() or byte_size(value) > Limits.max_variable_value()
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

    cond do
      not is_list(steps) or not Enum.all?(steps, &valid_step?/1) ->
        add_error(
          changeset,
          :steps,
          "must be a list of steps with a string key and an options map"
        )

      length(steps) > Limits.max_steps() ->
        add_error(changeset, :steps, "may contain at most %{count} steps",
          count: Limits.max_steps()
        )

      true ->
        changeset
    end
  end

  defp valid_step?(%{"key" => key, "options" => options})
       when is_binary(key) and key != "" and is_map(options),
       do: true

  defp valid_step?(_step), do: false

  defp validate_tools(changeset) do
    case get_field(changeset, :target_tools) do
      tools when is_list(tools) ->
        cond do
          length(tools) > Limits.max_tools() ->
            add_error(changeset, :target_tools, "may contain at most %{count} tools",
              count: Limits.max_tools()
            )

          Enum.any?(tools, &(not is_binary(&1) or byte_size(&1) > Limits.max_tool_length())) ->
            add_error(
              changeset,
              :target_tools,
              "tools must be at most %{count} characters",
              count: Limits.max_tool_length()
            )

          true ->
            changeset
        end

      _other ->
        add_error(changeset, :target_tools, "must be a list of tools")
    end
  end

  @doc false
  def tags_changeset(recipe, tags) do
    recipe
    |> change()
    |> put_assoc(:tags, tags)
  end
end
