defmodule Revkit.Repo.Migrations.AddOwnerEditions do
  use Ecto.Migration

  def change do
    alter table(:payloads) do
      add :owner_id, :string
      add :source_payload_id, references(:payloads, on_delete: :nilify_all)
    end

    create index(:payloads, [:owner_id])

    create unique_index(:payloads, [:owner_id, :source_payload_id])

    alter table(:recipes) do
      add :owner_id, :string
      add :source_recipe_id, references(:recipes, on_delete: :nilify_all)
    end

    create index(:recipes, [:owner_id])

    create unique_index(:recipes, [:owner_id, :source_recipe_id])
  end
end
