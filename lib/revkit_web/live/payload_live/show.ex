defmodule RevkitWeb.PayloadLive.Show do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Engine.Template
  alias Revkit.Engine.Transforms
  alias RevkitWeb.UI

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    payload = Catalog.get_payload!(id, socket.assigns.owner_id)

    {:noreply,
     assign(socket,
       payload: payload,
       owned: owned?(payload, socket.assigns.owner_id),
       variables: Template.variables(payload.template || ""),
       chain: chain_labels(payload.recipe)
     )}
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    case Catalog.toggle_payload_favorite(socket.assigns.payload, socket.assigns.owner_id) do
      {:ok, payload} ->
        {:noreply, assign(socket, :payload, payload)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Public entries cannot be favorited")}
    end
  end

  @impl true
  def handle_event("improve", _params, socket) do
    case Catalog.improve_payload(socket.assigns.payload, socket.assigns.owner_id) do
      {:ok, edition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your edition is ready")
         |> push_navigate(to: ~p"/payloads/#{edition.id}")}

      {:error, :limit_reached} ->
        {:noreply, put_flash(socket, :error, "Edition limit reached")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not improve payload")}
    end
  end

  @impl true
  def handle_event("discard", _params, socket) do
    case Catalog.discard_payload(socket.assigns.payload, socket.assigns.owner_id) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Edition discarded")
         |> push_navigate(to: ~p"/payloads")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not discard edition")}
    end
  end

  defp owned?(%{owner_id: owner_id}, owner_id) when is_binary(owner_id), do: true
  defp owned?(_payload, _owner_id), do: false

  defp chain_labels(nil), do: []

  defp chain_labels(recipe) do
    Enum.map(recipe.steps, fn step ->
      key = step["key"] || step[:key]

      case Transforms.fetch(key) do
        nil -> %{label: to_string(key), known: false}
        module -> %{label: module.label(), known: true}
      end
    end)
  end
end
