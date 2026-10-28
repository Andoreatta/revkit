defmodule RevkitWeb.UI do
  @moduledoc """
  Small shared presentation components used across the catalog pages.
  """

  use RevkitWeb, :html

  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  slot :body
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="card border border-dashed border-base-300 bg-base-100">
      <div class="card-body items-center px-6 py-12 text-center">
        <span class="grid size-12 place-items-center rounded-full bg-base-200 text-base-content/60">
          <.icon name={@icon} class="size-6" />
        </span>
        <h3 class="mt-2 text-base font-semibold">{@title}</h3>
        <p :if={@body != []} class="max-w-md text-sm text-base-content/60">
          {render_slot(@body)}
        </p>
        <div :if={@actions != []} class="mt-2 flex flex-wrap justify-center gap-2">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  attr :os, :string, default: nil
  attr :shell, :string, default: nil
  attr :tools, :list, default: []

  def target_badges(assigns) do
    ~H"""
    <div :if={@os || @shell || @tools != []} class="flex flex-wrap items-center gap-1">
      <span :if={@os} class="badge badge-outline badge-sm">{@os}</span>
      <span :if={@shell} class="badge badge-outline badge-sm">{@shell}</span>
      <span :if={@tools != []} class="badge badge-ghost badge-sm">
        tools: {Enum.join(@tools, ", ")}
      </span>
    </div>
    """
  end

  attr :tags, :list, required: true
  attr :selected, :list, default: []
  attr :name, :string, required: true
  attr :id, :string, required: true
  attr :errors, :list, default: []

  def tag_picker(assigns) do
    ~H"""
    <fieldset id={@id} class="fieldset mb-2">
      <legend class="label mb-1">Tags</legend>
      <div class="flex flex-wrap gap-2">
        <label
          :for={tag <- @tags}
          class="label cursor-pointer gap-2 rounded-box border border-base-300 px-3 py-1.5"
        >
          <input
            type="checkbox"
            name={@name}
            value={tag.id}
            checked={tag.id in @selected}
            class="checkbox checkbox-sm checkbox-primary"
          />
          <span class="label-text text-sm">{tag.name}</span>
        </label>
      </div>
      <p class="mt-1 text-xs text-base-content/60">
        Choose up to {Revkit.Limits.max_tags()} tags from the fixed vocabulary.
      </p>
      <p :for={error <- @errors} class="mt-1 text-sm text-error">
        {translate_error(error)}
      </p>
    </fieldset>
    """
  end

  attr :tags, :list, required: true
  attr :empty, :string, default: "—"

  def tag_badges(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-1">
      <span :for={tag <- @tags} class="badge badge-ghost badge-sm">{tag.name}</span>
      <span :if={@tags == []} class="text-xs text-base-content/50">{@empty}</span>
    </div>
    """
  end

  attr :favorite, :boolean, required: true
  attr :id, :any, required: true
  attr :class, :any, default: nil

  def favorite_button(assigns) do
    ~H"""
    <button
      type="button"
      class={["btn btn-ghost btn-sm", @class]}
      phx-click="toggle_favorite"
      phx-value-id={@id}
      aria-label={if @favorite, do: "Remove favorite", else: "Mark favorite"}
      aria-pressed={@favorite}
    >
      <.icon
        name={if @favorite, do: "hero-star-solid", else: "hero-star"}
        class="size-4 text-warning"
      />
    </button>
    """
  end

  attr :content, :string, required: true
  attr :id, :string, default: nil
  attr :class, :any, default: nil

  def code_block(assigns) do
    ~H"""
    <pre
      id={@id}
      class={[
        "max-h-72 overflow-auto whitespace-pre-wrap break-all rounded-box bg-base-200 p-4 font-mono text-xs leading-relaxed",
        @class
      ]}
    >{@content}</pre>
    """
  end
end
