defmodule RevkitWeb.RecipeLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Engine.Transforms

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_recipes(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)

    case Catalog.delete_recipe(recipe) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe deleted")
         |> assign_recipes()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete recipe")}
    end
  end

  defp assign_recipes(socket) do
    recipes = Catalog.list_recipes()
    chains = Map.new(recipes, fn recipe -> {recipe.id, chain_labels(recipe)} end)

    assign(socket, recipes: recipes, chains: chains)
  end

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
