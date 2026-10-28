defmodule RevkitWeb.RecipeLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Engine.Transforms
  alias RevkitWeb.UI

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tags, Catalog.list_tags())
     |> assign_recipes(nil, false, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     assign_recipes(
       socket,
       params["q"],
       params["favorites"] == "true",
       parse_id(params["tag"])
     )}
  end

  @impl true
  def handle_event("search", params, socket) do
    {:noreply,
     assign_recipes(
       socket,
       params["q"],
       params["favorites"] == "true",
       parse_id(params["tag_id"])
     )}
  end

  @impl true
  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)
    {:ok, _recipe} = Catalog.toggle_recipe_favorite(recipe)
    {:noreply, refresh(socket)}
  end

  @impl true
  def handle_event("fork", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)

    case Catalog.fork_recipe(recipe) do
      {:ok, forked} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe forked as #{forked.name}")
         |> refresh()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not fork recipe")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id)

    case Catalog.delete_recipe(recipe) do
      {:ok, _recipe} ->
        {:noreply, socket |> put_flash(:info, "Recipe deleted") |> refresh()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete recipe")}
    end
  end

  defp refresh(socket) do
    assign_recipes(
      socket,
      socket.assigns.query,
      socket.assigns.favorites_only,
      socket.assigns.tag_id
    )
  end

  defp assign_recipes(socket, query, favorites_only, tag_id) do
    recipes =
      Catalog.search_recipes(query, favorite: favorites_only, tag_id: tag_id)

    chains = Map.new(recipes, fn recipe -> {recipe.id, chain_labels(recipe)} end)

    assign(socket,
      recipes: recipes,
      chains: chains,
      query: query || "",
      favorites_only: favorites_only,
      tag_id: tag_id
    )
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

  defp parse_id(nil), do: nil
  defp parse_id(""), do: nil

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} -> value
      _other -> nil
    end
  end
end
