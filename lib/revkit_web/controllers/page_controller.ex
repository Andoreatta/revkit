defmodule RevkitWeb.PageController do
  use RevkitWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
