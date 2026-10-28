defmodule RevkitWeb.GenerateLive do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.{Payload, Recipe}
  alias Revkit.Engine.Chain
  alias Revkit.Engine.Template
  alias Revkit.Engine.Transforms
  alias Revkit.Engine.Validator

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       recipes: Catalog.list_recipes(),
       payloads: Catalog.list_payloads(),
       template: "",
       variables: %{},
       variable_names: [],
       steps: [],
       payload_id: nil,
       recipe_id: nil,
       target: %{},
       preview: preview("", %{}, [], %{}, nil),
       save_form: save_form()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    payload = payload_from_params(params["payload_id"])
    recipe = find_recipe(params["recipe_id"], socket.assigns.recipes)

    state =
      cond do
        recipe -> load_state(payload, recipe)
        payload -> load_payload_state(payload)
        true -> load_state(nil, nil)
      end

    {:noreply,
     assign(socket, state)
     |> assign(
       :preview,
       preview(state.template, state.variables, state.steps, state.target, recipe)
     )
     |> assign(:save_form, save_form())}
  end

  @impl true
  def handle_event("preview", params, socket) do
    payload_changed? = changed?(params, "payload_id", socket.assigns.payload_id)
    recipe_changed? = changed?(params, "recipe_id", socket.assigns.recipe_id)

    state =
      cond do
        recipe_changed? ->
          socket
          |> recipe_state(params["recipe_id"])
          |> with_template_fallback(params["template"] || socket.assigns.template)

        payload_changed? ->
          payload_state(socket, params["payload_id"])

        true ->
          edited_state(socket, params)
      end

    recipe = find_recipe(state.recipe_id, socket.assigns.recipes)

    {:noreply,
     assign(socket, state)
     |> assign(
       :preview,
       preview(state.template, state.variables, state.steps, state.target, recipe)
     )}
  end

  @impl true
  def handle_event("add_step", _params, socket) do
    steps = socket.assigns.steps ++ [new_step()]
    {:noreply, assign_steps(socket, steps)}
  end

  @impl true
  def handle_event("remove_step", %{"id" => id}, socket) do
    id = String.to_integer(id)
    steps = Enum.reject(socket.assigns.steps, &(&1.id == id))
    {:noreply, assign_steps(socket, steps)}
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

    {:noreply, assign_steps(socket, steps)}
  end

  @impl true
  def handle_event("save_recipe", %{"recipe" => params}, socket) do
    attrs =
      params
      |> Map.put("template", socket.assigns.template)
      |> Map.put("variables", socket.assigns.variables)
      |> Map.put("steps", steps_to_attrs(socket.assigns.steps))
      |> Map.put("payload_id", socket.assigns.payload_id)
      |> Map.put("target_os", socket.assigns.target[:os])
      |> Map.put("target_shell", socket.assigns.target[:shell])
      |> Map.put("target_tools", socket.assigns.target[:tools] || [])

    case Catalog.create_recipe_with_tags(attrs, params["tags"]) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe saved")
         |> push_navigate(to: ~p"/recipes")}

      {:error, changeset} ->
        {:noreply, assign(socket, save_form: to_form(changeset, action: :insert))}
    end
  end

  defp save_form do
    to_form(Recipe.changeset(%Recipe{}, %{}))
  end

  defp load_state(nil, nil) do
    %{
      template: "",
      variables: %{},
      variable_names: [],
      steps: [],
      payload_id: nil,
      recipe_id: nil,
      target: %{}
    }
  end

  defp load_state(payload, %Recipe{} = recipe) do
    fallback_template =
      loaded_payload_template(recipe.payload) || (payload && payload.template) || ""

    template = if recipe.template in [nil, ""], do: fallback_template, else: recipe.template

    %{
      template: template,
      variables: merge_variable_names(template, stringify_variables(recipe.variables)),
      variable_names: Template.variables(template),
      steps: to_editor_steps(recipe.steps),
      payload_id: recipe.payload_id || (payload && payload.id),
      recipe_id: recipe.id,
      target: target_from_recipe(recipe, payload)
    }
  end

  defp load_payload_state(payload) do
    recipe = payload.recipe
    template = payload.template || ""

    variables =
      if recipe && recipe.template in [nil, "", template] do
        stringify_variables(recipe.variables)
      else
        %{}
      end

    %{
      template: template,
      variables: merge_variable_names(template, variables),
      variable_names: Template.variables(template),
      steps: to_editor_steps(if recipe, do: recipe.steps, else: []),
      payload_id: payload.id,
      recipe_id: recipe && recipe.id,
      target: target_from_payload(payload)
    }
  end

  defp with_template_fallback(%{template: ""} = state, template) do
    variables = merge_variable_names(template, state.variables)

    %{
      state
      | template: template,
        variables: variables,
        variable_names: Template.variables(template)
    }
  end

  defp with_template_fallback(state, _template), do: state

  defp loaded_payload_template(%Payload{template: template}), do: template
  defp loaded_payload_template(_payload), do: nil

  defp edited_state(socket, params) do
    template = Map.get(params, "template", socket.assigns.template) || ""

    merged_variables =
      socket.assigns.variables |> Map.merge(Map.get(params, "variables") || %{})

    variables =
      Map.new(Template.variables(template), fn name ->
        {name, Map.get(merged_variables, name, "")}
      end)

    steps = merge_steps(socket.assigns.steps, params["steps"])

    %{
      template: template,
      variables: variables,
      variable_names: Template.variables(template),
      steps: steps,
      payload_id: socket.assigns.payload_id,
      recipe_id: socket.assigns.recipe_id,
      target: socket.assigns.target
    }
  end

  defp recipe_state(socket, id) do
    case find_recipe(id, socket.assigns.recipes) do
      nil ->
        %{
          template: socket.assigns.template,
          variables: socket.assigns.variables,
          variable_names: socket.assigns.variable_names,
          steps: socket.assigns.steps,
          payload_id: socket.assigns.payload_id,
          recipe_id: nil,
          target: socket.assigns.target
        }

      recipe ->
        load_state(socket.assigns.payloads |> Enum.find(&(&1.id == recipe.payload_id)), recipe)
    end
  end

  defp payload_state(socket, id) do
    case find_payload(id, socket.assigns.payloads) do
      nil ->
        %{
          template: socket.assigns.template,
          variables: socket.assigns.variables,
          variable_names: socket.assigns.variable_names,
          steps: socket.assigns.steps,
          payload_id: nil,
          recipe_id: socket.assigns.recipe_id,
          target: %{}
        }

      payload ->
        load_payload_state(payload)
    end
  end

  defp assign_steps(socket, steps) do
    recipe = find_recipe(socket.assigns.recipe_id, socket.assigns.recipes)

    preview =
      preview(
        socket.assigns.template,
        socket.assigns.variables,
        steps,
        socket.assigns.target,
        recipe
      )

    assign(socket, steps: steps, preview: preview)
  end

  defp preview(template, variables, steps, target, recipe) do
    case Transforms.resolve(steps) do
      {:ok, chain} ->
        validation = Validator.validate(chain, target)

        case Template.render(template || "", variables) do
          {:ok, rendered} ->
            run_chain(rendered, chain, recipe, validation)

          {:error, {:missing_variables, missing}} ->
            %{
              status: :error,
              output: nil,
              error: "Missing variables: " <> Enum.join(missing, ", "),
              recipe: recipe,
              steps: chain,
              validation: validation
            }
        end

      {:error, reason} ->
        %{
          status: :error,
          output: nil,
          error: format_error(reason),
          recipe: recipe,
          steps: [],
          validation: empty_validation()
        }
    end
  end

  defp run_chain(rendered, chain, recipe, validation) do
    case Chain.run(rendered, chain) do
      {:ok, output} ->
        %{
          status: :ok,
          output: output,
          error: nil,
          recipe: recipe,
          steps: chain,
          validation: validation
        }

      {:error, reason} ->
        %{
          status: :error,
          output: nil,
          error: format_error(reason),
          recipe: recipe,
          steps: chain,
          validation: validation
        }
    end
  end

  defp empty_validation do
    %{requires: [], pitfalls: [], warnings: [], compatible: true}
  end

  defp target_from_payload(payload) do
    %{os: payload.target_os, shell: payload.target_shell, tools: payload.target_tools || []}
  end

  defp target_from_recipe(recipe, payload) do
    target = %{os: recipe.target_os, shell: recipe.target_shell, tools: recipe.target_tools || []}

    cond do
      target != %{os: nil, shell: nil, tools: []} ->
        target

      match?(%Payload{}, recipe.payload) ->
        target_from_payload(recipe.payload)

      payload ->
        target_from_payload(payload)

      true ->
        target
    end
  end

  defp payload_from_params(nil), do: nil
  defp payload_from_params(""), do: nil

  defp payload_from_params(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> Catalog.get_payload(id)
      _other -> nil
    end
  end

  defp find_payload(id, payloads) do
    Enum.find(payloads, &(id_string(&1.id) == id_string(id)))
  end

  defp find_recipe(id, recipes) do
    Enum.find(recipes, &(id_string(&1.id) == id_string(id)))
  end

  defp changed?(params, key, current) do
    Map.has_key?(params, key) and id_string(Map.get(params, key)) != id_string(current)
  end

  defp id_string(nil), do: ""
  defp id_string(id) when is_integer(id), do: Integer.to_string(id)
  defp id_string(id), do: to_string(id)

  defp stringify_variables(variables) when is_map(variables) do
    Map.new(variables, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_variables(_variables), do: %{}

  defp merge_variable_names(template, variables) do
    Map.new(Template.variables(template), fn name -> {name, Map.get(variables, name, "")} end)
  end

  defp to_editor_steps(steps) when is_list(steps) do
    Enum.map(steps, fn step ->
      %{
        id: System.unique_integer([:positive]),
        key: step["key"] || step[:key] || "",
        options: step["options"] || step[:options] || %{}
      }
    end)
  end

  defp to_editor_steps(_steps), do: []

  defp new_step, do: %{id: System.unique_integer([:positive]), key: "", options: %{}}

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

  defp steps_to_attrs(steps) do
    Enum.map(steps, fn step ->
      %{"key" => step.key || "", "options" => step.options || %{}}
    end)
  end

  defp swap(steps, left, right) do
    steps
    |> List.replace_at(left, Enum.at(steps, right))
    |> List.replace_at(right, Enum.at(steps, left))
  end

  defp format_error({:unknown_transform, key}), do: "Unknown transform: #{key}"
  defp format_error({:invalid_step, _step}), do: "The recipe contains an invalid step."
  defp format_error(reason), do: inspect(reason)
end
