defmodule Revkit.Repo.Migrations.AddRecipeSnapshotAndCuration do
  use Ecto.Migration

  def change do
    alter table(:payloads) do
      add :target_os, :string
      add :target_shell, :string
      add :target_tools, {:array, :string}, null: false, default: []
      add :notes, :text
      add :favorite, :boolean, null: false, default: false
    end

    alter table(:recipes) do
      add :template, :text, null: false, default: ""
      add :variables, :map, null: false, default: %{}
      add :notes, :text
      add :favorite, :boolean, null: false, default: false
      add :target_os, :string
      add :target_shell, :string
      add :target_tools, {:array, :string}, null: false, default: []
      add :payload_id, references(:payloads, on_delete: :nilify_all)
    end

    create index(:recipes, [:payload_id])

    create table(:recipes_tags, primary_key: false) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:recipes_tags, [:recipe_id, :tag_id])
    create index(:recipes_tags, [:tag_id])
  end
end
