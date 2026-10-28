defmodule Revkit.Repo.Migrations.CreateCatalog do
  use Ecto.Migration

  def change do
    create table(:recipes) do
      add :name, :string, null: false
      add :description, :text
      add :steps, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:recipes, [:name])

    create table(:payloads) do
      add :name, :string, null: false
      add :description, :text
      add :template, :text, null: false
      add :recipe_id, references(:recipes, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:payloads, [:name])
    create index(:payloads, [:recipe_id])

    create table(:tags) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name])

    create table(:payloads_tags, primary_key: false) do
      add :payload_id, references(:payloads, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:payloads_tags, [:payload_id, :tag_id])
    create index(:payloads_tags, [:tag_id])
  end
end
