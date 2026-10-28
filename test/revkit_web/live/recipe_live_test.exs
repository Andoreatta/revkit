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

  test "links to the generator with the recipe id", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(%{name: "Chain"})

    {:ok, _view, html} = live(conn, ~p"/recipes")

    assert html =~ "/generate?recipe_id=#{recipe.id}"
  end
end
