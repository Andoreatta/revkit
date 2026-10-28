defmodule RevkitWeb.PayloadLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :payloads, Catalog.list_payloads())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    payload = Catalog.get_payload!(id)

    case Catalog.delete_payload(payload) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payload deleted")
         |> assign(:payloads, Catalog.list_payloads())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete payload")}
    end
  end
end
