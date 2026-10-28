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
    recipe = Catalog.get_recipe!(id, socket.assigns.owner_id)

    {:noreply,
     assign(socket,
       recipe: recipe,
       owned: owned?(recipe, socket.assigns.owner_id),
       variables: variable_rows(recipe),
       chain: chain_labels(recipe)
     )}
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    case Catalog.toggle_recipe_favorite(socket.assigns.recipe, socket.assigns.owner_id) do
      {:ok, recipe} ->
        {:noreply, assign(socket, :recipe, recipe)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Public entries cannot be favorited")}
    end
  end

  @impl true
  def handle_event("improve", _params, socket) do
    case Catalog.improve_recipe(socket.assigns.recipe, socket.assigns.owner_id) do
      {:ok, edition} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your edition is ready")
         |> push_navigate(to: ~p"/recipes/#{edition.id}")}

      {:error, :limit_reached} ->
        {:noreply, put_flash(socket, :error, "Edition limit reached")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not improve recipe")}
    end
  end

  @impl true
  def handle_event("discard", _params, socket) do
    case Catalog.discard_recipe(socket.assigns.recipe, socket.assigns.owner_id) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Edition discarded")
         |> push_navigate(to: ~p"/recipes")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not discard edition")}
    end
  end

  defp owned?(%{owner_id: owner_id}, owner_id) when is_binary(owner_id), do: true
  defp owned?(_recipe, _owner_id), do: false

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
