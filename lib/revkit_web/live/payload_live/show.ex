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
    payload = Catalog.get_payload!(id)

    {:noreply,
     assign(socket,
       payload: payload,
       variables: Template.variables(payload.template || ""),
       chain: chain_labels(payload.recipe)
     )}
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    {:ok, payload} = Catalog.toggle_payload_favorite(socket.assigns.payload)
    {:noreply, assign(socket, :payload, payload)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _payload} = Catalog.delete_payload(socket.assigns.payload)

    {:noreply,
     socket
     |> put_flash(:info, "Payload deleted")
     |> push_navigate(to: ~p"/payloads")}
  end

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
