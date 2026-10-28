defmodule RevkitWeb.TagLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  test "creates a tag", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tags")

    render_submit(view, "create", %{"tag" => %{"name" => "unix"}})

    assert [%{name: "unix"}] = Catalog.list_tags()
  end

  test "renames a tag", %{conn: conn} do
    {:ok, tag} = Catalog.create_tag(%{name: "unix"})

    {:ok, view, _html} = live(conn, ~p"/tags")

    render_submit(view, "rename", %{"tag_id" => to_string(tag.id), "tag" => %{"name" => "linux"}})

    assert Catalog.get_tag!(tag.id).name == "linux"
  end

  test "deletes a tag from payloads and recipes", %{conn: conn} do
    {:ok, tag} = Catalog.create_tag(%{name: "unix"})

    {:ok, _payload} =
      Catalog.create_payload_with_tags(%{name: "Payload", template: "id"}, ["unix"])

    {:ok, view, _html} = live(conn, ~p"/tags")

    render_click(view, "delete", %{"id" => to_string(tag.id)})

    assert Catalog.list_tags() == []
    assert Catalog.list_payloads() |> hd() |> Map.fetch!(:tags) == []
  end
end
