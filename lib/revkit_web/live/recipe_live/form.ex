defmodule RevkitWeb.RecipeLive.Form do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.Recipe
  alias RevkitWeb.{StepEditor, TargetParams}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
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
    |> assign(:tag_names, "")
    |> assign(:target_tools, "")
    |> assign(:form, to_form(Recipe.changeset(recipe, %{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    recipe = Catalog.get_recipe!(id)

    socket
    |> assign(:recipe, recipe)
    |> assign(:steps, StepEditor.to_editor_steps(recipe.steps))
    |> assign(:tag_names, Enum.map_join(recipe.tags, ", ", & &1.name))
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

    {:noreply,
     assign(socket,
       form: to_form(changeset),
       steps: steps,
       tag_names: Map.get(params, "tags", socket.assigns.tag_names),
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
    {:noreply,
     assign(socket, :steps, StepEditor.move(socket.assigns.steps, id, direction))}
  end

  @impl true
  def handle_event("save", %{"recipe" => params}, socket) do
    steps = StepEditor.merge(socket.assigns.steps, params["steps"])
    result = save_recipe(socket, attrs(params, steps), params["tags"])

    handle_save_result(socket, result, params, steps)
  end

  defp save_recipe(socket, recipe_attrs, tag_names) do
    case socket.assigns.live_action do
      :new -> Catalog.create_recipe_with_tags(recipe_attrs, tag_names)
      :edit -> Catalog.update_recipe_with_tags(socket.assigns.recipe, recipe_attrs, tag_names)
    end
  end

  defp handle_save_result(socket, {:ok, _recipe}, _params, _steps) do
    {:noreply,
     socket
     |> put_flash(:info, "Recipe saved")
     |> push_navigate(to: ~p"/recipes")}
  end

  defp handle_save_result(socket, {:error, changeset}, params, steps) do
    action = if socket.assigns.live_action == :new, do: :insert, else: :update
    {:noreply, save_error(socket, changeset, action, params, steps)}
  end

  defp save_error(socket, changeset, action, params, steps) do
    assign(socket,
      form: to_form(changeset, action: action),
      steps: steps,
      tag_names: params["tags"] || "",
      target_tools: params["target_tools_text"] || ""
    )
  end

  defp attrs(params, steps) do
    params
    |> TargetParams.normalize()
    |> Map.put("steps", StepEditor.to_attrs(steps))
  end
end
