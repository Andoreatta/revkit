defmodule RevkitWeb.PayloadLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias RevkitWeb.UI

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tags, Catalog.list_tags())
     |> assign_payloads(nil, false, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     assign_payloads(
       socket,
       params["q"],
       params["favorites"] == "true",
       parse_id(params["tag"])
     )}
  end

  @impl true
  def handle_event("search", params, socket) do
    {:noreply,
     assign_payloads(
       socket,
       params["q"],
       params["favorites"] == "true",
       parse_id(params["tag_id"])
     )}
  end

  @impl true
  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    payload = Catalog.get_payload!(id)
    {:ok, _payload} = Catalog.toggle_payload_favorite(payload)
    {:noreply, refresh(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    payload = Catalog.get_payload!(id)

    case Catalog.delete_payload(payload) do
      {:ok, _payload} ->
        {:noreply, socket |> put_flash(:info, "Payload deleted") |> refresh()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete payload")}
    end
  end

  defp refresh(socket) do
    assign_payloads(
      socket,
      socket.assigns.query,
      socket.assigns.favorites_only,
      socket.assigns.tag_id
    )
  end

  defp assign_payloads(socket, query, favorites_only, tag_id) do
    payloads =
      Catalog.search_payloads(query, favorite: favorites_only, tag_id: tag_id)

    assign(socket,
      payloads: payloads,
      query: query || "",
      favorites_only: favorites_only,
      tag_id: tag_id
    )
  end

  defp parse_id(nil), do: nil
  defp parse_id(""), do: nil

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} -> value
      _other -> nil
    end
  end
end
