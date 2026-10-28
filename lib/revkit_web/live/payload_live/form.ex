defmodule RevkitWeb.PayloadLive.Form do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.Payload

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :recipes, Catalog.list_recipes())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    payload = %Payload{}

    socket
    |> assign(:payload, payload)
    |> assign(:tag_names, "")
    |> assign(:form, to_form(Payload.changeset(payload, %{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    payload = Catalog.get_payload!(id)

    socket
    |> assign(:payload, payload)
    |> assign(:tag_names, Enum.map_join(payload.tags, ", ", & &1.name))
    |> assign(:form, to_form(Payload.changeset(payload, %{})))
  end

  @impl true
  def handle_event("validate", %{"payload" => params}, socket) do
    changeset =
      socket.assigns.payload
      |> Payload.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       form: to_form(changeset),
       tag_names: Map.get(params, "tags", socket.assigns.tag_names)
     )}
  end

  @impl true
  def handle_event("save", %{"payload" => params}, socket) do
    save_payload(socket, socket.assigns.live_action, params)
  end

  defp save_payload(socket, :new, params) do
    case Catalog.create_payload_with_tags(params, params["tags"]) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payload created")
         |> push_navigate(to: ~p"/payloads")}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(changeset, action: :insert),
           tag_names: params["tags"] || ""
         )}
    end
  end

  defp save_payload(socket, :edit, params) do
    case Catalog.update_payload_with_tags(socket.assigns.payload, params, params["tags"]) do
      {:ok, _payload} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payload updated")
         |> push_navigate(to: ~p"/payloads")}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(changeset, action: :update),
           tag_names: params["tags"] || ""
         )}
    end
  end
end
