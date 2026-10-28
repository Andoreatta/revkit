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

  test "searches payloads", %{conn: conn} do
    {:ok, _payload} = Catalog.create_payload(%{name: "Alpha shell", template: "bash -i"})
    {:ok, _payload} = Catalog.create_payload(%{name: "Beta", template: "nc"})

    {:ok, view, _html} = live(conn, ~p"/payloads")

    html = render_change(view, "search", %{"q" => "alpha"})

    assert html =~ "Alpha shell"
    refute html =~ "Beta"
  end

  test "toggles a payload favorite", %{conn: conn} do
    {:ok, payload} = Catalog.create_payload(%{name: "Favorite", template: "id"})

    {:ok, view, _html} = live(conn, ~p"/payloads")

    render_click(view, "toggle_favorite", %{"id" => to_string(payload.id)})

    assert Catalog.get_payload!(payload.id).favorite == true
  end

  test "creates a payload with target metadata and notes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/payloads/new")

    view
    |> render_submit("save", %{
      "payload" => %{
        "name" => "Targeted",
        "template" => "id",
        "target_os" => "linux",
        "target_shell" => "bash",
        "target_tools_text" => "base64, curl",
        "notes" => "Requires an interactive shell",
        "favorite" => "true"
      }
    })

    assert_redirect(view, ~p"/payloads")

    payload = Catalog.list_payloads() |> hd()
    assert payload.target_os == "linux"
    assert payload.target_shell == "bash"
    assert payload.target_tools == ["base64", "curl"]
    assert payload.notes == "Requires an interactive shell"
    assert payload.favorite == true
  end

  test "shows payload context and template", %{conn: conn} do
    {:ok, payload} =
      Catalog.create_payload_with_tags(
        %{
          name: "Shown payload",
          description: "Use with an outbound listener",
          template: "id {{HOST}}",
          notes: "Authorized testing only",
          target_shell: "bash"
        },
        ["linux"]
      )

    {:ok, _view, html} = live(conn, ~p"/payloads/#{payload.id}")

    assert html =~ "Shown payload"
    assert html =~ "Use with an outbound listener"
    assert html =~ "id {{HOST}}"
    assert html =~ "Authorized testing only"
    assert html =~ "linux"
  end

  test "search filters by favorites and tag", %{conn: conn} do
    {:ok, _payload} =
      Catalog.create_payload_with_tags(
        %{name: "Favorite Linux", template: "id", favorite: true},
        ["linux"]
      )

    {:ok, _payload} = Catalog.create_payload_with_tags(%{name: "Other", template: "id"}, ["web"])

    {:ok, view, _html} = live(conn, ~p"/payloads")
    [linux] = Enum.filter(Catalog.list_tags(), &(&1.name == "linux"))

    html = render_change(view, "search", %{"q" => "", "favorites" => "true"})
    assert html =~ "Favorite Linux"
    refute html =~ "Other"

    html = render_change(view, "search", %{"q" => "", "tag_id" => to_string(linux.id)})
    assert html =~ "Favorite Linux"
    refute html =~ "Other"
  end

  test "links to the generator with the payload id", %{conn: conn} do
    {:ok, payload} = Catalog.create_payload(%{name: "Payload", template: "id"})

    {:ok, _view, html} = live(conn, ~p"/payloads")

    assert html =~ "/generate?payload_id=#{payload.id}"
  end
end
