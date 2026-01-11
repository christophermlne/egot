defmodule EgotWeb.MCLive.GameControl do
  use EgotWeb, :live_view

  alias Egot.GameSessions

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@session.name} - Live Control
        <:subtitle>
          <.status_badge status={@session.status} />
          &bull; {@player_count} player(s) connected
        </:subtitle>
        <:actions>
          <.link navigate={~p"/mc/sessions/#{@session.id}"} class="btn btn-ghost btn-sm">
            &larr; Back to Editor
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 space-y-6">
        <%= cond do %>
          <% @session.status == :lobby -> %>
            <.lobby_state session={@session} player_count={@player_count} />

          <% @session.status == :completed -> %>
            <.completed_state leaderboard={@leaderboard} />

          <% @categories == [] -> %>
            <.no_categories_state session={@session} />

          <% @current_category == nil -> %>
            <.all_complete_state />

          <% true -> %>
            <.game_control_panel
              category={@current_category}
              vote_counts={@vote_counts}
              voted_count={@voted_count}
              player_count={@player_count}
              selected_winner={@selected_winner}
              votes_revealed={@votes_revealed}
            />
            <.category_list
              categories={@categories}
              current_id={@current_category.id}
              first_pending_id={first_pending_category_id(@categories)}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp lobby_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="text-6xl mb-4">&#128221;</div>
      <h2 class="text-2xl font-semibold mb-4">Game in Lobby</h2>
      <p class="text-base-content/60 mb-6">
        {@player_count} player(s) have joined. Start the game when ready.
      </p>
      <button phx-click="start_game" class="btn btn-primary btn-lg">
        Start Game
      </button>
    </div>
    """
  end

  defp completed_state(assigns) do
    ~H"""
    <div class="text-center py-8">
      <div class="text-6xl mb-4">&#127881;</div>
      <h2 class="text-2xl font-semibold mb-4">Game Complete!</h2>
      <div class="card bg-base-200 max-w-md mx-auto">
        <div class="card-body">
          <h3 class="card-title">Final Leaderboard</h3>
          <div :if={@leaderboard == []} class="text-base-content/60">
            No players in this session.
          </div>
          <ol class="space-y-2">
            <li :for={{player, idx} <- Enum.with_index(@leaderboard, 1)} class="flex justify-between">
              <span>{idx}. {player.user.email}</span>
              <span class="font-bold">{player.score} pts</span>
            </li>
          </ol>
        </div>
      </div>
    </div>
    """
  end

  defp no_categories_state(assigns) do
    ~H"""
    <div class="alert alert-warning">
      <span>No categories configured.</span>
      <.link navigate={~p"/mc/sessions/#{@session.id}"} class="btn btn-sm">
        Return to Session Editor
      </.link>
    </div>
    """
  end

  defp all_complete_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="text-6xl mb-4">&#9989;</div>
      <h2 class="text-2xl font-semibold mb-4">All Categories Complete</h2>
      <button phx-click="end_game" class="btn btn-primary btn-lg">
        End Game & Show Final Scores
      </button>
    </div>
    """
  end

  defp game_control_panel(assigns) do
    ~H"""
    <div class="card bg-primary/10 border-2 border-primary p-6">
      <div class="flex justify-between items-start mb-4">
        <div>
          <h2 class="text-2xl font-bold">{@category.name}</h2>
          <p class="text-base-content/60">
            Status: <.category_status_badge status={@category.status} />
          </p>
        </div>
        <div class="text-right">
          <div class="text-lg">
            <span class="font-bold">{@voted_count}</span> / {@player_count} voted
          </div>
        </div>
      </div>

      <!-- Vote counts (shown after votes revealed) -->
      <div :if={@votes_revealed || @category.status == :revealed} class="mb-6">
        <h3 class="font-semibold mb-2">Vote Distribution:</h3>
        <div class="space-y-2">
          <div :for={nominee <- @category.nominees} class="flex justify-between items-center">
            <span class={[
              @category.winner && @category.winner.id == nominee.id && "font-bold text-success"
            ]}>
              {nominee.name}
              <span :if={@category.winner && @category.winner.id == nominee.id} class="ml-2">
                &#127942;
              </span>
            </span>
            <span class="badge badge-lg">{Map.get(@vote_counts, nominee.id, 0)} votes</span>
          </div>
        </div>
      </div>

      <!-- Winner selection (shown after votes revealed, before winner revealed) -->
      <form :if={@votes_revealed && @category.status == :voting_closed} phx-change="select_winner" class="mb-6">
        <label class="label font-semibold">Select the Actual Winner:</label>
        <select class="select select-bordered w-full" name="winner_id">
          <option value="">-- Select the winner announced on TV --</option>
          <option :for={nominee <- @category.nominees} value={nominee.id} selected={@selected_winner && @selected_winner.id == nominee.id}>
            {nominee.name}
          </option>
        </select>
      </form>

      <!-- Control buttons -->
      <div class="flex flex-wrap gap-3">
        <button
          :if={@category.status == :pending}
          phx-click="open_voting"
          class="btn btn-success"
        >
          Open Voting
        </button>

        <button
          :if={@category.status == :voting_open}
          phx-click="close_voting"
          class="btn btn-warning"
        >
          Close Voting
        </button>

        <button
          :if={@category.status == :voting_open}
          phx-click="cancel_voting"
          class="btn btn-error btn-outline"
          data-confirm="This will delete all votes for this category and return it to pending status. Are you sure?"
        >
          Cancel Voting
        </button>

        <button
          :if={@category.status == :voting_closed && !@votes_revealed}
          phx-click="reveal_votes"
          class="btn btn-info"
        >
          Reveal Votes
        </button>

        <button
          :if={@category.status == :voting_closed && @votes_revealed && @selected_winner}
          phx-click="reveal_winner"
          class="btn btn-primary"
        >
          Reveal Winner
        </button>

        <button
          :if={@category.status == :revealed}
          phx-click="next_category"
          class="btn btn-primary"
        >
          Next Category
        </button>
      </div>
    </div>
    """
  end

  defp category_list(assigns) do
    ~H"""
    <div class="space-y-2">
      <h3 class="font-semibold">All Categories:</h3>
      <div
        :for={{cat, index} <- Enum.with_index(@categories)}
        class={[
          "card p-3",
          cat.id == @current_id && "bg-primary/10 border border-primary",
          cat.id != @current_id && "bg-base-200"
        ]}
      >
        <div class="flex justify-between items-center gap-2">
          <span class="flex-1">{cat.name}</span>
          <div class="flex items-center gap-1">
            <button
              :if={cat.status == :pending && cat.id != @first_pending_id}
              phx-click="queue_next"
              phx-value-id={cat.id}
              class="btn btn-xs btn-secondary"
              title="Queue as next category"
            >
              Queue Next
            </button>
            <button
              :if={index > 0}
              phx-click="move_category_up"
              phx-value-id={cat.id}
              class="btn btn-xs btn-ghost"
              title="Move up"
            >
              &uarr;
            </button>
            <button
              :if={index < length(@categories) - 1}
              phx-click="move_category_down"
              phx-value-id={cat.id}
              class="btn btn-xs btn-ghost"
              title="Move down"
            >
              &darr;
            </button>
            <.category_status_badge status={cat.status} />
          </div>
        </div>
        <div :if={cat.winner} class="text-sm text-success mt-1">
          Winner: {cat.winner.name}
        </div>
      </div>
    </div>
    """
  end

  defp first_pending_category_id(categories) do
    case Enum.find(categories, &(&1.status == :pending)) do
      nil -> nil
      category -> category.id
    end
  end

  defp status_badge(assigns) do
    {text, class} =
      case assigns.status do
        :lobby -> {"Lobby", "badge-info"}
        :in_progress -> {"In Progress", "badge-success"}
        :completed -> {"Completed", "badge-neutral"}
      end

    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"badge #{@class}"}>{@text}</span>
    """
  end

  defp category_status_badge(assigns) do
    {text, class} =
      case assigns.status do
        :pending -> {"Pending", "badge-ghost"}
        :voting_open -> {"Voting Open", "badge-success"}
        :voting_closed -> {"Voting Closed", "badge-warning"}
        :revealed -> {"Complete", "badge-info"}
      end

    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"badge #{@class}"}>{@text}</span>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    session = GameSessions.get_session!(id)

    # Verify ownership
    if session.created_by_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this session.")
       |> redirect(to: ~p"/mc")}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{id}")
      end

      {:ok, load_game_state(socket, session)}
    end
  end

  defp load_game_state(socket, session) do
    categories = GameSessions.get_categories_with_status(session.id)
    current_category = GameSessions.get_current_category_for_mc(session.id)
    player_count = GameSessions.count_players(session.id)

    {vote_counts, voted_count} =
      if current_category do
        {
          GameSessions.count_votes_by_nominee(current_category.id),
          GameSessions.count_votes_for_category(current_category.id)
        }
      else
        {%{}, 0}
      end

    leaderboard =
      if session.status == :completed do
        GameSessions.list_players(session.id) |> Enum.sort_by(& &1.score, :desc)
      else
        []
      end

    socket
    |> assign(:session, session)
    |> assign(:categories, categories)
    |> assign(:current_category, current_category)
    |> assign(:player_count, player_count)
    |> assign(:vote_counts, vote_counts)
    |> assign(:voted_count, voted_count)
    |> assign(:selected_winner, nil)
    |> assign(:votes_revealed, false)
    |> assign(:leaderboard, leaderboard)
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    session = socket.assigns.session

    case GameSessions.update_session_status(session, :in_progress) do
      {:ok, session} ->
        # Broadcast session started
        Phoenix.PubSub.broadcast(
          Egot.PubSub,
          "game:#{session.id}",
          {:session_started, %{session: session}}
        )

        {:noreply, load_game_state(socket, session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start game.")}
    end
  end

  def handle_event("open_voting", _params, socket) do
    category = socket.assigns.current_category

    case GameSessions.open_voting(category) do
      {:ok, category} ->
        categories = update_category_in_list(socket.assigns.categories, category)

        socket =
          socket
          |> assign(:current_category, category)
          |> assign(:categories, categories)
          |> assign(:votes_revealed, false)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to open voting.")}
    end
  end

  def handle_event("close_voting", _params, socket) do
    category = socket.assigns.current_category

    case GameSessions.close_voting(category) do
      {:ok, category} ->
        category = Egot.Repo.preload(category, [:nominees, :winner])
        vote_counts = GameSessions.count_votes_by_nominee(category.id)
        categories = update_category_in_list(socket.assigns.categories, category)

        socket =
          socket
          |> assign(:current_category, category)
          |> assign(:vote_counts, vote_counts)
          |> assign(:categories, categories)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to close voting.")}
    end
  end

  def handle_event("cancel_voting", _params, socket) do
    category = socket.assigns.current_category

    case GameSessions.cancel_voting(category) do
      {:ok, category} ->
        category = Egot.Repo.preload(category, [:nominees, :winner])
        categories = update_category_in_list(socket.assigns.categories, category)

        socket =
          socket
          |> assign(:current_category, category)
          |> assign(:categories, categories)
          |> assign(:vote_counts, %{})
          |> assign(:voted_count, 0)
          |> assign(:votes_revealed, false)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel voting.")}
    end
  end

  def handle_event("reveal_votes", _params, socket) do
    category = socket.assigns.current_category

    case GameSessions.reveal_votes(category) do
      {:ok, category, vote_counts} ->
        category = Egot.Repo.preload(category, [:nominees, :winner])

        socket =
          socket
          |> assign(:current_category, category)
          |> assign(:vote_counts, vote_counts)
          |> assign(:votes_revealed, true)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reveal votes.")}
    end
  end

  def handle_event("select_winner", %{"winner_id" => winner_id}, socket) do
    selected =
      if winner_id == "" do
        nil
      else
        Enum.find(
          socket.assigns.current_category.nominees,
          &(to_string(&1.id) == winner_id)
        )
      end

    {:noreply, assign(socket, :selected_winner, selected)}
  end

  def handle_event("reveal_winner", _params, socket) do
    category = socket.assigns.current_category
    winner = socket.assigns.selected_winner

    case GameSessions.reveal_winner(category, winner) do
      {:ok, category} ->
        categories = update_category_in_list(socket.assigns.categories, category)

        socket =
          socket
          |> assign(:current_category, category)
          |> assign(:categories, categories)
          |> assign(:selected_winner, nil)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reveal winner.")}
    end
  end

  def handle_event("next_category", _params, socket) do
    session_id = socket.assigns.session.id

    case GameSessions.advance_to_next_category(session_id) do
      {:ok, category} ->
        categories = GameSessions.get_categories_with_status(session_id)

        socket =
          socket
          |> assign(:current_category, category)
          |> assign(:categories, categories)
          |> assign(:vote_counts, %{})
          |> assign(:voted_count, 0)
          |> assign(:selected_winner, nil)
          |> assign(:votes_revealed, false)

        {:noreply, socket}

      {:error, :no_more_categories} ->
        {:noreply, assign(socket, :current_category, nil)}
    end
  end

  def handle_event("end_game", _params, socket) do
    session = socket.assigns.session

    case GameSessions.end_game(session) do
      {:ok, session} ->
        {:noreply, load_game_state(socket, session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to end game.")}
    end
  end

  def handle_event("move_category_up", %{"id" => id}, socket) do
    reorder_category(socket, String.to_integer(id), :up)
  end

  def handle_event("move_category_down", %{"id" => id}, socket) do
    reorder_category(socket, String.to_integer(id), :down)
  end

  def handle_event("queue_next", %{"id" => id}, socket) do
    category_id = String.to_integer(id)
    session_id = socket.assigns.session.id

    case GameSessions.queue_category_next(session_id, category_id) do
      {:ok, _} ->
        categories = GameSessions.get_categories_with_status(session_id)
        {:noreply, assign(socket, :categories, categories)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to queue category.")}
    end
  end

  defp reorder_category(socket, category_id, direction) do
    categories = socket.assigns.categories
    index = Enum.find_index(categories, &(&1.id == category_id))

    new_index =
      case direction do
        :up -> max(0, index - 1)
        :down -> min(length(categories) - 1, index + 1)
      end

    if new_index != index do
      category_ids =
        categories
        |> Enum.map(& &1.id)
        |> List.delete_at(index)
        |> List.insert_at(new_index, category_id)

      GameSessions.reorder_categories(socket.assigns.session.id, category_ids)
      categories = GameSessions.get_categories_with_status(socket.assigns.session.id)
      {:noreply, assign(socket, :categories, categories)}
    else
      {:noreply, socket}
    end
  end

  # Handle PubSub messages (for vote updates from players)
  @impl true
  def handle_info({:vote_cast, %{category_id: category_id}}, socket) do
    if socket.assigns.current_category &&
         socket.assigns.current_category.id == category_id do
      vote_counts = GameSessions.count_votes_by_nominee(category_id)
      voted_count = GameSessions.count_votes_for_category(category_id)

      {:noreply,
       socket
       |> assign(:vote_counts, vote_counts)
       |> assign(:voted_count, voted_count)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:player_joined, _}, socket) do
    player_count = GameSessions.count_players(socket.assigns.session.id)
    {:noreply, assign(socket, :player_count, player_count)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_category_in_list(categories, updated_category) do
    # Preload associations to ensure winner is always available
    updated_category = Egot.Repo.preload(updated_category, [:nominees, :winner])

    Enum.map(categories, fn cat ->
      if cat.id == updated_category.id do
        updated_category
      else
        cat
      end
    end)
  end
end
