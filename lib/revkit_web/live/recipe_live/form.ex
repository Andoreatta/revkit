defmodule RevkitWeb.RecipeLive.Form do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.Recipe
  alias RevkitWeb.{StepEditor, TargetParams, UI}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tags, Catalog.list_tags())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    recipe = %Recipe{}

    socket
    |> assign(:recipe, recipe)
    |> assign(:steps, [])
    |> assign(:selected_tag_ids, [])
    |> assign(:tag_errors, [])
    |> assign(:target_tools, "")
    |> assign(:form, to_form(Recipe.changeset(recipe, %{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    recipe = Catalog.get_owned_recipe!(id, socket.assigns.owner_id)

    socket
    |> assign(:recipe, recipe)
    |> assign(:steps, StepEditor.to_editor_steps(recipe.steps))
    |> assign(:selected_tag_ids, Enum.map(recipe.tags, & &1.id))
    |> assign(:tag_errors, [])
    |> assign(:target_tools, Enum.join(recipe.target_tools, ", "))
    |> assign(:form, to_form(Recipe.changeset(recipe, %{})))
  end

  @impl true
  def handle_event("validate", %{"recipe" => params}, socket) do
    steps = StepEditor.merge(socket.assigns.steps, params["steps"])

    changeset =
      socket.assigns.recipe
      |> Recipe.changeset(attrs(params, steps))
      |> Map.put(:action, :validate)

    selected_tag_ids = parse_tag_ids(params["tags"])

    {:noreply,
     assign(socket,
       form: to_form(changeset),
       steps: steps,
       selected_tag_ids: selected_tag_ids,
       tag_errors: tag_errors(selected_tag_ids),
       target_tools: Map.get(params, "target_tools_text", socket.assigns.target_tools)
     )}
  end

  @impl true
  def handle_event("add_step", _params, socket) do
    {:noreply, assign(socket, :steps, StepEditor.add(socket.assigns.steps))}
  end

  @impl true
  def handle_event("remove_step", %{"id" => id}, socket) do
    {:noreply, assign(socket, :steps, StepEditor.remove(socket.assigns.steps, id))}
  end

  @impl true
  def handle_event("move_step", %{"id" => id, "direction" => direction}, socket) do
    {:noreply, assign(socket, :steps, StepEditor.move(socket.assigns.steps, id, direction))}
  end

  @impl true
  def handle_event("save", %{"recipe" => params}, socket) do
    steps = StepEditor.merge(socket.assigns.steps, params["steps"])

    socket
    |> save_recipe(attrs(params, steps), params["tags"] || [])
    |> handle_save_result(socket, params, steps)
  end

  defp save_recipe(socket, recipe_attrs, tag_ids) do
    case socket.assigns.live_action do
      :new ->
        Catalog.create_recipe(socket.assigns.owner_id, recipe_attrs, tag_ids)

      :edit ->
        Catalog.update_recipe(
          socket.assigns.recipe,
          socket.assigns.owner_id,
          recipe_attrs,
          tag_ids
        )
    end
  end

  defp handle_save_result({:ok, recipe}, socket, _params, _steps) do
    {:noreply,
     socket
     |> put_flash(:info, "Recipe saved")
     |> push_navigate(to: ~p"/recipes/#{recipe.id}")}
  end

  defp handle_save_result({:error, :limit_reached}, socket, params, steps) do
    selected_tag_ids = parse_tag_ids(params["tags"])

    {:noreply,
     socket
     |> put_flash(:error, "You have reached the private edition limit")
     |> assign(:steps, steps)
     |> assign(:selected_tag_ids, selected_tag_ids)
     |> assign(:tag_errors, tag_errors(selected_tag_ids))}
  end

  defp handle_save_result({:error, %Ecto.Changeset{} = changeset}, socket, params, steps) do
    action = if socket.assigns.live_action == :new, do: :insert, else: :update
    selected_tag_ids = parse_tag_ids(params["tags"])

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: action),
       steps: steps,
       selected_tag_ids: selected_tag_ids,
       tag_errors: tag_errors(selected_tag_ids),
       target_tools: params["target_tools_text"] || ""
     )}
  end

  defp handle_save_result({:error, _reason}, socket, _params, _steps) do
    {:noreply, put_flash(socket, :error, "Could not save recipe")}
  end

  defp attrs(params, steps) do
    params
    |> TargetParams.normalize()
    |> Map.put("steps", StepEditor.to_attrs(steps))
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

  defp tag_errors(tag_ids) do
    if length(Enum.uniq(tag_ids)) > Revkit.Limits.max_tags() do
      [{"may contain at most %{count} tags", [count: Revkit.Limits.max_tags()]}]
    else
      []
    end
  end
end
