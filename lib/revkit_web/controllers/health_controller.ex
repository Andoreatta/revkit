defmodule RevkitWeb.HealthController do
  @moduledoc """
  Lightweight liveness endpoint for container orchestration.
  """

  use RevkitWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(:ok, "ok")
  end
end
