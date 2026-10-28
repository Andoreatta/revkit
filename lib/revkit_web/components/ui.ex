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
