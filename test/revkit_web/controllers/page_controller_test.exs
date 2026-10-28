defmodule RevkitWeb.PageControllerTest do
  use RevkitWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Generate payload"
  end

  test "sets a nonce-based Content-Security-Policy", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert [policy] = get_resp_header(conn, "content-security-policy")
    assert policy =~ "default-src 'self'"
    assert policy =~ "frame-ancestors 'none'"

    assert [_, nonce] = Regex.run(~r/script-src 'self' 'nonce-([^']+)'/, policy)
    assert html_response(conn, 200) =~ ~s(nonce="#{nonce}")
  end
end
