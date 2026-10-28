defmodule RevkitWeb.GenerateLiveTest do
  use RevkitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Revkit.Catalog

  test "renders the generator at the root route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Generate payload"
  end

  test "renders the generator with recipes", %{conn: conn} do
    {:ok, _recipe} =
      Catalog.create_recipe(%{
        name: "Encode",
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, _view, html} = live(conn, ~p"/generate")

    assert html =~ "Generate payload"
    assert html =~ "Encode"
    assert html =~ "No recipe"
  end

  test "serves the CSP nonce for the inline theme script", %{conn: conn} do
    conn = get(conn, ~p"/generate")

    assert [policy] = get_resp_header(conn, "content-security-policy")
    assert [_, nonce] = Regex.run(~r/script-src 'self' 'nonce-([^']+)'/, policy)
    assert html_response(conn, 200) =~ ~s(nonce="#{nonce}")
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

  test "renders variables and reports missing values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/generate")

    html =
      render_change(view, "preview", %{
        "template" => "nc {{LHOST}} {{LPORT}}",
        "variables" => %{"LHOST" => "10.0.0.1", "LPORT" => "4444"}
      })

    assert html =~ "nc 10.0.0.1 4444"
    assert html =~ "LHOST"

    html =
      render_change(view, "preview", %{
        "template" => "nc {{LHOST}} {{LPORT}}",
        "variables" => %{"LHOST" => "10.0.0.1", "LPORT" => ""}
      })

    assert html =~ "Missing variables: LPORT"
  end

  test "warns about incompatible target metadata before the copy button", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Bash",
        steps: [%{"key" => "bash_wrapper", "options" => %{}}]
      })

    {:ok, payload} =
      Catalog.create_payload(%{
        name: "Linux sh",
        template: "id",
        target_os: "linux",
        target_shell: "sh",
        recipe_id: recipe.id
      })

    {:ok, _view, html} = live(conn, ~p"/generate?payload_id=#{payload.id}")

    {warning_position, _} = :binary.match(html, "Compatibility warnings")
    {copy_position, _} = :binary.match(html, ~s(id="generate-copy"))

    assert warning_position < copy_position
    assert html =~ "does not declare it"
  end

  test "adds a transform and previews the edited chain", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/generate")

    view |> element("#generate-add-step") |> render_click()
    assert has_element?(view, "#generate-step-0")

    html =
      render_change(view, "preview", %{
        "template" => "hello",
        "steps" => %{"0" => %{"key" => "base64_encode"}}
      })

    assert html =~ "aGVsbG8="
  end

  test "reopens a saved recipe snapshot", %{conn: conn} do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Snapshot",
        template: "id {{HOST}}",
        variables: %{"HOST" => "10.0.0.1"},
        steps: [%{"key" => "base64_encode", "options" => %{}}],
        notes: "note"
      })

    {:ok, _view, html} = live(conn, ~p"/generate?recipe_id=#{recipe.id}")

    assert html =~ "aWQgMTAuMC4wLjE="
    assert html =~ "Snapshot"
  end

  test "payload selection keeps the payload template over its default recipe snapshot", %{
    conn: conn
  } do
    {:ok, recipe} =
      Catalog.create_recipe(%{
        name: "Different snapshot",
        template: "recipe {{HOST}}",
        variables: %{"HOST" => "recipe"},
        steps: [%{"key" => "base64_encode", "options" => %{}}]
      })

    {:ok, payload} =
      Catalog.create_payload(%{
        name: "Payload",
        template: "payload {{HOST}}",
        recipe_id: recipe.id
      })

    {:ok, _view, html} = live(conn, ~p"/generate?payload_id=#{payload.id}")

    assert html =~ "payload {{HOST}}"
    refute html =~ "recipe {{HOST}}"
  end

  test "saves the full generation snapshot as a recipe", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/generate")

    render_change(view, "preview", %{
      "template" => "id {{HOST}}",
      "variables" => %{"HOST" => "10.0.0.1"}
    })

    view |> element("#generate-add-step") |> render_click()

    render_change(view, "preview", %{
      "template" => "id {{HOST}}",
      "variables" => %{"HOST" => "10.0.0.1"},
      "steps" => %{"0" => %{"key" => "base64_encode"}}
    })

    render_submit(view, "save_recipe", %{
      "recipe" => %{"name" => "Saved generation", "notes" => "note", "tags" => "unix"}
    })

    assert_redirect(view, ~p"/recipes")

    assert [recipe] = Catalog.list_recipes()
    assert recipe.template == "id {{HOST}}"
    assert recipe.variables == %{"HOST" => "10.0.0.1"}
    assert recipe.steps == [%{"key" => "base64_encode", "options" => %{}}]
    assert recipe.notes == "note"
    assert recipe.tags |> Enum.map(& &1.name) == ["unix"]
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
