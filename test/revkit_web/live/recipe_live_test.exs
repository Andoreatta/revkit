defmodule RevkitWeb.RecipeLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  test "lists recipes with chain labels", %{conn: conn} do
    {:ok, _recipe} =
      Catalog.create_recipe(%{
        name: "Encode",
        steps: [
          %{"key" => "bash_wrapper", "options" => %{}},
          %{"key" => "base64_encode", "options" => %{}}
        ]
      })

    {:ok, _view, html} = live(conn, ~p"/recipes")

    assert html =~ "Encode"
    assert html =~ "Bash wrapper"
    assert html =~ "Base64 encode"
  end

  test "creates a recipe with ordered steps", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/recipes/new")

    refute has_element?(view, "#recipe-step-0")
    view |> element("#recipe-add-step") |> render_click()
    assert has_element?(view, "#recipe-step-0")

    view
    |> render_submit("save", %{
      "recipe" => %{
        "name" => "Chain",
        "description" => "",
        "steps" => %{"0" => %{"key" => "base64_encode"}}
      }
    })

    assert_redirect(view, ~p"/recipes")

    assert [recipe] = Catalog.list_recipes()
    assert recipe.name == "Chain"
    assert recipe.steps == [%{"key" => "base64_encode", "options" => %{}}]
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
    assert Catalog.list_recipes() == []
  end

  test "adds and removes steps", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
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
      Catalog.create_recipe(%{
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
      Catalog.create_recipe(%{
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

    assert_redirect(view, ~p"/recipes")

    updated = Catalog.get_recipe!(recipe.id)
    assert updated.name == "Renamed"

    assert updated.steps == [
             %{"key" => "base64_encode", "options" => %{"padding" => false}}
           ]
  end

  test "deletes a recipe", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(%{name: "Delete me"})

    {:ok, view, html} = live(conn, ~p"/recipes")
    assert html =~ "Delete me"

    html = render_click(view, "delete", %{"id" => to_string(recipe.id)})

    refute html =~ "Delete me"
    assert render(view) =~ "Recipe deleted"
    assert Catalog.list_recipes() == []
  end

  test "shows a saved snapshot with variables and context", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
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
  end

  test "searches recipes", %{conn: conn} do
    {:ok, _recipe} = Catalog.create_recipe(%{name: "Linux shell", template: "bash -i"})
    {:ok, _recipe} = Catalog.create_recipe(%{name: "Other", template: "cmd.exe"})

    {:ok, view, _html} = live(conn, ~p"/recipes")

    html = render_change(view, "search", %{"q" => "linux"})

    assert html =~ "Linux shell"
    refute html =~ "Other"
  end

  test "forks a recipe with its snapshot and tags", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Original",
        template: "id {{HOST}}",
        variables: %{"HOST" => "10.0.0.1"},
        steps: [%{"key" => "base64_encode", "options" => %{}}],
        notes: "note",
        target_shell: "bash"
      })

    {:ok, _recipe} = Catalog.put_recipe_tag_names(recipe, ["unix"])

    {:ok, view, _html} = live(conn, ~p"/recipes")

    render_click(view, "fork", %{"id" => to_string(recipe.id)})

    assert render(view) =~ "Recipe forked"
    assert length(Catalog.list_recipes()) == 2

    forked = Catalog.list_recipes() |> Enum.find(&(&1.name == "Original (copy)"))
    assert forked.template == "id {{HOST}}"
    assert forked.variables == %{"HOST" => "10.0.0.1"}
    assert forked.steps == [%{"key" => "base64_encode", "options" => %{}}]
    assert forked.notes == "note"
    assert forked.target_shell == "bash"
    assert Enum.map(forked.tags, & &1.name) == ["unix"]
  end

  test "toggles a recipe favorite", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(%{name: "Favorite"})

    {:ok, view, _html} = live(conn, ~p"/recipes")

    render_click(view, "toggle_favorite", %{"id" => to_string(recipe.id)})

    assert Catalog.get_recipe!(recipe.id).favorite == true
  end

  test "recipe form stores template, notes, and tags", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/recipes/new")

    view |> element("#recipe-add-step") |> render_click()

    render_submit(view, "save", %{
      "recipe" => %{
        "name" => "Snapshot",
        "description" => "",
        "template" => "id {{HOST}}",
        "notes" => "Keep this",
        "tags" => "unix",
        "target_os" => "linux",
        "target_shell" => "bash",
        "target_tools_text" => "base64, bash",
        "steps" => %{"0" => %{"key" => "base64_encode"}}
      }
    })

    assert_redirect(view, ~p"/recipes")

    recipe = Catalog.list_recipes() |> hd()
    assert recipe.template == "id {{HOST}}"
    assert recipe.notes == "Keep this"
    assert recipe.steps == [%{"key" => "base64_encode", "options" => %{}}]
    assert recipe.target_os == "linux"
    assert recipe.target_shell == "bash"
    assert recipe.target_tools == ["base64", "bash"]
    assert Enum.map(recipe.tags, & &1.name) == ["unix"]
  end

  test "links to the generator with the recipe id", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(%{name: "Chain"})

    {:ok, _view, html} = live(conn, ~p"/recipes")

    assert html =~ "/generate?recipe_id=#{recipe.id}"
  end
end
