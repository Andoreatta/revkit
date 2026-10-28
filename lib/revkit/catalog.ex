defmodule Revkit.Catalog do
  @moduledoc """
  The catalog context: the public payload/recipe catalog and cookie-owned
  private editions.

  Public rows (`owner_id` is `nil`) are curated and read-only. A browser may
  create a private edition of a public row or create a new private row; those
  rows are only visible to the cookie that owns them.

  This is the only module that talks to `Revkit.Repo`. LiveViews call this
  context; the engine never does.
  """

  import Ecto.Query, warn: false

  alias Revkit.Catalog.{Payload, Recipe, Tag}
  alias Revkit.Limits
  alias Revkit.Repo

  @payload_preloads [:tags, :recipe, :source_payload]
  @recipe_preloads [:tags, :payload, :source_recipe]

  ## Payloads

  @doc "Lists public payloads plus the owner's private editions, ordered by name."
  def list_payloads(owner_id) do
    base_payload_query()
    |> order_by([payload], asc: payload.name)
    |> scope_owner(owner_id)
    |> Repo.all()
  end

  @doc "Lists only public payloads."
  def list_public_payloads, do: list_payloads(nil)

  @doc "Lists only the owner's private payload editions."
  def list_owned_payloads(nil), do: []

  def list_owned_payloads(owner_id) do
    base_payload_query()
    |> order_by([payload], asc: payload.name)
    |> where([payload], payload.owner_id == ^owner_id)
    |> Repo.all()
  end

  @doc "Gets a public payload or one owned by `owner_id`, or `nil`."
  def get_payload(id, nil), do: get_visible_payload(id, :public)
  def get_payload(id, owner_id), do: get_visible_payload(id, {:owner, owner_id})

  defp get_visible_payload(id, scope) do
    case parse_id(id) do
      {:ok, id} ->
        query =
          from payload in Payload,
            where: payload.id == ^id,
            preload: ^@payload_preloads

        query =
          case scope do
            :public ->
              where(query, [payload], is_nil(payload.owner_id))

            {:owner, owner_id} ->
              where(
                query,
                [payload],
                is_nil(payload.owner_id) or payload.owner_id == ^owner_id
              )
          end

        Repo.one(query)

      {:error, _reason} ->
        nil
    end
  end

  @doc "Gets a visible payload or raises `Ecto.NoResultsError`."
  def get_payload!(id, owner_id) do
    get_payload(id, owner_id) || raise Ecto.NoResultsError, queryable: Payload
  end

  @doc "Gets a private payload owned by `owner_id` or raises."
  def get_owned_payload!(_id, nil), do: raise(Ecto.NoResultsError, queryable: Payload)

  def get_owned_payload!(id, owner_id) do
    case parse_id(id) do
      {:ok, id} ->
        Repo.one!(
          from payload in Payload,
            where: payload.id == ^id and payload.owner_id == ^owner_id,
            preload: ^@payload_preloads
        )

      {:error, _reason} ->
        raise Ecto.NoResultsError, queryable: Payload
    end
  end

  @doc "Returns a changeset for tracking payload changes."
  def change_payload(%Payload{} = payload, attrs \\ %{}) do
    Payload.changeset(payload, attrs)
  end

  @doc "Creates a private payload owned by `owner_id`."
  def create_payload(owner_id, attrs, tag_ids \\ []) do
    with {:ok, owner_id} <- require_owner(owner_id),
         :ok <- check_payload_quota(owner_id),
         {:ok, attrs} <- normalize_attrs(attrs),
         {:ok, attrs} <- normalize_payload_refs(attrs, owner_id) do
      insert_payload(attrs, owner_id, nil, tag_ids)
    end
  end

  @doc "Creates a public catalog payload. Intended for seeds."
  def create_public_payload(attrs, tag_ids \\ []) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         {:ok, attrs} <- normalize_payload_refs(attrs, nil) do
      insert_payload(attrs, nil, nil, tag_ids)
    end
  end

  @doc "Updates a private payload owned by `owner_id`."
  def update_payload(payload, owner_id, attrs, tag_ids \\ nil) do
    if owned?(payload, owner_id) do
      with {:ok, attrs} <- normalize_attrs(attrs),
           {:ok, attrs} <- normalize_payload_refs(attrs, owner_id) do
        update_payload_record(payload, attrs, tag_ids)
      end
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Returns the owner's edition of a public payload, creating one if needed.

  Public rows are never modified.
  """
  def improve_payload(%Payload{owner_id: nil} = source, owner_id) do
    with {:ok, owner_id} <- require_owner(owner_id) do
      case Repo.get_by(Payload, owner_id: owner_id, source_payload_id: source.id) do
        nil -> create_payload_edition(source, owner_id)
        edition -> {:ok, preload_payload(edition)}
      end
    end
  end

  def improve_payload(%Payload{} = source, owner_id) do
    if owned?(source, owner_id), do: {:ok, preload_payload(source)}, else: {:error, :forbidden}
  end

  @doc "Deletes a private payload edition owned by `owner_id`."
  def discard_payload(%Payload{} = payload, owner_id) do
    if owned?(payload, owner_id), do: Repo.delete(payload), else: {:error, :forbidden}
  end

  @doc "Toggles the favorite flag on a private payload."
  def toggle_payload_favorite(%Payload{} = payload, owner_id) do
    if owned?(payload, owner_id) do
      Repo.update(Payload.changeset(payload, %{favorite: not payload.favorite}))
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Searches visible payloads by name, description, or template.

  Options: `:favorite` (boolean) and `:tag_id` (integer).
  """
  def search_payloads(owner_id, term, opts \\ []) do
    base_payload_query()
    |> order_by([payload], asc: payload.name)
    |> scope_owner(owner_id)
    |> filter_favorite(opts, owner_id)
    |> filter_tag(opts)
    |> filter_payload_term(term)
    |> Repo.all()
  end

  @doc "Counts the private payload editions owned by `owner_id`."
  def private_payload_count(nil), do: 0

  def private_payload_count(owner_id) do
    Repo.aggregate(
      from(payload in Payload, where: payload.owner_id == ^owner_id),
      :count,
      :id
    )
  end

  ## Recipes

  @doc "Lists public recipes plus the owner's private editions, ordered by name."
  def list_recipes(owner_id) do
    base_recipe_query()
    |> order_by([recipe], asc: recipe.name)
    |> scope_owner(owner_id)
    |> Repo.all()
  end

  @doc "Lists only public recipes."
  def list_public_recipes, do: list_recipes(nil)

  @doc "Lists only the owner's private recipe editions."
  def list_owned_recipes(nil), do: []

  def list_owned_recipes(owner_id) do
    base_recipe_query()
    |> order_by([recipe], asc: recipe.name)
    |> where([recipe], recipe.owner_id == ^owner_id)
    |> Repo.all()
  end

  @doc "Returns the most recently updated visible recipes, newest first."
  def list_recent_recipes(owner_id, limit \\ 5) do
    base_recipe_query()
    |> scope_owner(owner_id)
    |> order_by([recipe], desc: recipe.updated_at, asc: recipe.name)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Gets a public recipe or one owned by `owner_id`, or `nil`."
  def get_recipe(id, nil), do: get_visible_recipe(id, :public)
  def get_recipe(id, owner_id), do: get_visible_recipe(id, {:owner, owner_id})

  defp get_visible_recipe(id, scope) do
    case parse_id(id) do
      {:ok, id} ->
        query =
          from recipe in Recipe,
            where: recipe.id == ^id,
            preload: ^@recipe_preloads

        query =
          case scope do
            :public ->
              where(query, [recipe], is_nil(recipe.owner_id))

            {:owner, owner_id} ->
              where(
                query,
                [recipe],
                is_nil(recipe.owner_id) or recipe.owner_id == ^owner_id
              )
          end

        Repo.one(query)

      {:error, _reason} ->
        nil
    end
  end

  @doc "Gets a visible recipe or raises `Ecto.NoResultsError`."
  def get_recipe!(id, owner_id) do
    get_recipe(id, owner_id) || raise Ecto.NoResultsError, queryable: Recipe
  end

  @doc "Gets a private recipe owned by `owner_id` or raises."
  def get_owned_recipe!(_id, nil), do: raise(Ecto.NoResultsError, queryable: Recipe)

  def get_owned_recipe!(id, owner_id) do
    case parse_id(id) do
      {:ok, id} ->
        Repo.one!(
          from recipe in Recipe,
            where: recipe.id == ^id and recipe.owner_id == ^owner_id,
            preload: ^@recipe_preloads
        )

      {:error, _reason} ->
        raise Ecto.NoResultsError, queryable: Recipe
    end
  end

  @doc "Returns a changeset for tracking recipe changes."
  def change_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end

  @doc "Creates a private recipe snapshot owned by `owner_id`."
  def create_recipe(owner_id, attrs, tag_ids \\ []) do
    with {:ok, owner_id} <- require_owner(owner_id),
         :ok <- check_recipe_quota(owner_id),
         {:ok, attrs} <- normalize_attrs(attrs),
         {:ok, attrs} <- normalize_recipe_refs(attrs, owner_id) do
      insert_recipe(attrs, owner_id, nil, tag_ids)
    end
  end

  @doc "Creates a public catalog recipe. Intended for seeds."
  def create_public_recipe(attrs, tag_ids \\ []) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         {:ok, attrs} <- normalize_recipe_refs(attrs, nil) do
      insert_recipe(attrs, nil, nil, tag_ids)
    end
  end

  @doc "Updates a private recipe owned by `owner_id`."
  def update_recipe(recipe, owner_id, attrs, tag_ids \\ nil) do
    if owned?(recipe, owner_id) do
      with {:ok, attrs} <- normalize_attrs(attrs),
           {:ok, attrs} <- normalize_recipe_refs(attrs, owner_id) do
        update_recipe_record(recipe, attrs, tag_ids)
      end
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Returns the owner's edition of a public recipe, creating one if needed.

  Public rows are never modified.
  """
  def improve_recipe(%Recipe{owner_id: nil} = source, owner_id) do
    with {:ok, owner_id} <- require_owner(owner_id) do
      case Repo.get_by(Recipe, owner_id: owner_id, source_recipe_id: source.id) do
        nil -> create_recipe_edition(source, owner_id)
        edition -> {:ok, preload_recipe(edition)}
      end
    end
  end

  def improve_recipe(%Recipe{} = source, owner_id) do
    if owned?(source, owner_id), do: {:ok, preload_recipe(source)}, else: {:error, :forbidden}
  end

  @doc "Deletes a private recipe edition owned by `owner_id`."
  def discard_recipe(%Recipe{} = recipe, owner_id) do
    if owned?(recipe, owner_id), do: Repo.delete(recipe), else: {:error, :forbidden}
  end

  @doc "Toggles the favorite flag on a private recipe."
  def toggle_recipe_favorite(%Recipe{} = recipe, owner_id) do
    if owned?(recipe, owner_id) do
      Repo.update(Recipe.changeset(recipe, %{favorite: not recipe.favorite}))
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Searches visible recipes by name, description, template, or notes.

  Options: `:favorite` (boolean) and `:tag_id` (integer).
  """
  def search_recipes(owner_id, term, opts \\ []) do
    base_recipe_query()
    |> order_by([recipe], asc: recipe.name)
    |> scope_owner(owner_id)
    |> filter_favorite(opts, owner_id)
    |> filter_tag(opts)
    |> filter_recipe_term(term)
    |> Repo.all()
  end

  @doc "Counts the private recipe editions owned by `owner_id`."
  def private_recipe_count(nil), do: 0

  def private_recipe_count(owner_id) do
    Repo.aggregate(
      from(recipe in Recipe, where: recipe.owner_id == ^owner_id),
      :count,
      :id
    )
  end

  ## Tags

  @doc "Lists the fixed tag vocabulary ordered by name."
  def list_tags do
    Repo.all(from tag in Tag, order_by: [asc: tag.name])
  end

  @doc "Lists tags with usage counts for public rows plus the owner's editions."
  def list_tags_with_usage(owner_id) do
    payload_counts =
      from(payload in Payload,
        join: tag in assoc(payload, :tags),
        group_by: tag.id,
        select: {tag.id, count(payload.id)}
      )
      |> scope_owner(owner_id)
      |> Repo.all()
      |> Map.new()

    recipe_counts =
      from(recipe in Recipe,
        join: tag in assoc(recipe, :tags),
        group_by: tag.id,
        select: {tag.id, count(recipe.id)}
      )
      |> scope_owner(owner_id)
      |> Repo.all()
      |> Map.new()

    Enum.map(list_tags(), fn tag ->
      %{
        tag: tag,
        payloads: Map.get(payload_counts, tag.id, 0),
        recipes: Map.get(recipe_counts, tag.id, 0)
      }
    end)
  end

  @doc "Gets a tag, or `nil`."
  def get_tag(id), do: Repo.get(Tag, id)

  @doc "Gets a tag, or raises."
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc "Creates a tag while the fixed vocabulary has room. Intended for seeds."
  def create_tag(attrs \\ %{}) do
    if tag_count() >= Limits.max_tag_vocabulary() do
      {:error, :vocabulary_full}
    else
      %Tag{}
      |> Tag.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc "Creates missing tags from the fixed vocabulary. Intended for seeds."
  def ensure_tags(names) do
    names
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn name, {:ok, acc} ->
      case ensure_tag(name) do
        {:ok, tag} -> {:cont, {:ok, [tag | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, tags} -> {:ok, Enum.reverse(tags)}
      error -> error
    end
  end

  defp ensure_tag(name) do
    case Repo.get_by(Tag, name: name) do
      nil -> create_tag(%{name: name})
      tag -> {:ok, tag}
    end
  end

  ## Internal helpers

  defp base_payload_query do
    from payload in Payload, preload: ^@payload_preloads
  end

  defp base_recipe_query do
    from recipe in Recipe, preload: ^@recipe_preloads
  end

  defp scope_owner_condition(owner_id),
    do: dynamic([record], is_nil(record.owner_id) or record.owner_id == ^owner_id)

  defp scope_owner(query, nil), do: where(query, [record], is_nil(record.owner_id))
  defp scope_owner(query, owner_id), do: where(query, ^scope_owner_condition(owner_id))

  defp filter_favorite(query, opts, owner_id) do
    if Keyword.get(opts, :favorite, false) do
      case owner_id do
        nil ->
          where(query, [record], false)

        owner_id ->
          where(query, [record], record.owner_id == ^owner_id and record.favorite == true)
      end
    else
      query
    end
  end

  defp filter_tag(query, opts) do
    case Keyword.get(opts, :tag_id) do
      nil ->
        query

      tag_id ->
        query
        |> join(:inner, [record], tag in assoc(record, :tags))
        |> where([_record, tag], tag.id == ^tag_id)
    end
  end

  defp filter_payload_term(query, term) do
    case normalize_term(term) do
      "" ->
        query

      term ->
        pattern = "%" <> term <> "%"

        where(
          query,
          [payload],
          fragment("LOWER(?) LIKE ?", payload.name, ^pattern) or
            fragment("LOWER(?) LIKE ?", payload.description, ^pattern) or
            fragment("LOWER(?) LIKE ?", payload.template, ^pattern)
        )
    end
  end

  defp filter_recipe_term(query, term) do
    case normalize_term(term) do
      "" ->
        query

      term ->
        pattern = "%" <> term <> "%"

        where(
          query,
          [recipe],
          fragment("LOWER(?) LIKE ?", recipe.name, ^pattern) or
            fragment("LOWER(?) LIKE ?", recipe.description, ^pattern) or
            fragment("LOWER(?) LIKE ?", recipe.template, ^pattern) or
            fragment("LOWER(?) LIKE ?", recipe.notes, ^pattern)
        )
    end
  end

  defp normalize_term(term) when is_binary(term) do
    term
    |> String.trim()
    |> String.slice(0, Limits.max_search())
    |> String.downcase()
  end

  defp normalize_term(_term), do: ""

  defp insert_payload(attrs, owner_id, source_id, tag_ids) do
    Repo.transaction(fn ->
      changeset =
        %Payload{}
        |> Payload.changeset(attrs)
        |> Ecto.Changeset.put_change(:owner_id, owner_id)
        |> Ecto.Changeset.put_change(:source_payload_id, source_id)

      with {:ok, payload} <- Repo.insert(changeset),
           {:ok, payload} <- replace_tags(payload, &Payload.tags_changeset/2, tag_ids) do
        preload_payload(payload)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp update_payload_record(payload, attrs, nil) do
    payload
    |> Payload.changeset(attrs)
    |> Repo.update()
  end

  defp update_payload_record(payload, attrs, tag_ids) do
    Repo.transaction(fn ->
      with {:ok, payload} <- payload |> Payload.changeset(attrs) |> Repo.update(),
           {:ok, payload} <- replace_tags(payload, &Payload.tags_changeset/2, tag_ids) do
        preload_payload(payload)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_recipe(attrs, owner_id, source_id, tag_ids) do
    Repo.transaction(fn ->
      changeset =
        %Recipe{}
        |> Recipe.changeset(attrs)
        |> Ecto.Changeset.put_change(:owner_id, owner_id)
        |> Ecto.Changeset.put_change(:source_recipe_id, source_id)

      with {:ok, recipe} <- Repo.insert(changeset),
           {:ok, recipe} <- replace_tags(recipe, &Recipe.tags_changeset/2, tag_ids) do
        preload_recipe(recipe)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp update_recipe_record(recipe, attrs, nil) do
    recipe
    |> Recipe.changeset(attrs)
    |> Repo.update()
  end

  defp update_recipe_record(recipe, attrs, tag_ids) do
    Repo.transaction(fn ->
      with {:ok, recipe} <- recipe |> Recipe.changeset(attrs) |> Repo.update(),
           {:ok, recipe} <- replace_tags(recipe, &Recipe.tags_changeset/2, tag_ids) do
        preload_recipe(recipe)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp create_payload_edition(source, owner_id) do
    with :ok <- check_payload_quota(owner_id) do
      source = Repo.preload(source, :tags)

      attrs =
        source
        |> Map.take([
          :name,
          :description,
          :template,
          :target_os,
          :target_shell,
          :target_tools,
          :notes,
          :favorite
        ])
        |> Map.put(:recipe_id, scoped_recipe_id(source.recipe_id, owner_id))

      insert_payload(attrs, owner_id, source.id, Enum.map(source.tags, & &1.id))
    end
  end

  defp create_recipe_edition(source, owner_id) do
    with :ok <- check_recipe_quota(owner_id) do
      source = Repo.preload(source, :tags)

      attrs =
        source
        |> Map.take([
          :name,
          :description,
          :template,
          :variables,
          :steps,
          :notes,
          :favorite,
          :target_os,
          :target_shell,
          :target_tools
        ])
        |> Map.put(:payload_id, scoped_payload_id(source.payload_id, owner_id))

      insert_recipe(attrs, owner_id, source.id, Enum.map(source.tags, & &1.id))
    end
  end

  defp scoped_recipe_id(nil, _owner_id), do: nil

  defp scoped_recipe_id(recipe_id, owner_id) do
    case Repo.get_by(Recipe, owner_id: owner_id, source_recipe_id: recipe_id) do
      nil ->
        case Repo.get(Recipe, recipe_id) do
          %Recipe{owner_id: nil} = recipe -> recipe.id
          _recipe -> nil
        end

      edition ->
        edition.id
    end
  end

  defp scoped_payload_id(nil, _owner_id), do: nil

  defp scoped_payload_id(payload_id, owner_id) do
    case Repo.get_by(Payload, owner_id: owner_id, source_payload_id: payload_id) do
      nil ->
        case Repo.get(Payload, payload_id) do
          %Payload{owner_id: nil} = payload -> payload.id
          _payload -> nil
        end

      edition ->
        edition.id
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    {:ok, Map.new(attrs, fn {key, value} -> {to_string(key), value} end)}
  end

  defp normalize_attrs(_attrs), do: {:error, :invalid_attributes}

  defp normalize_payload_refs(attrs, owner_id) do
    case Map.fetch(attrs, "recipe_id") do
      :error ->
        {:ok, attrs}

      {:ok, recipe_id} ->
        with {:ok, recipe_id} <- accessible_recipe_id(recipe_id, owner_id) do
          {:ok, Map.put(attrs, "recipe_id", recipe_id)}
        end
    end
  end

  defp normalize_recipe_refs(attrs, owner_id) do
    case Map.fetch(attrs, "payload_id") do
      :error ->
        {:ok, attrs}

      {:ok, payload_id} ->
        with {:ok, payload_id} <- accessible_payload_id(payload_id, owner_id) do
          {:ok, Map.put(attrs, "payload_id", payload_id)}
        end
    end
  end

  defp accessible_recipe_id(nil, _owner_id), do: {:ok, nil}
  defp accessible_recipe_id("", _owner_id), do: {:ok, nil}

  defp accessible_recipe_id(recipe_id, owner_id) do
    with {:ok, recipe_id} <- parse_id(recipe_id) do
      case get_recipe(recipe_id, owner_id) do
        nil -> {:error, :unknown_recipe}
        %Recipe{id: id} -> {:ok, id}
      end
    end
  end

  defp accessible_payload_id(nil, _owner_id), do: {:ok, nil}
  defp accessible_payload_id("", _owner_id), do: {:ok, nil}

  defp accessible_payload_id(payload_id, owner_id) do
    with {:ok, payload_id} <- parse_id(payload_id) do
      case get_payload(payload_id, owner_id) do
        nil -> {:error, :unknown_payload}
        %Payload{id: id} -> {:ok, id}
      end
    end
  end

  defp replace_tags(record, _changeset_fun, nil), do: {:ok, record}

  defp replace_tags(record, changeset_fun, tag_ids) do
    case normalize_tag_ids(tag_ids) do
      {:ok, ids} ->
        if length(ids) > Limits.max_tags() do
          {:error, tags_error(record, "may contain at most #{Limits.max_tags()} tags")}
        else
          put_existing_tags(record, changeset_fun, ids)
        end

      {:error, _reason} ->
        {:error, tags_error(record, "must reference existing tags")}
    end
  end

  defp put_existing_tags(record, changeset_fun, ids) do
    tags = Repo.all(from tag in Tag, where: tag.id in ^ids, order_by: [asc: tag.name])

    if length(tags) == length(ids) do
      record
      |> Repo.preload(:tags)
      |> then(&changeset_fun.(&1, tags))
      |> Repo.update()
    else
      {:error, tags_error(record, "must reference existing tags")}
    end
  end

  defp tags_error(record, message) do
    record
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.add_error(:tags, message)
  end

  defp normalize_tag_ids(tag_ids) do
    tag_ids
    |> List.wrap()
    |> Enum.reduce_while({:ok, []}, fn tag_id, {:ok, acc} ->
      case parse_id(tag_id) do
        {:ok, tag_id} -> {:cont, {:ok, [tag_id | acc]}}
        {:error, _reason} -> {:halt, {:error, :invalid_tag}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, ids |> Enum.reverse() |> Enum.uniq()}
      error -> error
    end
  end

  defp parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} when value > 0 -> {:ok, value}
      _other -> {:error, :invalid_id}
    end
  end

  defp parse_id(_id), do: {:error, :invalid_id}

  defp require_owner(nil), do: {:error, :missing_owner}

  defp require_owner(owner_id) when is_binary(owner_id) and byte_size(owner_id) > 0,
    do: {:ok, owner_id}

  defp require_owner(_owner_id), do: {:error, :missing_owner}

  defp check_payload_quota(owner_id) do
    if private_payload_count(owner_id) >= Limits.max_private_editions() do
      {:error, :limit_reached}
    else
      :ok
    end
  end

  defp check_recipe_quota(owner_id) do
    if private_recipe_count(owner_id) >= Limits.max_private_editions() do
      {:error, :limit_reached}
    else
      :ok
    end
  end

  defp owned?(%Payload{owner_id: owner_id}, owner_id) when is_binary(owner_id), do: true
  defp owned?(%Recipe{owner_id: owner_id}, owner_id) when is_binary(owner_id), do: true
  defp owned?(_record, _owner_id), do: false

  defp tag_count, do: Repo.aggregate(Tag, :count, :id)

  defp preload_payload(payload), do: Repo.preload(payload, @payload_preloads)
  defp preload_recipe(recipe), do: Repo.preload(recipe, @recipe_preloads)
end
