defmodule RevkitWeb.TagLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias RevkitWeb.UI

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tags, Catalog.list_tags_with_usage(socket.assigns.owner_id))}
  end
end
