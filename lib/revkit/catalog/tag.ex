defmodule Revkit.Catalog.Tag do
  @moduledoc """
  A label used to group payloads.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Revkit.Catalog.Payload

  schema "tags" do
    field :name, :string

    many_to_many :payloads, Payload, join_through: "payloads_tags"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 40)
    |> unique_constraint(:name)
  end
end
