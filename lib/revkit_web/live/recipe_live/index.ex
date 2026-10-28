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
    recipe = Catalog.get_owned_recipe!(id, socket.assigns.owner_id)

    case Catalog.toggle_recipe_favorite(recipe, socket.assigns.owner_id) do
      {:ok, _recipe} -> {:noreply, refresh(socket)}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Could not favorite recipe")}
    end
  end

  @impl true
  def handle_event("improve", %{"id" => id}, socket) do
    recipe = Catalog.get_recipe!(id, socket.assigns.owner_id)

    case Catalog.improve_recipe(recipe, socket.assigns.owner_id) do
      {:ok, edition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your edition is ready")
         |> push_navigate(to: ~p"/recipes/#{edition.id}/edit")}

      {:error, :limit_reached} ->
        {:noreply, put_flash(socket, :error, "Edition limit reached")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not improve recipe")}
    end
  end

  @impl true
  def handle_event("discard", %{"id" => id}, socket) do
    recipe = Catalog.get_owned_recipe!(id, socket.assigns.owner_id)

    case Catalog.discard_recipe(recipe, socket.assigns.owner_id) do
      {:ok, _recipe} ->
        {:noreply, socket |> put_flash(:info, "Edition discarded") |> refresh()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not discard edition")}
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
      Catalog.search_recipes(socket.assigns.owner_id, query,
        favorite: favorites_only,
        tag_id: tag_id
      )

    chains = Map.new(recipes, fn recipe -> {recipe.id, chain_labels(recipe)} end)

    assign(socket,
      recipes: recipes,
      public_recipes: Enum.filter(recipes, &is_nil(&1.owner_id)),
      owned_recipes: Enum.reject(recipes, &is_nil(&1.owner_id)),
      chains: chains,
      quota: Catalog.private_recipe_count(socket.assigns.owner_id),
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
