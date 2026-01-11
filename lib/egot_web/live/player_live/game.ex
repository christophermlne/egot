defmodule EgotWeb.PlayerLive.Game do
  use EgotWeb, :live_view

  alias Egot.GameSessions

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.confetti_celebration :if={@show_confetti} />

      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-xl sm:text-2xl font-bold">{@session.name}</h1>
          <div class="flex items-center gap-2 mt-1">
            <.status_indicator status={@session.status} />
            <span class="text-base-content/60">Score:</span>
            <span class="font-bold text-lg">{@player.score}</span>
          </div>
        </div>
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
          <.icon name="hero-home" class="size-5" />
        </.link>
      </div>

      <div>
        <div :if={@session.status == :lobby} class="text-center py-16">
          <div class="text-7xl mb-6">&#8987;</div>
          <h2 class="text-2xl sm:text-3xl font-semibold mb-3">Waiting for game to start...</h2>
          <p class="text-base-content/60 text-lg">
            The MC will start the game shortly. Stay tuned!
          </p>
          <div class="mt-8 badge badge-lg badge-info gap-2 py-4 px-6">
            <.icon name="hero-users" class="size-5" />
            {@player_count} player(s) have joined
          </div>
        </div>

        <div :if={@session.status == :in_progress} class="space-y-4">
          <.live_scoreboard leaderboard={@leaderboard} current_player_id={@player.id} />

          <%= cond do %>
            <% @current_category == nil -> %>
              <div class="text-center py-16">
                <div class="text-7xl mb-6">&#9201;</div>
                <h2 class="text-2xl sm:text-3xl font-semibold mb-3">Waiting for Next Category</h2>
                <p class="text-base-content/60 text-lg">
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
              <div class="text-center py-12">
                <div class="alert alert-success mb-6 justify-center">
                  <.icon name="hero-check-circle" class="size-6" />
                  <span class="text-lg">Vote recorded!</span>
                </div>
                <div class="text-7xl mb-6">&#9989;</div>
                <h2 class="text-2xl sm:text-3xl font-semibold mb-3">Vote Submitted</h2>
                <p class="text-base-content/60 text-lg">
                  Waiting for voting to close...
                </p>
              </div>

            <% true -> %>
              <.voting_open_view category={@current_category} />
          <% end %>
        </div>

        <div :if={@session.status == :completed} class="text-center py-12">
          <div class="text-7xl mb-6">&#127881;</div>
          <h2 class="text-2xl sm:text-3xl font-semibold mb-3">Game Complete!</h2>
          <p class="text-base-content/60 text-lg mb-6">
            Thanks for playing!
          </p>
          <div class="stats bg-base-200 shadow mb-8">
            <div class="stat">
              <div class="stat-title">Your Final Score</div>
              <div class="stat-value text-primary">{@player.score}</div>
            </div>
          </div>

          <div :if={@leaderboard != []} class="card bg-base-200 max-w-md mx-auto">
            <div class="card-body">
              <h3 class="card-title justify-center mb-4">
                <.icon name="hero-trophy" class="size-6 text-warning" />
                Final Leaderboard
              </h3>
              <ol class="space-y-3">
                <li
                  :for={{p, idx} <- Enum.with_index(@leaderboard, 1)}
                  class={[
                    "flex justify-between items-center p-3 rounded-lg",
                    p.id == @player.id && "bg-primary/20 font-bold",
                    idx == 1 && "text-warning"
                  ]}
                >
                  <span class="flex items-center gap-2">
                    <span :if={idx == 1}>&#127942;</span>
                    <span :if={idx == 2}>&#129352;</span>
                    <span :if={idx == 3}>&#129353;</span>
                    <span :if={idx > 3} class="w-6 text-center">{idx}.</span>
                    <span class="truncate max-w-[150px]">{p.user.email}</span>
                  </span>
                  <span class="badge badge-lg">{p.score} pts</span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp voting_open_view(assigns) do
    ~H"""
    <div class="card bg-gradient-to-br from-primary/10 to-primary/5 border-2 border-primary/30 p-4 sm:p-6">
      <div class="flex items-center gap-2 mb-2">
        <span class="badge badge-primary badge-sm animate-pulse">VOTING OPEN</span>
      </div>
      <h2 class="text-xl sm:text-2xl font-bold mb-2">{@category.name}</h2>
      <p class="text-base-content/60 mb-6">Tap your prediction:</p>

      <div class="space-y-3">
        <button
          :for={nominee <- @category.nominees}
          phx-click="cast_vote"
          phx-value-nominee_id={nominee.id}
          class="w-full btn btn-outline btn-lg h-auto min-h-16 py-4 justify-start text-left text-base sm:text-lg active:scale-[0.98] transition-transform"
        >
          <span class="line-clamp-2">{nominee.name}</span>
        </button>
      </div>
    </div>
    """
  end

  defp votes_revealed_view(assigns) do
    ~H"""
    <div class="card bg-base-200 p-4 sm:p-6">
      <h2 class="text-xl sm:text-2xl font-bold mb-4">{@category.name}</h2>
      <div class="alert alert-info mb-6 justify-center">
        <.icon name="hero-clock" class="size-5" />
        <span>Votes are in! Waiting for the winner...</span>
      </div>

      <h3 class="font-semibold mb-3 text-base-content/70">Vote Distribution:</h3>
      <div class="space-y-3">
        <div
          :for={nominee <- @category.nominees}
          class={[
            "flex justify-between items-center p-3 rounded-lg bg-base-100",
            @player_vote && @player_vote.nominee_id == nominee.id && "ring-2 ring-primary"
          ]}
        >
          <span class="flex items-center gap-2 flex-1 min-w-0">
            <span class={[
              "truncate",
              @player_vote && @player_vote.nominee_id == nominee.id && "font-bold text-primary"
            ]}>
              {nominee.name}
            </span>
            <span
              :if={@player_vote && @player_vote.nominee_id == nominee.id}
              class="badge badge-primary badge-xs flex-shrink-0"
            >
              YOU
            </span>
          </span>
          <span class="badge badge-lg ml-2">{Map.get(@vote_counts, nominee.id, 0)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp winner_revealed_view(assigns) do
    ~H"""
    <div class="card bg-base-200 p-4 sm:p-6">
      <h2 class="text-xl sm:text-2xl font-bold mb-4">{@category.name}</h2>

      <div :if={@voted_correctly} class="alert alert-success mb-6 winner-announcement">
        <.icon name="hero-star" class="size-6" />
        <span class="text-lg font-semibold">Correct! +1 point!</span>
      </div>
      <div :if={!@voted_correctly} class="alert alert-error mb-6">
        <.icon name="hero-x-circle" class="size-6" />
        <span>Not this time...</span>
      </div>

      <div class="bg-gradient-to-r from-warning/20 to-warning/10 rounded-xl p-4 mb-6">
        <h3 class="font-semibold mb-2 text-base-content/70">Winner:</h3>
        <div class="text-2xl sm:text-3xl font-bold text-warning flex items-center gap-2">
          <span>&#127942;</span>
          <span>{@winner.name}</span>
        </div>
      </div>

      <h3 class="font-semibold mb-3 text-base-content/70">Vote Distribution:</h3>
      <div class="space-y-3">
        <div
          :for={nominee <- @category.nominees}
          class={[
            "flex justify-between items-center p-3 rounded-lg",
            nominee.id == @winner.id && "bg-success/20 ring-2 ring-success",
            nominee.id != @winner.id && "bg-base-100"
          ]}
        >
          <span class="flex items-center gap-2 flex-1 min-w-0">
            <span :if={nominee.id == @winner.id}>&#127942;</span>
            <span class={[
              "truncate",
              nominee.id == @winner.id && "font-bold text-success",
              @player_vote && @player_vote.nominee_id == nominee.id && nominee.id != @winner.id && "text-error"
            ]}>
              {nominee.name}
            </span>
            <span
              :if={@player_vote && @player_vote.nominee_id == nominee.id}
              class={[
                "badge badge-xs flex-shrink-0",
                nominee.id == @winner.id && "badge-success",
                nominee.id != @winner.id && "badge-error"
              ]}
            >
              YOU
            </span>
          </span>
          <span class="badge badge-lg ml-2">{Map.get(@vote_counts, nominee.id, 0)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp confetti_celebration(assigns) do
    colors = ["confetti-gold", "confetti-yellow", "confetti-orange", "confetti-amber", "confetti-white"]
    pieces = for i <- 1..30 do
      %{
        left: "#{:rand.uniform(100)}%",
        delay: "#{:rand.uniform(20) / 10}s",
        color: Enum.at(colors, rem(i, length(colors)))
      }
    end
    assigns = assign(assigns, :pieces, pieces)

    ~H"""
    <div class="confetti-container" id="confetti" phx-hook="Confetti">
      <div
        :for={{piece, idx} <- Enum.with_index(@pieces)}
        class={["confetti-piece", piece.color]}
        style={"left: #{piece.left}; animation-delay: #{piece.delay};"}
      />
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

  defp live_scoreboard(assigns) do
    ~H"""
    <div :if={@leaderboard != []} class="card bg-base-200/50 p-3">
      <div class="flex items-center gap-2 mb-2">
        <.icon name="hero-trophy-mini" class="size-4 text-warning" />
        <span class="text-sm font-semibold">Live Scores</span>
      </div>
      <div class="flex flex-wrap gap-2">
        <div
          :for={{p, idx} <- Enum.with_index(@leaderboard, 1)}
          class={[
            "flex items-center gap-1.5 px-2 py-1 rounded-lg text-sm",
            p.id == @current_player_id && "bg-primary/20 font-bold ring-1 ring-primary/50"
          ]}
        >
          <span class="text-base-content/50 text-xs">{idx}.</span>
          <span class="truncate max-w-[80px] sm:max-w-[100px]">{p.user.email}</span>
          <span class="badge badge-sm badge-ghost">{p.score}</span>
        </div>
      </div>
    </div>
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
          if game_session.status in [:in_progress, :completed] do
            GameSessions.get_leaderboard(id)
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
         |> assign(:leaderboard, leaderboard)
         |> assign(:show_confetti, false)}
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
        {:noreply, assign(socket, :player_vote, vote)}

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
    leaderboard = GameSessions.get_leaderboard(session.id)

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:leaderboard, leaderboard)}
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
     |> assign(:show_confetti, false)}
  end

  def handle_info({:voting_closed, %{category: category}}, socket) do
    if socket.assigns.current_category &&
         socket.assigns.current_category.id == category.id do
      {:noreply,
       assign(socket, :current_category, %{socket.assigns.current_category | status: :voting_closed})}
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

  def handle_info({:winner_revealed, %{category: category, winner: winner, vote_counts: vote_counts}}, socket) do
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
     |> assign(:vote_counts, vote_counts)
     |> assign(:winner_revealed, true)
     |> assign(:voted_correctly, correct)
     |> assign(:show_confetti, correct)}
  end

  def handle_info({:leaderboard_updated, %{leaderboard: leaderboard}}, socket) do
    {:noreply, assign(socket, :leaderboard, leaderboard)}
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
