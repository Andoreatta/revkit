defmodule Revkit.Catalog do
  @moduledoc """
  The catalog context: payload templates, transform recipes and tags.

  This is the only module that talks to `Revkit.Repo`. LiveViews call this
  context; the engine never does.
  """

  import Ecto.Query, warn: false

  alias Revkit.Catalog.{Payload, Recipe, Tag}
  alias Revkit.Repo

  ## Payloads

  @doc "Lists payloads ordered by name, with tags and recipe preloaded."
  def list_payloads do
    Repo.all(from payload in Payload, order_by: [asc: payload.name], preload: [:tags, :recipe])
  end

  @doc "Gets a payload with tags and recipe preloaded, or `nil`."
  def get_payload(id), do: Repo.get(Payload, id) |> preload_payload()

  @doc "Gets a payload with tags and recipe preloaded, or raises."
  def get_payload!(id), do: Repo.get!(Payload, id) |> preload_payload()

  @doc "Creates a payload."
  def create_payload(attrs \\ %{}) do
    %Payload{}
    |> Payload.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Creates a payload and assigns tags by name in a single transaction."
  def create_payload_with_tags(attrs, tag_names) do
    Repo.transaction(fn ->
      with {:ok, payload} <- %Payload{} |> Payload.changeset(attrs) |> Repo.insert(),
           {:ok, payload} <- put_payload_tag_names(payload, tag_names) do
        payload
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc "Updates a payload."
  def update_payload(%Payload{} = payload, attrs) do
    payload
    |> Payload.changeset(attrs)
    |> Repo.update()
  end

  @doc "Updates a payload and replaces its tags by name in a single transaction."
  def update_payload_with_tags(%Payload{} = payload, attrs, tag_names) do
    Repo.transaction(fn ->
      with {:ok, payload} <- payload |> Payload.changeset(attrs) |> Repo.update(),
           {:ok, payload} <- put_payload_tag_names(payload, tag_names) do
        payload
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc "Deletes a payload."
  def delete_payload(%Payload{} = payload), do: Repo.delete(payload)

  @doc "Returns a changeset for tracking payload changes."
  def change_payload(%Payload{} = payload, attrs \\ %{}) do
    Payload.changeset(payload, attrs)
  end

  @doc """
  Replaces the payload's tags with the tags identified by `tag_ids`.

  Returns an error changeset if any id does not reference an existing tag.
  """
  def put_payload_tags(%Payload{} = payload, tag_ids) when is_list(tag_ids) do
    tag_ids = Enum.uniq(tag_ids)
    tags = Repo.all(from tag in Tag, where: tag.id in ^tag_ids)
    payload = Repo.preload(payload, :tags)

    if length(tags) == length(tag_ids) do
      payload
      |> Payload.tags_changeset(tags)
      |> Repo.update()
    else
      changeset =
        payload
        |> Payload.tags_changeset(tags)
        |> Ecto.Changeset.add_error(:tags, "reference unknown tags")

      {:error, changeset}
    end
  end

  @doc """
  Replaces the payload's tags with tags found or created by name.

  Names may be a list or a comma-separated string; they are trimmed,
  de-duplicated and blank names are ignored.
  """
  def put_payload_tag_names(%Payload{} = payload, tag_names) do
    with {:ok, tags} <- ensure_tags(normalize_tag_names(tag_names)) do
      put_payload_tags(payload, Enum.map(tags, & &1.id))
    end
  end

  ## Recipes

  @doc "Lists recipes ordered by name."
  def list_recipes do
    Repo.all(from recipe in Recipe, order_by: [asc: recipe.name])
  end

  @doc "Gets a recipe, or `nil`."
  def get_recipe(id), do: Repo.get(Recipe, id)

  @doc "Gets a recipe, or raises."
  def get_recipe!(id), do: Repo.get!(Recipe, id)

  @doc "Creates a recipe."
  def create_recipe(attrs \\ %{}) do
    %Recipe{}
    |> Recipe.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a recipe."
  def update_recipe(%Recipe{} = recipe, attrs) do
    recipe
    |> Recipe.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a recipe. Payloads that reference it keep a `nil` recipe id."
  def delete_recipe(%Recipe{} = recipe), do: Repo.delete(recipe)

  @doc "Returns a changeset for tracking recipe changes."
  def change_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end

  ## Tags

  @doc "Lists tags ordered by name."
  def list_tags do
    Repo.all(from tag in Tag, order_by: [asc: tag.name])
  end

  @doc "Gets a tag, or `nil`."
  def get_tag(id), do: Repo.get(Tag, id)

  @doc "Gets a tag, or raises."
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc "Creates a tag."
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a tag."
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a tag and its payload associations."
  def delete_tag(%Tag{} = tag), do: Repo.delete(tag)

  @doc "Returns a changeset for tracking tag changes."
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  defp normalize_tag_names(tag_names) do
    tag_names
    |> List.wrap()
    |> Enum.flat_map(fn
      name when is_binary(name) -> String.split(name, ",")
      _other -> []
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp ensure_tags(names) do
    names
    |> Enum.reduce_while({:ok, []}, fn name, {:ok, acc} ->
      case ensure_tag(name) do
        {:ok, tag} -> {:cont, {:ok, [tag | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, tags} -> {:ok, Enum.reverse(tags)}
      error -> error
    end
  end

  defp ensure_tag(name) do
    case Repo.get_by(Tag, name: name) do
      nil ->
        %Tag{}
        |> Tag.changeset(%{name: name})
        |> Repo.insert()

      tag ->
        {:ok, tag}
    end
  end

  defp preload_payload(nil), do: nil
  defp preload_payload(payload), do: Repo.preload(payload, [:tags, :recipe])
end
