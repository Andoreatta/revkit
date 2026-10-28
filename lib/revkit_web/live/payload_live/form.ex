defmodule RevkitWeb.PayloadLive.Form do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.Payload
  alias RevkitWeb.{TargetParams, UI}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:recipes, Catalog.list_recipes(socket.assigns.owner_id))
     |> assign(:tags, Catalog.list_tags())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    payload = %Payload{}

    socket
    |> assign(:payload, payload)
    |> assign(:selected_tag_ids, [])
    |> assign(:target_tools, "")
    |> assign(:form, to_form(Payload.changeset(payload, %{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    payload = Catalog.get_owned_payload!(id, socket.assigns.owner_id)

    socket
    |> assign(:payload, payload)
    |> assign(:selected_tag_ids, Enum.map(payload.tags, & &1.id))
    |> assign(:target_tools, Enum.join(payload.target_tools, ", "))
    |> assign(:form, to_form(Payload.changeset(payload, %{})))
  end

  @impl true
  def handle_event("validate", %{"payload" => params}, socket) do
    attrs = TargetParams.normalize(params)

    changeset =
      socket.assigns.payload
      |> Payload.changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       form: to_form(changeset),
       selected_tag_ids: parse_tag_ids(params["tags"]),
       target_tools: Map.get(params, "target_tools_text", socket.assigns.target_tools)
     )}
  end

  @impl true
  def handle_event("save", %{"payload" => params}, socket) do
    save_payload(socket, socket.assigns.live_action, params)
  end

  defp save_payload(socket, :new, params) do
    attrs = TargetParams.normalize(params)

    socket.assigns.owner_id
    |> Catalog.create_payload(attrs, params["tags"] || [])
    |> handle_save_result(socket, params)
  end

  defp save_payload(socket, :edit, params) do
    attrs = TargetParams.normalize(params)

    Catalog.update_payload(
      socket.assigns.payload,
      socket.assigns.owner_id,
      attrs,
      params["tags"] || []
    )
    |> handle_save_result(socket, params)
  end

  defp handle_save_result({:ok, payload}, socket, _params) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       if(socket.assigns.live_action == :new, do: "Payload created", else: "Payload updated")
     )
     |> push_navigate(to: ~p"/payloads/#{payload.id}")}
  end

  defp handle_save_result({:error, :limit_reached}, socket, params) do
    {:noreply,
     socket
     |> put_flash(:error, "You have reached the private edition limit")
     |> assign(:selected_tag_ids, parse_tag_ids(params["tags"]))}
  end

  defp handle_save_result({:error, %Ecto.Changeset{} = changeset}, socket, params) do
    action = if socket.assigns.live_action == :new, do: :insert, else: :update

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: action),
       selected_tag_ids: parse_tag_ids(params["tags"]),
       target_tools: params["target_tools_text"] || ""
     )}
  end

  defp handle_save_result({:error, _reason}, socket, _params) do
    {:noreply, put_flash(socket, :error, "Could not save payload")}
  end

  defp parse_tag_ids(tag_ids) do
    tag_ids
    |> List.wrap()
    |> Enum.reduce([], fn tag_id, acc ->
      case Integer.parse(to_string(tag_id)) do
        {id, ""} -> [id | acc]
        _other -> acc
      end
    end)
    |> Enum.reverse()
  end
end
