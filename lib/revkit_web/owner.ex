defmodule RevkitWeb.Owner do
  @moduledoc """
  Copies the cookie owner identifier from the session into LiveView assigns.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    {:cont, assign(socket, :owner_id, session["owner_id"])}
  end
end
