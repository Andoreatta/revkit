defmodule RevkitWeb.HealthControllerTest do
  use RevkitWeb.ConnCase

  test "GET /health returns a plain-text liveness response", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert text_response(conn, 200) == "ok"
  end
end
