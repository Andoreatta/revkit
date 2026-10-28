defmodule RevkitWeb.RecipeLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Engine.Transforms

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_recipes(socket, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_recipes(socket, params["q"])}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign_recipes(socket, query)}
  end

  @impl true
  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)
    {:ok, _recipe} = Catalog.toggle_recipe_favorite(recipe)
    {:noreply, assign_recipes(socket, socket.assigns.query)}
  end

  @impl true
  def handle_event("fork", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)

    case Catalog.fork_recipe(recipe) do
      {:ok, forked} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe forked as #{forked.name}")
         |> assign_recipes(socket.assigns.query)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not fork recipe")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)

    case Catalog.delete_recipe(recipe) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe deleted")
         |> assign_recipes(socket.assigns.query)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete recipe")}
    end
  end

  defp assign_recipes(socket, query) do
    recipes = Catalog.search_recipes(query)
    chains = Map.new(recipes, fn recipe -> {recipe.id, chain_labels(recipe)} end)

    assign(socket, recipes: recipes, chains: chains, query: query || "")
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
