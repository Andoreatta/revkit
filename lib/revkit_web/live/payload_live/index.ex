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
    payload = Catalog.get_owned_payload!(id, socket.assigns.owner_id)

    case Catalog.toggle_payload_favorite(payload, socket.assigns.owner_id) do
      {:ok, _payload} -> {:noreply, refresh(socket)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Could not favorite payload")}
    end
  end

  @impl true
  def handle_event("improve", %{"id" => id}, socket) do
    payload = Catalog.get_payload!(id, socket.assigns.owner_id)

    case Catalog.improve_payload(payload, socket.assigns.owner_id) do
      {:ok, edition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your edition is ready")
         |> push_navigate(to: ~p"/payloads/#{edition.id}/edit")}

      {:error, :limit_reached} ->
        {:noreply, put_flash(socket, :error, "Edition limit reached")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not improve payload")}
    end
  end

  @impl true
  def handle_event("discard", %{"id" => id}, socket) do
    payload = Catalog.get_owned_payload!(id, socket.assigns.owner_id)

    case Catalog.discard_payload(payload, socket.assigns.owner_id) do
      {:ok, _payload} ->
        {:noreply, socket |> put_flash(:info, "Edition discarded") |> refresh()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not discard edition")}
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
      Catalog.search_payloads(socket.assigns.owner_id, query,
        favorite: favorites_only,
        tag_id: tag_id
      )

    assign(socket,
      payloads: payloads,
      public_payloads: Enum.filter(payloads, &is_nil(&1.owner_id)),
      owned_payloads: Enum.reject(payloads, &is_nil(&1.owner_id)),
      quota: Catalog.private_payload_count(socket.assigns.owner_id),
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
