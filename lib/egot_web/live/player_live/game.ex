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
          &bull; Score: <span class="font-bold">{@player.score}</span>
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

            <% @winner_revealed -> %>
              <.winner_revealed_view
                category={@current_category}
                winner={@winner}
                vote_counts={@vote_counts}
                player_vote={@player_vote}
                voted_correctly={@voted_correctly}
              />

            <% @show_votes -> %>
              <.votes_revealed_view
                category={@current_category}
                vote_counts={@vote_counts}
                player_vote={@player_vote}
              />

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
            Thanks for playing!
          </p>
          <div class="stat bg-base-200 rounded-box p-4 inline-block mb-6">
            <div class="stat-title">Your Final Score</div>
            <div class="stat-value">{@player.score}</div>
          </div>

          <div :if={@leaderboard != []} class="card bg-base-200 max-w-md mx-auto">
            <div class="card-body">
              <h3 class="card-title">Final Leaderboard</h3>
              <ol class="space-y-2">
                <li
                  :for={{p, idx} <- Enum.with_index(@leaderboard, 1)}
                  class={[
                    "flex justify-between",
                    p.id == @player.id && "font-bold text-primary"
                  ]}
                >
                  <span>{idx}. {p.user.email}</span>
                  <span>{p.score} pts</span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp votes_revealed_view(assigns) do
    ~H"""
    <div class="card bg-base-200 p-6">
      <h2 class="text-xl font-bold mb-4">{@category.name}</h2>
      <div class="alert alert-info mb-4">
        <span>Votes are in! Waiting for the winner to be announced...</span>
      </div>

      <h3 class="font-semibold mb-2">Vote Distribution:</h3>
      <div class="space-y-2">
        <div :for={nominee <- @category.nominees} class="flex justify-between items-center">
          <span class={[
            @player_vote && @player_vote.nominee_id == nominee.id && "font-bold text-primary"
          ]}>
            {nominee.name}
            <span :if={@player_vote && @player_vote.nominee_id == nominee.id} class="text-xs ml-1">
              (your pick)
            </span>
          </span>
          <span class="badge badge-lg">{Map.get(@vote_counts, nominee.id, 0)} votes</span>
        </div>
      </div>
    </div>
    """
  end

  defp winner_revealed_view(assigns) do
    ~H"""
    <div class="card bg-base-200 p-6">
      <h2 class="text-xl font-bold mb-4">{@category.name}</h2>

      <div :if={@voted_correctly} class="alert alert-success mb-4">
        <span class="text-xl">&#127881; Correct! +1 point!</span>
      </div>
      <div :if={!@voted_correctly} class="alert alert-error mb-4">
        <span>Not this time...</span>
      </div>

      <h3 class="font-semibold mb-2">Winner:</h3>
      <div class="text-2xl font-bold text-success mb-4">
        &#127942; {@winner.name}
      </div>

      <h3 class="font-semibold mb-2">Vote Distribution:</h3>
      <div class="space-y-2">
        <div :for={nominee <- @category.nominees} class="flex justify-between items-center">
          <span class={[
            nominee.id == @winner.id && "font-bold text-success",
            @player_vote && @player_vote.nominee_id == nominee.id && nominee.id != @winner.id && "text-error"
          ]}>
            {nominee.name}
            <span :if={nominee.id == @winner.id} class="ml-1">&#127942;</span>
            <span :if={@player_vote && @player_vote.nominee_id == nominee.id} class="text-xs ml-1">
              (your pick)
            </span>
          </span>
          <span class="badge badge-lg">{Map.get(@vote_counts, nominee.id, 0)} votes</span>
        </div>
      </div>
    </div>
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

        leaderboard =
          if game_session.status == :completed do
            GameSessions.list_players(id) |> Enum.sort_by(& &1.score, :desc)
          else
            []
          end

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{id}")
        end

        {:ok,
         socket
         |> assign(:session, game_session)
         |> assign(:player, player)
         |> assign(:player_count, player_count)
         |> assign(:current_category, current_category)
         |> assign(:player_vote, player_vote)
         |> assign(:vote_counts, %{})
         |> assign(:show_votes, false)
         |> assign(:winner, nil)
         |> assign(:winner_revealed, false)
         |> assign(:voted_correctly, false)
         |> assign(:leaderboard, leaderboard)}
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
  def handle_info({:session_started, %{session: session}}, socket) do
    {:noreply,
     socket
     |> assign(:session, session)
     |> put_flash(:info, "Game has started!")}
  end

  def handle_info({:voting_opened, %{category: category}}, socket) do
    player_vote = GameSessions.get_vote(socket.assigns.player.id, category.id)

    {:noreply,
     socket
     |> assign(:current_category, category)
     |> assign(:player_vote, player_vote)
     |> assign(:vote_counts, %{})
     |> assign(:show_votes, false)
     |> assign(:winner, nil)
     |> assign(:winner_revealed, false)
     |> assign(:voted_correctly, false)
     |> put_flash(:info, "Voting is now open for: #{category.name}")}
  end

  def handle_info({:voting_closed, %{category: category}}, socket) do
    if socket.assigns.current_category &&
         socket.assigns.current_category.id == category.id do
      {:noreply,
       socket
       |> assign(:current_category, %{socket.assigns.current_category | status: :voting_closed})
       |> put_flash(:info, "Voting is now closed!")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:votes_revealed, %{category: category, vote_counts: vote_counts}}, socket) do
    if socket.assigns.current_category &&
         socket.assigns.current_category.id == category.id do
      {:noreply,
       socket
       |> assign(:current_category, category)
       |> assign(:vote_counts, vote_counts)
       |> assign(:show_votes, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:winner_revealed, %{category: category, winner: winner}}, socket) do
    player = socket.assigns.player
    player_vote = socket.assigns.player_vote

    # Check if player voted correctly
    correct = player_vote && player_vote.nominee_id == winner.id

    # Reload player to get updated score
    updated_player = GameSessions.get_player!(player.user_id, socket.assigns.session.id)

    {:noreply,
     socket
     |> assign(:player, updated_player)
     |> assign(:current_category, category)
     |> assign(:winner, winner)
     |> assign(:winner_revealed, true)
     |> assign(:voted_correctly, correct)}
  end

  def handle_info({:game_ended, %{session: session, leaderboard: leaderboard}}, socket) do
    player = GameSessions.get_player!(socket.assigns.player.user_id, session.id)

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:player, player)
     |> assign(:leaderboard, leaderboard)
     |> assign(:current_category, nil)}
  end

  def handle_info({:player_joined, _player}, socket) do
    player_count = GameSessions.count_players(socket.assigns.session.id)
    {:noreply, assign(socket, :player_count, player_count)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
