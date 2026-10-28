defmodule RevkitWeb.Router do
  use RevkitWeb, :router

  # CSP is set by RevkitWeb.Plugs.ContentSecurityPolicy with a per-request
  # nonce; Sobelow only recognizes put_secure_browser_headers/2.
  # sobelow_skip ["Config.CSP"]
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RevkitWeb.Plugs.Owner
    plug :fetch_live_flash
    plug :put_root_layout, html: {RevkitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RevkitWeb.Plugs.ContentSecurityPolicy
  end

  scope "/", RevkitWeb do
    pipe_through :browser

    get "/health", HealthController, :index

    live_session :catalog, on_mount: [{RevkitWeb.Owner, :default}] do
      live "/", GenerateLive, :index
      live "/generate", GenerateLive, :index

      live "/payloads", PayloadLive.Index, :index
      live "/payloads/new", PayloadLive.Form, :new
      live "/payloads/:id/edit", PayloadLive.Form, :edit
      live "/payloads/:id", PayloadLive.Show, :show

      live "/recipes", RecipeLive.Index, :index
      live "/recipes/new", RecipeLive.Form, :new
      live "/recipes/:id/edit", RecipeLive.Form, :edit
      live "/recipes/:id", RecipeLive.Show, :show

      live "/tags", TagLive.Index, :index
    end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:revkit, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RevkitWeb.Telemetry, csp_nonce_assign_key: :csp_nonce
    end
  end
end
