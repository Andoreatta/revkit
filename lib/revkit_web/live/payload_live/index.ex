defmodule RevkitWeb.PayloadLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_payloads(socket, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_payloads(socket, params["q"])}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign_payloads(socket, query)}
  end

  @impl true
  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    payload = Catalog.get_payload!(id)
    {:ok, _payload} = Catalog.toggle_payload_favorite(payload)
    {:noreply, assign_payloads(socket, socket.assigns.query)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    payload = Catalog.get_payload!(id)

    case Catalog.delete_payload(payload) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payload deleted")
         |> assign_payloads(socket.assigns.query)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete payload")}
    end
  end

  defp assign_payloads(socket, query) do
    assign(socket, payloads: Catalog.search_payloads(query), query: query || "")
  end
end
