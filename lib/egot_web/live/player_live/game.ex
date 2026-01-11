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
          <%= cond do %>
            <% @current_category == nil -> %>
              <div class="text-center py-12">
                <div class="text-6xl mb-4">&#9201;</div>
                <h2 class="text-2xl font-semibold mb-2">Waiting for Next Category</h2>
                <p class="text-base-content/60">
                  The MC will open voting for the next category shortly.
                </p>
              </div>

            <% @player_vote != nil -> %>
              <div class="text-center py-8">
                <div class="alert alert-success mb-6">
                  <span>Vote recorded for {@current_category.name}!</span>
                </div>
                <div class="text-6xl mb-4">&#9989;</div>
                <h2 class="text-2xl font-semibold mb-2">Vote Submitted</h2>
                <p class="text-base-content/60">
                  Waiting for voting to close...
                </p>
              </div>

            <% true -> %>
              <div class="card bg-base-200 p-6">
                <h2 class="text-xl font-bold mb-4">{@current_category.name}</h2>
                <p class="text-base-content/60 mb-6">Select your prediction:</p>

                <div class="space-y-3">
                  <button
                    :for={nominee <- @current_category.nominees}
                    phx-click="cast_vote"
                    phx-value-nominee_id={nominee.id}
                    class="w-full btn btn-outline btn-lg justify-start text-left"
                  >
                    {nominee.name}
                  </button>
                </div>
              </div>
          <% end %>
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

        # Get current voting category and player's vote
        {current_category, player_vote} =
          if game_session.status == :in_progress do
            category = GameSessions.get_current_voting_category(id)
            vote = if category, do: GameSessions.get_vote(player.id, category.id), else: nil
            {category, vote}
          else
            {nil, nil}
          end

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Egot.PubSub, "game_session:#{id}")
        end

        {:ok,
         socket
         |> assign(:session, game_session)
         |> assign(:player, player)
         |> assign(:player_count, player_count)
         |> assign(:current_category, current_category)
         |> assign(:player_vote, player_vote)}
    end
  end

  @impl true
  def handle_event("cast_vote", %{"nominee_id" => nominee_id}, socket) do
    player = socket.assigns.player
    category = socket.assigns.current_category

    # Find the nominee
    nominee = Enum.find(category.nominees, &(to_string(&1.id) == nominee_id))

    case GameSessions.cast_vote(player, category, nominee) do
      {:ok, vote} ->
        {:noreply,
         socket
         |> assign(:player_vote, vote)
         |> put_flash(:info, "Vote cast successfully!")}

      {:error, :voting_not_open} ->
        {:noreply, put_flash(socket, :error, "Voting is not open for this category.")}

      {:error, :nominee_not_in_category} ->
        {:noreply, put_flash(socket, :error, "Invalid nominee selection.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "You have already voted in this category.")}
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

  def handle_info({:category_updated, category}, socket) do
    if category.status == :voting_open do
      # New category opened for voting
      player_vote = GameSessions.get_vote(socket.assigns.player.id, category.id)
      category = Egot.Repo.preload(category, :nominees)

      {:noreply,
       socket
       |> assign(:current_category, category)
       |> assign(:player_vote, player_vote)}
    else
      # Category voting closed - clear if it was the current one
      if socket.assigns.current_category && socket.assigns.current_category.id == category.id do
        # Check for next voting category
        next_category = GameSessions.get_current_voting_category(socket.assigns.session.id)

        player_vote =
          if next_category,
            do: GameSessions.get_vote(socket.assigns.player.id, next_category.id),
            else: nil

        {:noreply,
         socket
         |> assign(:current_category, next_category)
         |> assign(:player_vote, player_vote)}
      else
        {:noreply, socket}
      end
    end
  end
end
