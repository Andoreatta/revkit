defmodule RevkitWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use RevkitWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current, :atom,
    default: nil,
    doc: "the active navigation item: :generate, :payloads, :recipes, or :tags"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-box focus:bg-base-100 focus:px-4 focus:py-2 focus:shadow-lg"
    >
      Skip to content
    </a>

    <header class="sticky top-0 z-40 border-b border-base-300 bg-base-100/95 backdrop-blur">
      <div class="mx-auto flex h-16 max-w-7xl items-center gap-3 px-4 sm:px-6 lg:px-8">
        <a href={~p"/"} class="flex min-w-0 items-center gap-2.5" aria-label="RevKit home">
          <img src={~p"/images/logo.svg"} class="size-9 shrink-0" alt="" />
          <span class="text-base font-semibold tracking-tight">RevKit</span>
          <span class="hidden text-xs text-base-content/50 md:inline">Payload Studio</span>
        </a>

        <nav class="ml-auto hidden items-center gap-1 lg:flex" aria-label="Main navigation">
          <.nav_link navigate={~p"/"} current={@current == :generate}>Generate</.nav_link>
          <.nav_link navigate={~p"/payloads"} current={@current == :payloads}>Payloads</.nav_link>
          <.nav_link navigate={~p"/recipes"} current={@current == :recipes}>Recipes</.nav_link>
          <.nav_link navigate={~p"/tags"} current={@current == :tags}>Tags</.nav_link>
        </nav>

        <div class="ml-auto flex items-center gap-2 lg:ml-0">
          <div class="hidden lg:block">
            <.theme_toggle />
          </div>

          <div class="dropdown dropdown-end lg:hidden">
            <button
              type="button"
              tabindex="0"
              class="btn btn-ghost btn-sm"
              aria-label="Open navigation"
            >
              <.icon name="hero-bars-3" class="size-5" />
            </button>
            <ul
              tabindex="0"
              class="menu dropdown-content z-50 mt-3 w-56 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
            >
              <li>
                <.mobile_link navigate={~p"/"} current={@current == :generate}>Generate</.mobile_link>
              </li>
              <li>
                <.mobile_link navigate={~p"/payloads"} current={@current == :payloads}>
                  Payloads
                </.mobile_link>
              </li>
              <li>
                <.mobile_link navigate={~p"/recipes"} current={@current == :recipes}>
                  Recipes
                </.mobile_link>
              </li>
              <li>
                <.mobile_link navigate={~p"/tags"} current={@current == :tags}>Tags</.mobile_link>
              </li>
              <li class="menu-title">Theme</li>
              <li class="px-2 py-1">
                <.theme_toggle />
              </li>
            </ul>
          </div>
        </div>
      </div>
    </header>

    <main
      id="main-content"
      class="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6 sm:py-8 lg:px-8 lg:py-10"
    >
      {render_slot(@inner_block)}
    </main>

    <footer class="border-t border-base-300 bg-base-100">
      <div class="mx-auto flex max-w-7xl flex-col gap-1 px-4 py-6 text-xs text-base-content/60 sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
        <p>
          <span class="font-semibold text-base-content">RevKit</span>
          · payload studio for authorized testing.
        </p>
        <p>Generates strings only. Nothing is executed.</p>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  attr :navigate, :any, required: true
  attr :current, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      aria-current={if @current, do: "page", else: nil}
      class={["btn btn-ghost btn-sm", @current && "btn-active"]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :navigate, :any, required: true
  attr :current, :boolean, default: false
  slot :inner_block, required: true

  defp mobile_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      aria-current={if @current, do: "page", else: nil}
      class={["rounded-box px-3 py-2 text-sm", @current && "bg-base-200 font-semibold"]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
