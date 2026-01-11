defmodule EgotWeb.PlayerLive.Game do
  use EgotWeb, :live_view

  alias Egot.GameSessions

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@session.name}
        <:subtitle>
          <.status_indicator status={@session.status} />
        </:subtitle>
      </.header>

      <div class="mt-8">
        <div :if={@session.status == :lobby} class="text-center py-12">
          <div class="text-6xl mb-4">&#8987;</div>
          <h2 class="text-2xl font-semibold mb-2">Waiting for game to start...</h2>
          <p class="text-base-content/60">
            The MC will start the game shortly. Stay tuned!
          </p>
          <div class="mt-6 badge badge-lg badge-info">
            {@player_count} player(s) have joined
          </div>
        </div>

        <div :if={@session.status == :in_progress} class="space-y-6">
          <div class="alert alert-success">
            <span>The game is in progress! Voting will appear here.</span>
          </div>
          <p class="text-center text-base-content/60">
            Voting interface coming soon...
          </p>
        </div>

        <div :if={@session.status == :completed} class="text-center py-12">
          <div class="text-6xl mb-4">&#127881;</div>
          <h2 class="text-2xl font-semibold mb-2">Game Complete!</h2>
          <p class="text-base-content/60 mb-4">
            Thanks for playing! Final scores will be displayed here.
          </p>
          <div class="stat bg-base-200 rounded-box p-4 inline-block">
            <div class="stat-title">Your Score</div>
            <div class="stat-value">{@player.score}</div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_indicator(assigns) do
    {text, class} =
      case assigns.status do
        :lobby -> {"Waiting in Lobby", "badge-info"}
        :in_progress -> {"Game in Progress", "badge-success"}
        :completed -> {"Game Completed", "badge-neutral"}
      end

    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"badge #{@class}"}>
      {@text}
    </span>
    """
  end

  @impl true
  def mount(%{"game_session_id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    case GameSessions.get_player(user.id, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You haven't joined this game session.")
         |> redirect(to: ~p"/join")}

      player ->
        game_session = GameSessions.get_session!(id)
        player_count = GameSessions.count_players(id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Egot.PubSub, "game_session:#{id}")
        end

        {:ok,
         socket
         |> assign(:session, game_session)
         |> assign(:player, player)
         |> assign(:player_count, player_count)}
    end
  end

  @impl true
  def handle_info({:session_updated, game_session}, socket) do
    {:noreply, assign(socket, :session, game_session)}
  end

  def handle_info({:player_joined, _player}, socket) do
    player_count = GameSessions.count_players(socket.assigns.session.id)
    {:noreply, assign(socket, :player_count, player_count)}
  end
end
