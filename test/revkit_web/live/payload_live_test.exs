defmodule RevkitWeb.PayloadLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  @owner "test-owner-00000001"

  defp tag!(name) do
    {:ok, tag} = Catalog.create_tag(%{name: name})
    tag
  end

  test "lists public payloads and the owner's editions", %{conn: conn} do
    {:ok, recipe} = Catalog.create_public_recipe(%{name: "Encode"})
    linux = tag!("linux")

    {:ok, _public} =
      Catalog.create_public_payload(
        %{name: "Public payload", template: "echo public", recipe_id: recipe.id},
        [linux.id]
      )

    {:ok, _owned} =
      Catalog.create_payload(
        @owner,
        %{name: "My payload", template: "echo mine"},
        [linux.id]
      )

    {:ok, _view, html} = live(conn, ~p"/payloads")

    assert html =~ "Public payload"
    assert html =~ "My payload"
    assert html =~ "Public catalog"
    assert html =~ "Your editions"
    assert html =~ "Encode"
    assert html =~ "linux"
    assert html =~ "Improve"
    assert html =~ "Discard"
  end

  test "does not list another owner's editions", %{conn: conn} do
    {:ok, _hidden} =
      Catalog.create_payload("another-owner", %{name: "Hidden edition", template: "id"})

    {:ok, _view, html} = live(conn, ~p"/payloads")

    refute html =~ "Hidden edition"
  end

  test "keeps a second cookie's edition hidden and the public row visible", %{} do
    {:ok, public} = Catalog.create_public_payload(%{name: "Shared public", template: "id"})
    {:ok, edition} = Catalog.create_payload(@owner, %{name: "First cookie", template: "id"})
    {:ok, _edition} = Catalog.update_payload(edition, @owner, %{name: "First cookie only"})

    other_conn = owner_conn("other-owner-00000002")
    {:ok, _view, html} = live(other_conn, ~p"/payloads")

    assert html =~ public.name
    refute html =~ "First cookie only"
    assert Catalog.get_payload(public.id, "other-owner-00000002").owner_id == nil
  end

  test "creates a private payload with tags", %{conn: conn} do
    unix = tag!("unix")
    web = tag!("web")

    {:ok, view, _html} = live(conn, ~p"/payloads/new")

    view
    |> render_submit("save", %{
      "payload" => %{
        "name" => "New payload",
        "description" => "A test",
        "template" => "echo hi",
        "tags" => [to_string(unix.id), to_string(web.id)]
      }
    })

    assert [payload] = Catalog.list_owned_payloads(@owner)
    assert_redirect(view, ~p"/payloads/#{payload.id}")

    assert payload.name == "New payload"
    assert payload.description == "A test"
    assert payload.template == "echo hi"
    assert payload.owner_id == @owner
    assert payload.tags |> Enum.map(& &1.name) |> Enum.sort() == ["unix", "web"]
  end

  test "shows the tag limit error and does not insert", %{conn: conn} do
    tags = Enum.map(1..4, fn index -> tag!("limit-#{index}") end)

    {:ok, view, _html} = live(conn, ~p"/payloads/new")

    html =
      render_submit(view, "save", %{
        "payload" => %{
          "name" => "Too many tags",
          "template" => "id",
          "tags" => Enum.map(tags, &to_string(&1.id))
        }
      })

    assert html =~ "may contain at most 3 tags"
    assert Catalog.list_owned_payloads(@owner) == []
  end

  test "shows validation errors and does not insert", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/payloads/new")

    html = render_submit(view, "save", %{"payload" => %{"name" => "", "template" => ""}})

    assert html =~ "can&#39;t be blank"
    assert Catalog.list_owned_payloads(@owner) == []
  end

  test "updates a private payload", %{conn: conn} do
    unix = tag!("unix")
    linux = tag!("linux")

    {:ok, payload} =
      Catalog.create_payload(@owner, %{name: "Old", template: "id"}, [unix.id])

    {:ok, view, _html} = live(conn, ~p"/payloads/#{payload.id}/edit")

    view
    |> render_submit("save", %{
      "payload" => %{
        "name" => "Updated",
        "description" => "",
        "template" => "whoami",
        "tags" => [to_string(linux.id)]
      }
    })

    assert_redirect(view, ~p"/payloads/#{payload.id}")

    updated = Catalog.get_payload!(payload.id, @owner)
    assert updated.name == "Updated"
    assert updated.template == "whoami"
    assert updated.tags |> Enum.map(& &1.name) == ["linux"]
  end

  test "improves a public payload into a private edition", %{conn: conn} do
    linux = tag!("linux")
    {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "id"}, [linux.id])

    {:ok, view, _html} = live(conn, ~p"/payloads")

    view |> element("#improve-payload-#{public.id}") |> render_click()

    assert [edition] = Catalog.list_owned_payloads(@owner)
    assert edition.source_payload_id == public.id
    assert edition.owner_id == @owner
    assert_redirect(view, ~p"/payloads/#{edition.id}/edit")

    assert Catalog.get_payload!(public.id, @owner).owner_id == nil
    assert Catalog.get_payload!(public.id, @owner).template == "id"
    assert Enum.map(Catalog.get_payload!(public.id, @owner).tags, & &1.name) == ["linux"]
  end

  test "does not show a delete action for public payloads", %{conn: conn} do
    {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "id"})

    {:ok, view, _html} = live(conn, ~p"/payloads")

    refute has_element?(view, "#discard-payload-#{public.id}")
    refute has_element?(view, "#delete-payload-#{public.id}")
  end

  test "discards only the owner's edition", %{conn: conn} do
    {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "id"})
    {:ok, edition} = Catalog.create_payload(@owner, %{name: "Mine", template: "id"})

    {:ok, view, _html} = live(conn, ~p"/payloads")

    view |> element("#discard-payload-#{edition.id}") |> render_click()

    assert render(view) =~ "Edition discarded"
    assert Catalog.list_owned_payloads(@owner) == []
    assert Catalog.get_payload!(public.id, @owner).id == public.id
  end

  test "searches only visible payloads", %{conn: conn} do
    {:ok, _public} = Catalog.create_public_payload(%{name: "Alpha shell", template: "bash -i"})
    {:ok, _owned} = Catalog.create_payload(@owner, %{name: "Beta", template: "nc"})

    {:ok, _hidden} =
      Catalog.create_payload("another-owner", %{name: "Beta hidden", template: "nc"})

    {:ok, view, _html} = live(conn, ~p"/payloads")

    html = render_change(view, "search", %{"q" => "alpha"})

    assert html =~ "Alpha shell"
    refute html =~ "Beta"
  end

  test "toggles a favorite on a private payload", %{conn: conn} do
    {:ok, payload} = Catalog.create_payload(@owner, %{name: "Favorite", template: "id"})

    {:ok, view, _html} = live(conn, ~p"/payloads")

    render_click(view, "toggle_favorite", %{"id" => to_string(payload.id)})

    assert Catalog.get_payload!(payload.id, @owner).favorite == true
  end

  test "creates a private payload with target metadata and notes", %{conn: conn} do
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

    payload = Catalog.list_owned_payloads(@owner) |> hd()
    assert payload.target_os == "linux"
    assert payload.target_shell == "bash"
    assert payload.target_tools == ["base64", "curl"]
    assert payload.notes == "Requires an interactive shell"
    assert payload.favorite == true
  end

  test "shows a public payload's context and template", %{conn: conn} do
    linux = tag!("linux")

    {:ok, payload} =
      Catalog.create_public_payload(
        %{
          name: "Shown payload",
          description: "Use with an outbound listener",
          template: "id {{HOST}}",
          notes: "Authorized testing only",
          target_shell: "bash"
        },
        [linux.id]
      )

    {:ok, _view, html} = live(conn, ~p"/payloads/#{payload.id}")

    assert html =~ "Shown payload"
    assert html =~ "Use with an outbound listener"
    assert html =~ "id {{HOST}}"
    assert html =~ "Authorized testing only"
    assert html =~ "linux"
    assert html =~ "Public catalog"
    assert html =~ "Improve for me"
  end

  test "shows a private edition with its source and editing controls", %{conn: conn} do
    {:ok, public} = Catalog.create_public_payload(%{name: "Public", template: "id"})
    {:ok, edition} = Catalog.improve_payload(public, @owner)

    {:ok, _view, html} = live(conn, ~p"/payloads/#{edition.id}")

    assert html =~ "Your edition"
    assert html =~ "Based on public"
    assert html =~ "Public"
    assert html =~ "Edit my edition"
    assert html =~ "Discard edition"
  end

  test "search filters by favorites and tag", %{conn: conn} do
    linux = tag!("linux")
    web = tag!("web")

    {:ok, _payload} =
      Catalog.create_payload(
        @owner,
        %{name: "Favorite Linux", template: "id", favorite: true},
        [linux.id]
      )

    {:ok, _payload} = Catalog.create_payload(@owner, %{name: "Other", template: "id"}, [web.id])

    {:ok, view, _html} = live(conn, ~p"/payloads")

    html = render_change(view, "search", %{"q" => "", "favorites" => "true"})
    assert html =~ "Favorite Linux"
    refute html =~ "Other"

    html = render_change(view, "search", %{"q" => "", "tag_id" => to_string(linux.id)})
    assert html =~ "Favorite Linux"
    refute html =~ "Other"
  end

  test "links to the generator with the payload id", %{conn: conn} do
    {:ok, payload} = Catalog.create_payload(@owner, %{name: "Payload", template: "id"})

    {:ok, _view, html} = live(conn, ~p"/payloads")

    assert html =~ "/generate?payload_id=#{payload.id}"
  end
end
