defmodule RevkitWeb.RecipeLive.Show do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Engine.Template
  alias Revkit.Engine.Transforms
  alias RevkitWeb.UI

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    recipe = Catalog.get_recipe!(id)

    {:noreply,
     assign(socket,
       recipe: recipe,
       variables: variable_rows(recipe),
       chain: chain_labels(recipe)
     )}
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    {:ok, recipe} = Catalog.toggle_recipe_favorite(socket.assigns.recipe)
    {:noreply, assign(socket, :recipe, recipe)}
  end

  @impl true
  def handle_event("fork", _params, socket) do
    case Catalog.fork_recipe(socket.assigns.recipe) do
      {:ok, forked} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe forked as #{forked.name}")
         |> push_navigate(to: ~p"/recipes/#{forked.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not fork recipe")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _recipe} = Catalog.delete_recipe(socket.assigns.recipe)

    {:noreply,
     socket
     |> put_flash(:info, "Recipe deleted")
     |> push_navigate(to: ~p"/recipes")}
  end

  defp variable_rows(recipe) do
    names =
      if map_size(recipe.variables) > 0 do
        recipe.variables |> Map.keys() |> Enum.sort()
      else
        Template.variables(recipe.template || "")
      end

    Enum.map(names, fn name -> {name, Map.get(recipe.variables, name, "")} end)
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
