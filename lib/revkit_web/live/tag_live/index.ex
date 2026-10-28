defmodule RevkitWeb.TagLive.Index do
  use RevkitWeb, :live_view

  alias Revkit.Catalog
  alias Revkit.Catalog.Tag

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       tags: Catalog.list_tags(),
       new_form: to_form(Tag.changeset(%Tag{}, %{}))
     )}
  end

  @impl true
  def handle_event("create", %{"tag" => params}, socket) do
    case Catalog.create_tag(params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag created")
         |> assign(tags: Catalog.list_tags(), new_form: to_form(Tag.changeset(%Tag{}, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, new_form: to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def handle_event("rename", %{"tag_id" => id, "tag" => params}, socket) do
    tag = Catalog.get_tag!(id)

    case Catalog.update_tag(tag, params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag renamed")
         |> assign(tags: Catalog.list_tags())}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, tag_error(changeset))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tag = Catalog.get_tag!(id)

    case Catalog.delete_tag(tag) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag deleted")
         |> assign(tags: Catalog.list_tags())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete tag")}
    end
  end

  defp tag_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map_join(", ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end
end
