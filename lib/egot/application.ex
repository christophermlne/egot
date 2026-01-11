defmodule Egot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EgotWeb.Telemetry,
      Egot.Repo,
      {DNSCluster, query: Application.get_env(:egot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Egot.PubSub},
      # Start a worker by calling: Egot.Worker.start_link(arg)
      # {Egot.Worker, arg},
      # Start to serve requests, typically the last entry
      EgotWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Egot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EgotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
