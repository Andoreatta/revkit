defmodule Revkit.Catalog.Payload do
  @moduledoc """
  A payload template.

  A payload with a `nil` owner is part of the public, read-only catalog. A
  payload with an `owner_id` is a private edition owned by one browser cookie;
  editions point at the public row they improve through `source_payload_id`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Revkit.Catalog.{Recipe, Tag}
  alias Revkit.Limits

  schema "payloads" do
    field :name, :string
    field :description, :string
    field :template, :string
    field :target_os, :string
    field :target_shell, :string
    field :target_tools, {:array, :string}, default: []
    field :notes, :string
    field :favorite, :boolean, default: false
    field :owner_id, :string

    belongs_to :recipe, Recipe
    belongs_to :source_payload, __MODULE__, foreign_key: :source_payload_id
    has_many :recipes, Recipe, foreign_key: :payload_id
    many_to_many :tags, Tag, join_through: "payloads_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payload, attrs) do
    payload
    |> cast(attrs, [
      :name,
      :description,
      :template,
      :recipe_id,
      :target_os,
      :target_shell,
      :target_tools,
      :notes,
      :favorite
    ])
    |> validate_required([:name, :template])
    |> validate_length(:name, min: 1, max: Limits.max_name())
    |> validate_length(:description, max: Limits.max_description())
    |> validate_length(:template, max: Limits.max_template())
    |> validate_length(:notes, max: Limits.max_notes())
    |> validate_length(:target_os, max: Limits.max_target())
    |> validate_length(:target_shell, max: Limits.max_target())
    |> validate_tools()
    |> unique_constraint(:source_payload_id,
      name: :payloads_owner_id_source_payload_id_index
    )
  end

  @doc false
  def tags_changeset(payload, tags) do
    payload
    |> change()
    |> put_assoc(:tags, tags)
  end

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
end
