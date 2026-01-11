defmodule EgotWeb.HomeLive do
  use EgotWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[70vh] flex flex-col items-center justify-center text-center px-4">
        <div class="mb-8">
          <h1 class="text-6xl sm:text-7xl font-bold tracking-tight mb-2">
            EGOT
          </h1>
          <p class="text-lg text-base-content/70">
            Award Show Voting Party
          </p>
        </div>

        <p class="text-base-content/60 max-w-md mb-10">
          Predict award show winners with friends! Cast your votes before winners are announced
          and compete for the highest score.
        </p>

        <%= if @current_scope do %>
          <div class="flex flex-col sm:flex-row gap-4 w-full max-w-sm">
            <.button navigate={~p"/join"} class="btn-primary btn-lg flex-1">
              Join Game
            </.button>
            <%= if @current_scope.user.is_mc do %>
              <.button navigate={~p"/mc"} class="btn-outline btn-lg flex-1 whitespace-nowrap">
                MC Dashboard
              </.button>
            <% end %>
          </div>
        <% else %>
          <div class="flex flex-col sm:flex-row gap-4 w-full max-w-xs">
            <.button navigate={~p"/users/log-in"} class="btn-primary btn-lg flex-1">
              Log In
            </.button>
            <.button navigate={~p"/users/register"} class="btn-outline btn-lg flex-1">
              Register
            </.button>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
