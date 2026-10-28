defmodule RevkitWeb.TagLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  test "shows the fixed vocabulary with usage counts", %{conn: conn} do
    {:ok, linux} = Catalog.create_tag(%{name: "linux"})

    {:ok, _payload} =
      Catalog.create_public_payload(%{name: "Payload", template: "id"}, [linux.id])

    {:ok, _recipe} = Catalog.create_public_recipe(%{name: "Recipe"}, [linux.id])

    {:ok, view, html} = live(conn, ~p"/tags")

    assert html =~ "linux"
    assert html =~ "1 payloads"
    assert html =~ "1 recipes"
    assert html =~ "read-only"
    refute has_element?(view, "#new-tag-form")
    refute has_element?(view, "#rename-tag-#{linux.id}")
  end

  test "shows an empty state when the vocabulary is missing", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/tags")

    assert html =~ "No tags yet"
  end
end
