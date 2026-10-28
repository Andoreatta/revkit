defmodule RevkitWeb.PayloadLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  test "lists payloads with their recipe and tags", %{conn: conn} do
    {:ok, recipe} = Catalog.create_recipe(%{name: "Encode"})

    {:ok, _payload} =
      Catalog.create_payload_with_tags(
        %{name: "Payload", template: "echo hi", recipe_id: recipe.id},
        ["unix"]
      )

    {:ok, _view, html} = live(conn, ~p"/payloads")

    assert html =~ "Payload"
    assert html =~ "Encode"
    assert html =~ "unix"
  end

  test "creates a payload with tags", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/payloads/new")

    view
    |> render_submit("save", %{
      "payload" => %{
        "name" => "New payload",
        "description" => "A test",
        "template" => "echo hi",
        "tags" => "unix, web"
      }
    })

    assert_redirect(view, ~p"/payloads")

    assert [payload] = Catalog.list_payloads()
    assert payload.name == "New payload"
    assert payload.description == "A test"
    assert payload.template == "echo hi"
    assert payload.tags |> Enum.map(& &1.name) |> Enum.sort() == ["unix", "web"]
  end

  test "shows validation errors and does not insert", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/payloads/new")

    html =
      render_submit(view, "save", %{"payload" => %{"name" => "", "template" => ""}})

    assert html =~ "can&#39;t be blank"
    assert Catalog.list_payloads() == []
  end

  test "updates a payload", %{conn: conn} do
    {:ok, payload} =
      Catalog.create_payload_with_tags(%{name: "Old", template: "id"}, ["unix"])

    {:ok, view, _html} = live(conn, ~p"/payloads/#{payload.id}/edit")

    view
    |> render_submit("save", %{
      "payload" => %{
        "name" => "Updated",
        "description" => "",
        "template" => "whoami",
        "tags" => "linux"
      }
    })

    assert_redirect(view, ~p"/payloads")

    updated = Catalog.get_payload!(payload.id)
    assert updated.name == "Updated"
    assert updated.template == "whoami"
    assert updated.tags |> Enum.map(& &1.name) == ["linux"]
  end

  test "deletes a payload", %{conn: conn} do
    {:ok, payload} = Catalog.create_payload(%{name: "Delete me", template: "id"})

    {:ok, view, html} = live(conn, ~p"/payloads")
    assert html =~ "Delete me"

    html = render_click(view, "delete", %{"id" => to_string(payload.id)})

    refute html =~ "Delete me"
    assert render(view) =~ "Payload deleted"
    assert Catalog.list_payloads() == []
  end

  test "links to the generator with the payload id", %{conn: conn} do
    {:ok, payload} = Catalog.create_payload(%{name: "Payload", template: "id"})

    {:ok, _view, html} = live(conn, ~p"/payloads")

    assert html =~ "/generate?payload_id=#{payload.id}"
  end
end
