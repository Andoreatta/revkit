defmodule RevkitWeb.GenerateLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  test "renders the generator with recipes", %{conn: conn} do
    {:ok, _recipe} =
      Catalog.create_recipe(%{
        name: "Encode",
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, _view, html} = live(conn, ~p"/generate")

    assert html =~ "Generate payload"
    assert html =~ "Encode"
    assert html =~ "No recipe (identity)"
  end

  test "previews a recipe on phx-change without writing to the database", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Encode",
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, view, _html} = live(conn, ~p"/generate")
    payloads_before = Catalog.list_payloads()

    html =
      render_change(view, "preview", %{
        "template" => "hello",
        "recipe_id" => to_string(recipe.id)
      })

    assert html =~ "aGVsbG8="
    assert Catalog.list_payloads() == payloads_before
  end

  test "applies the recipe in order", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Wrap then encode",
        steps: [
          %{"key" => "bash_wrapper", "options" => %{}},
          %{"key" => "base64_encode", "options" => %{}}
        ]
      })

    {:ok, view, _html} = live(conn, ~p"/generate")

    html =
      render_change(view, "preview", %{
        "template" => "hello",
        "recipe_id" => to_string(recipe.id)
      })

    assert html =~ "YmFzaCAtYyAnaGVsbG8n"
  end

  test "returns the template unchanged without a recipe", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/generate")

    html = render_change(view, "preview", %{"template" => "echo hi"})

    assert html =~ "echo hi"
  end

  test "prefills the template and recipe from a saved payload", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Encode",
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, payload} =
      Catalog.create_payload(%{
        name: "Saved",
        template: "hello",
        recipe_id: recipe.id
      })

    {:ok, _view, html} = live(conn, ~p"/generate?payload_id=#{payload.id}")

    assert html =~ "aGVsbG8="
    assert html =~ "Saved"
  end

  test "shows the recipe requirements and pitfalls", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Wrapped",
        steps: [%{"key" => "bash_wrapper", "options" => %{}}]
      })

    {:ok, view, _html} = live(conn, ~p"/generate")

    html =
      render_change(view, "preview", %{
        "template" => "id",
        "recipe_id" => to_string(recipe.id)
      })

    assert html =~ "Target requires"
    assert html =~ "bash"
    assert html =~ "Warnings"
    assert html =~ "The payload runs with the privileges"
  end

  test "renders the copy hook with the current preview value", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Encode",
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, view, _html} = live(conn, ~p"/generate")

    html =
      render_change(view, "preview", %{
        "template" => "hello",
        "recipe_id" => to_string(recipe.id)
      })

    assert html =~ ~s(phx-hook="RevkitWeb.GenerateLive.CopyToClipboard")
    assert html =~ ~s(id="generate-copy")
    assert html =~ ~s(data-copy-value="aGVsbG8=")

    html =
      render_change(view, "preview", %{
        "template" => "world",
        "recipe_id" => to_string(recipe.id)
      })

    assert html =~ ~s(data-copy-value="d29ybGQ=")
  end

  test "hides the copy button when the preview fails", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Broken",
        steps: [%{"key" => "does_not_exist", "options" => %{}}]
      })

    {:ok, view, _html} = live(conn, ~p"/generate")

    render_change(view, "preview", %{
      "template" => "hello",
      "recipe_id" => to_string(recipe.id)
    })

    refute has_element?(view, "#generate-copy")
  end

  test "shows an error for a recipe with an unknown transform", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Broken",
        steps: [%{"key" => "does_not_exist", "options" => %{}}]
      })

    {:ok, view, _html} = live(conn, ~p"/generate")

    html =
      render_change(view, "preview", %{
        "template" => "hello",
        "recipe_id" => to_string(recipe.id)
      })

    assert html =~ "Unknown transform: does_not_exist"
  end
end
