defmodule RevkitWeb.RecipeLive.Form do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.Recipe
  alias Revkit.Engine.Transforms

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
    |> assign(:steps, Enum.map(recipe.steps, &to_editor_step/1))
    |> assign(:tag_names, Enum.map_join(recipe.tags, ", ", & &1.name))
    |> assign(:target_tools, Enum.join(recipe.target_tools, ", "))
    |> assign(:form, to_form(Recipe.changeset(recipe, %{})))
  end

  defp to_editor_step(step) do
    %{
      id: System.unique_integer([:positive]),
      key: step["key"] || step[:key] || "",
      options: step["options"] || step[:options] || %{}
    }
  end

  @impl true
  def handle_event("validate", %{"recipe" => params}, socket) do
    steps = merge_steps(socket.assigns.steps, params["steps"])

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
    step = %{id: System.unique_integer([:positive]), key: "", options: %{}}

    {:noreply, assign(socket, :steps, socket.assigns.steps ++ [step])}
  end

  @impl true
  def handle_event("remove_step", %{"id" => id}, socket) do
    id = String.to_integer(id)
    steps = Enum.reject(socket.assigns.steps, &(&1.id == id))

    {:noreply, assign(socket, :steps, steps)}
  end

  @impl true
  def handle_event("move_step", %{"id" => id, "direction" => direction}, socket) do
    id = String.to_integer(id)
    steps = socket.assigns.steps
    index = Enum.find_index(steps, &(&1.id == id))

    steps =
      cond do
        is_nil(index) -> steps
        direction == "up" and index > 0 -> swap(steps, index, index - 1)
        direction == "down" and index < length(steps) - 1 -> swap(steps, index, index + 1)
        true -> steps
      end

    {:noreply, assign(socket, :steps, steps)}
  end

  @impl true
  def handle_event("save", %{"recipe" => params}, socket) do
    steps = merge_steps(socket.assigns.steps, params["steps"])
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

  defp merge_steps(steps, step_params) when is_map(step_params) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {step, index} ->
      case Map.get(step_params, Integer.to_string(index)) do
        nil -> step
        params -> %{step | key: params["key"] || ""}
      end
    end)
  end

  defp merge_steps(steps, _step_params), do: steps

  defp attrs(params, steps) do
    tools =
      params
      |> Map.get("target_tools_text", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    params
    |> Map.delete("target_tools_text")
    |> Map.put("target_tools", tools)
    |> Map.put("steps", Enum.map(steps, &step_attrs/1))
  end

  defp step_attrs(step) do
    %{"key" => step.key || "", "options" => step.options || %{}}
  end

  defp swap(steps, left, right) do
    steps
    |> List.replace_at(left, Enum.at(steps, right))
    |> List.replace_at(right, Enum.at(steps, left))
  end
end
