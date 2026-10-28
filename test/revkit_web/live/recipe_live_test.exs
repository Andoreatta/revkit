defmodule RevkitWeb.RecipeLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  @owner "test-owner-00000001"

  defp tag!(name) do
    {:ok, tag} = Catalog.create_tag(%{name: name})
    tag
  end

  test "lists public recipes and the owner's editions with chain labels", %{conn: conn} do
    {:ok, _public} =
      Catalog.create_public_recipe(%{
        name: "Public encode",
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, _owned} =
      Catalog.create_recipe(@owner, %{
        name: "My encode",
        steps: [%{"key" => "bash_wrapper", "options" => %{}}]
      })

    {:ok, _view, html} = live(conn, ~p"/recipes")

    assert html =~ "Public encode"
    assert html =~ "My encode"
    assert html =~ "Public catalog"
    assert html =~ "Your editions"
    assert html =~ "Bash wrapper"
    assert html =~ "Base64 encode"
    assert html =~ "Improve"
    assert html =~ "Discard"
  end

  test "does not list another owner's recipes", %{conn: conn} do
    {:ok, _hidden} = Catalog.create_recipe("another-owner", %{name: "Hidden recipe"})

    {:ok, _view, html} = live(conn, ~p"/recipes")

    refute html =~ "Hidden recipe"
  end

  test "creates a private recipe with ordered steps", %{conn: conn} do
    unix = tag!("unix")

    {:ok, view, _html} = live(conn, ~p"/recipes/new")

    refute has_element?(view, "#recipe-step-0")
    view |> element("#recipe-add-step") |> render_click()
    assert has_element?(view, "#recipe-step-0")

    view
    |> render_submit("save", %{
      "recipe" => %{
        "name" => "Chain",
        "description" => "",
        "tags" => [to_string(unix.id)],
        "steps" => %{"0" => %{"key" => "base64_encode"}}
      }
    })

    assert [recipe] = Catalog.list_owned_recipes(@owner)
    assert_redirect(view, ~p"/recipes/#{recipe.id}")

    assert recipe.name == "Chain"
    assert recipe.owner_id == @owner
    assert recipe.steps == [%{"key" => "base64_encode", "options" => %{}}]
    assert Enum.map(recipe.tags, & &1.name) == ["unix"]
  end

  test "shows validation errors for an empty transform", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/recipes/new")

    view |> element("#recipe-add-step") |> render_click()

    html =
      render_submit(view, "save", %{
        "recipe" => %{
          "name" => "Broken",
          "steps" => %{"0" => %{"key" => ""}}
        }
      })

    assert html =~ "must be a list of steps"
    assert Catalog.list_owned_recipes(@owner) == []
  end

  test "adds and removes steps", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(@owner, %{
        name: "Chain",
        steps: [
          %{"key" => "base64_encode", "options" => %{}},
          %{"key" => "bash_wrapper", "options" => %{}}
        ]
      })

    {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}/edit")

    assert has_element?(view, "#recipe-step-1")

    view |> element("#recipe-step-0 button[aria-label='Remove step']") |> render_click()

    refute has_element?(view, "#recipe-step-1")
    assert has_element?(view, "#recipe-step-0")
  end

  test "moves steps up and down", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(@owner, %{
        name: "Chain",
        steps: [
          %{"key" => "base64_encode", "options" => %{}},
          %{"key" => "bash_wrapper", "options" => %{}}
        ]
      })

    {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}/edit")

    first_select = view |> element("#recipe-step-0 select") |> render()
    assert first_select =~ ~s(value="base64_encode" selected)

    view |> element("#recipe-step-0 button[aria-label='Move down']") |> render_click()

    first_select = view |> element("#recipe-step-0 select") |> render()
    assert first_select =~ ~s(value="bash_wrapper" selected)
  end

  test "preserves step options when editing", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(@owner, %{
        name: "Chain",
        steps: [%{"key" => "base64_encode", "options" => %{"padding" => false}}]
      })

    {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe.id}/edit")

    view
    |> render_submit("save", %{
      "recipe" => %{
        "name" => "Renamed",
        "description" => "",
        "steps" => %{"0" => %{"key" => "base64_encode"}}
      }
    })

    assert_redirect(view, ~p"/recipes/#{recipe.id}")

    updated = Catalog.get_recipe!(recipe.id, @owner)
    assert updated.name == "Renamed"

    assert updated.steps == [
             %{"key" => "base64_encode", "options" => %{"padding" => false}}
           ]
  end

  test "improves a public recipe into a private edition", %{conn: conn} do
    {:ok, public} = Catalog.create_public_recipe(%{name: "Public recipe", template: "id"})

    {:ok, view, _html} = live(conn, ~p"/recipes")

    view |> element("#improve-recipe-#{public.id}") |> render_click()

    assert [edition] = Catalog.list_owned_recipes(@owner)
    assert edition.source_recipe_id == public.id
    assert edition.owner_id == @owner
    assert_redirect(view, ~p"/recipes/#{edition.id}/edit")

    assert Catalog.get_recipe!(public.id, @owner).owner_id == nil
    assert Catalog.get_recipe!(public.id, @owner).template == "id"
  end

  test "discards only the owner's edition", %{conn: conn} do
    {:ok, public} = Catalog.create_public_recipe(%{name: "Public", template: "id"})
    {:ok, edition} = Catalog.create_recipe(@owner, %{name: "Mine", template: "id"})

    {:ok, view, _html} = live(conn, ~p"/recipes")

    view |> element("#discard-recipe-#{edition.id}") |> render_click()

    assert render(view) =~ "Edition discarded"
    assert Catalog.list_owned_recipes(@owner) == []
    assert Catalog.get_recipe!(public.id, @owner).id == public.id
  end

  test "shows a saved snapshot with variables and context", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(@owner, %{
        name: "Shown recipe",
        template: "id {{HOST}}",
        variables: %{"HOST" => "10.0.0.1"},
        steps: [%{"key" => "base64_encode", "options" => %{}}],
        notes: "Authorized testing only",
        target_shell: "bash"
      })

    {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe.id}")

    assert html =~ "Shown recipe"
    assert html =~ "id {{HOST}}"
    assert html =~ "10.0.0.1"
    assert html =~ "Authorized testing only"
    assert html =~ "Base64 encode"
    assert html =~ "Your edition"
    assert html =~ "Discard edition"
  end

  test "searches only visible recipes", %{conn: conn} do
    {:ok, _public} = Catalog.create_public_recipe(%{name: "Linux shell", template: "bash -i"})
    {:ok, _owned} = Catalog.create_recipe(@owner, %{name: "Other", template: "cmd.exe"})

    {:ok, _hidden} =
      Catalog.create_recipe("another-owner", %{name: "Other hidden", template: "cmd.exe"})

    {:ok, view, _html} = live(conn, ~p"/recipes")

    html = render_change(view, "search", %{"q" => "linux"})

    assert html =~ "Linux shell"
    refute html =~ "Other"
  end

  test "toggles a favorite on a private recipe", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(@owner, %{name: "Favorite"})

    {:ok, view, _html} = live(conn, ~p"/recipes")

    render_click(view, "toggle_favorite", %{"id" => to_string(recipe.id)})

    assert Catalog.get_recipe!(recipe.id, @owner).favorite == true
  end

  test "recipe form stores template, notes, and tags", %{conn: conn} do
    unix = tag!("unix")

    {:ok, view, _html} = live(conn, ~p"/recipes/new")

    view |> element("#recipe-add-step") |> render_click()

    render_submit(view, "save", %{
      "recipe" => %{
        "name" => "Snapshot",
        "description" => "",
        "template" => "id {{HOST}}",
        "notes" => "Keep this",
        "tags" => [to_string(unix.id)],
        "target_os" => "linux",
        "target_shell" => "bash",
        "target_tools_text" => "base64, bash",
        "steps" => %{"0" => %{"key" => "base64_encode"}}
      }
    })

    recipe = Catalog.list_owned_recipes(@owner) |> hd()
    assert recipe.template == "id {{HOST}}"
    assert recipe.notes == "Keep this"
    assert recipe.steps == [%{"key" => "base64_encode", "options" => %{}}]
    assert recipe.target_os == "linux"
    assert recipe.target_shell == "bash"
    assert recipe.target_tools == ["base64", "bash"]
    assert Enum.map(recipe.tags, & &1.name) == ["unix"]
  end

  test "links to the generator with the recipe id", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(@owner, %{name: "Chain"})

    {:ok, _view, html} = live(conn, ~p"/recipes")

    assert html =~ "/generate?recipe_id=#{recipe.id}"
  end
end
