defmodule Revkit.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RevkitWeb.Telemetry,
      Revkit.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:revkit, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:revkit, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Revkit.PubSub},
      # Start a worker by calling: Revkit.Worker.start_link(arg)
      # {Revkit.Worker, arg},
      # Start to serve requests, typically the last entry
      RevkitWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Revkit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RevkitWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
