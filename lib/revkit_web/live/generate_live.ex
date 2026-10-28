defmodule RevkitWeb.GenerateLive do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Engine.Chain
  alias Revkit.Engine.Transforms
  alias Revkit.Engine.Validator

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       recipes: Catalog.list_recipes(),
       payloads: Catalog.list_payloads(),
       template: "",
       recipe_id: nil,
       preview: preview("", nil)
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    payload = payload_from_params(params["payload_id"])
    recipe = recipe_from_params(params["recipe_id"], payload, socket.assigns.recipes)

    template = if payload, do: payload.template, else: ""
    recipe_id = recipe && recipe.id

    {:noreply,
     assign(socket,
       template: template,
       recipe_id: recipe_id,
       preview: preview(template, recipe)
     )}
  end

  @impl true
  def handle_event("preview", params, socket) do
    recipe = find_recipe(params["recipe_id"], socket.assigns.recipes)

    {:noreply, assign(socket, :preview, preview(params["template"], recipe))}
  end

  defp payload_from_params(nil), do: nil
  defp payload_from_params(""), do: nil

  defp payload_from_params(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> Catalog.get_payload(id)
      _other -> nil
    end
  end

  defp recipe_from_params(id, payload, recipes) do
    find_recipe(id, recipes) || (payload && payload.recipe)
  end

  defp find_recipe(nil, _recipes), do: nil
  defp find_recipe("", _recipes), do: nil

  defp find_recipe(id, recipes) when is_binary(id) do
    Enum.find(recipes, &(Integer.to_string(&1.id) == id))
  end

  defp find_recipe(id, recipes) when is_integer(id) do
    Enum.find(recipes, &(&1.id == id))
  end

  defp preview(template, recipe) do
    steps = if recipe, do: recipe.steps, else: []

    case Transforms.resolve(steps) do
      {:ok, chain} ->
        run_chain(template || "", chain, recipe)

      {:error, reason} ->
        %{
          status: :error,
          output: nil,
          error: format_error(reason),
          recipe: recipe,
          steps: [],
          validation: %{requires: [], pitfalls: []}
        }
    end
  end

  defp run_chain(template, chain, recipe) do
    validation = Validator.validate(chain)

    case Chain.run(template, chain) do
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

  defp format_error({:unknown_transform, key}), do: "Unknown transform: #{key}"
  defp format_error({:invalid_step, _step}), do: "The recipe contains an invalid step."
  defp format_error(reason), do: inspect(reason)
end
