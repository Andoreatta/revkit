defmodule Revkit.Catalog.Payload do
  @moduledoc """
  A saved payload template, optionally tied to a recipe and tags.

  The payload body is stored as a template; rendering and transform chains are
  performed by `Revkit.Engine`, never by this schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Revkit.Catalog.{Recipe, Tag}

  schema "payloads" do
    field :name, :string
    field :description, :string
    field :template, :string

    belongs_to :recipe, Recipe
    many_to_many :tags, Tag, join_through: "payloads_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payload, attrs) do
    payload
    |> cast(attrs, [:name, :description, :template, :recipe_id])
    |> validate_required([:name, :template])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:description, max: 500)
  end

  @doc false
  def tags_changeset(payload, tags) do
    payload
    |> change()
    |> put_assoc(:tags, tags)
  end
end
