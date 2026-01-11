defmodule Egot.GameSessions do
  @moduledoc """
  The GameSessions context.
  """

  import Ecto.Query, warn: false
  alias Egot.Repo
  alias Egot.GameSessions.GameSession
  alias Egot.GameSessions.Category
  alias Egot.GameSessions.Nominee
  alias Egot.GameSessions.Player
  alias Egot.GameSessions.Vote

  # -------------------------------------------------------------------
  # PubSub Helpers
  # -------------------------------------------------------------------

  defp game_topic(game_session_id), do: "game:#{game_session_id}"

  defp broadcast(game_session_id, event, payload) do
    Phoenix.PubSub.broadcast(Egot.PubSub, game_topic(game_session_id), {event, payload})
  end

  @doc """
  Returns the list of game sessions created by a specific user.
  """
  def list_sessions_by_user(user_id) do
    GameSession
    |> where([gs], gs.created_by_id == ^user_id)
    |> order_by([gs], desc: gs.inserted_at, desc: gs.id)
    |> Repo.all()
  end

  @doc """
  Gets a single game_session.

  Raises `Ecto.NoResultsError` if the Game session does not exist.
  """
  def get_session!(id), do: Repo.get!(GameSession, id)

  @doc """
  Gets a game session by join code (case-insensitive).
  """
  def get_session_by_join_code(join_code) when is_binary(join_code) do
    join_code = String.upcase(join_code)
    Repo.get_by(GameSession, join_code: join_code)
  end

  @doc """
  Creates a game session with retry logic for join code collisions.
  """
  def create_session(attrs \\ %{}) do
    create_session_with_retry(attrs, 3)
  end

  defp create_session_with_retry(_attrs, 0) do
    {:error, :join_code_collision}
  end

  defp create_session_with_retry(attrs, attempts) do
    result =
      %GameSession{}
      |> GameSession.create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, session} ->
        {:ok, session}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :join_code) do
          # Join code collision - retry with new code
          create_session_with_retry(attrs, attempts - 1)
        else
          {:error, changeset}
        end
    end
  end

  @doc """
  Updates a game session's status.
  """
  def update_session_status(%GameSession{} = game_session, status) do
    game_session
    |> GameSession.status_changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game session changes.
  """
  def change_session(%GameSession{} = game_session, attrs \\ %{}) do
    GameSession.create_changeset(game_session, attrs)
  end

  @doc """
  Deletes a game session.
  """
  def delete_session(%GameSession{} = game_session) do
    Repo.delete(game_session)
  end

  @doc """
  Gets a game session with categories and nominees preloaded.
  """
  def get_session_with_categories!(id) do
    GameSession
    |> Repo.get!(id)
    |> Repo.preload(categories: {from(c in Category, order_by: c.display_order), :nominees})
  end

  # -------------------------------------------------------------------
  # Categories
  # -------------------------------------------------------------------

  @doc """
  Lists categories for a game session, ordered by display_order.
  """
  def list_categories(game_session_id) do
    Category
    |> where([c], c.game_session_id == ^game_session_id)
    |> order_by([c], asc: c.display_order)
    |> Repo.all()
    |> Repo.preload(:nominees)
  end

  @doc """
  Gets a single category.

  Raises `Ecto.NoResultsError` if the Category does not exist.
  """
  def get_category!(id), do: Repo.get!(Category, id)

  @doc """
  Creates a category for a game session.
  Auto-assigns display_order to be after the last category.
  """
  def create_category(game_session_id, attrs \\ %{}) do
    # Get the next display_order
    max_order =
      Category
      |> where([c], c.game_session_id == ^game_session_id)
      |> select([c], max(c.display_order))
      |> Repo.one() || -1

    # Ensure consistent key types by converting to string keys
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("game_session_id", game_session_id)
      |> Map.put_new("display_order", max_order + 1)

    %Category{}
    |> Category.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category.
  """
  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.
  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.update_changeset(category, attrs)
  end

  @doc """
  Reorders categories by setting display_order based on the given list of category IDs.
  """
  def reorder_categories(game_session_id, category_ids) when is_list(category_ids) do
    Repo.transaction(fn ->
      category_ids
      |> Enum.with_index()
      |> Enum.each(fn {category_id, index} ->
        Category
        |> where([c], c.id == ^category_id and c.game_session_id == ^game_session_id)
        |> Repo.update_all(set: [display_order: index])
      end)
    end)
  end

  @doc """
  Queues a category to be next by moving it to the first position among pending categories.
  Categories that have already been played (non-pending) remain in their positions.
  """
  def queue_category_next(game_session_id, category_id) do
    categories =
      Category
      |> where([c], c.game_session_id == ^game_session_id)
      |> order_by([c], asc: c.display_order)
      |> Repo.all()

    # Split into non-pending (already played) and pending categories
    {played, pending} = Enum.split_while(categories, &(&1.status != :pending))

    # Remove target from pending and add it at the front
    pending_without_target = Enum.reject(pending, &(&1.id == category_id))
    target = Enum.find(pending, &(&1.id == category_id))

    if target do
      new_order = played ++ [target | pending_without_target]
      category_ids = Enum.map(new_order, & &1.id)
      reorder_categories(game_session_id, category_ids)
    else
      {:error, :category_not_pending}
    end
  end

  # -------------------------------------------------------------------
  # Nominees
  # -------------------------------------------------------------------

  @doc """
  Lists nominees for a category.
  """
  def list_nominees(category_id) do
    Nominee
    |> where([n], n.category_id == ^category_id)
    |> order_by([n], asc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single nominee.

  Raises `Ecto.NoResultsError` if the Nominee does not exist.
  """
  def get_nominee!(id), do: Repo.get!(Nominee, id)

  @doc """
  Creates a nominee for a category.
  """
  def create_nominee(category_id, attrs \\ %{}) do
    # Ensure consistent key types by converting to string keys
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("category_id", category_id)

    %Nominee{}
    |> Nominee.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a nominee.
  """
  def update_nominee(%Nominee{} = nominee, attrs) do
    nominee
    |> Nominee.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a nominee.
  """
  def delete_nominee(%Nominee{} = nominee) do
    Repo.delete(nominee)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking nominee changes.
  """
  def change_nominee(%Nominee{} = nominee, attrs \\ %{}) do
    Nominee.changeset(nominee, attrs)
  end

  # Converts all atom keys in a map to string keys
  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  # -------------------------------------------------------------------
  # Players
  # -------------------------------------------------------------------

  @doc """
  Gets a player by user_id and game_session_id.
  Returns nil if the player doesn't exist.
  """
  def get_player(user_id, game_session_id) do
    Repo.get_by(Player, user_id: user_id, game_session_id: game_session_id)
  end

  @doc """
  Gets a player by user_id and game_session_id.
  Raises `Ecto.NoResultsError` if the Player does not exist.
  """
  def get_player!(user_id, game_session_id) do
    Player
    |> where([p], p.user_id == ^user_id and p.game_session_id == ^game_session_id)
    |> Repo.one!()
  end

  @doc """
  Creates a player (joins a user to a game session).
  Returns error if session is not in lobby status.
  """
  def join_session(%{id: user_id}, %GameSession{id: game_session_id, status: status}) do
    if status != :lobby do
      {:error, :session_not_joinable}
    else
      attrs = %{user_id: user_id, game_session_id: game_session_id}

      %Player{}
      |> Player.create_changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Lists all players for a game session.
  """
  def list_players(game_session_id) do
    Player
    |> where([p], p.game_session_id == ^game_session_id)
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Counts players in a game session.
  """
  def count_players(game_session_id) do
    Player
    |> where([p], p.game_session_id == ^game_session_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Updates a player's score.
  """
  def update_player_score(%Player{} = player, score) do
    player
    |> Player.score_changeset(%{score: score})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking player changes.
  """
  def change_player(%Player{} = player, attrs \\ %{}) do
    Player.create_changeset(player, attrs)
  end

  @doc """
  Returns the leaderboard (players sorted by score descending) for a game session.
  """
  def get_leaderboard(game_session_id) do
    list_players(game_session_id) |> Enum.sort_by(& &1.score, :desc)
  end

  # -------------------------------------------------------------------
  # Votes
  # -------------------------------------------------------------------

  @doc """
  Casts a vote for a nominee in a category.
  Returns error if category is not voting_open or if player already voted.
  """
  def cast_vote(
        %Player{id: player_id},
        %Category{id: category_id, status: status, game_session_id: game_session_id},
        %Nominee{id: nominee_id, category_id: nominee_category_id}
      ) do
    cond do
      status != :voting_open ->
        {:error, :voting_not_open}

      nominee_category_id != category_id ->
        {:error, :nominee_not_in_category}

      true ->
        attrs = %{player_id: player_id, category_id: category_id, nominee_id: nominee_id}

        case %Vote{} |> Vote.changeset(attrs) |> Repo.insert() do
          {:ok, vote} ->
            broadcast(game_session_id, :vote_cast, %{category_id: category_id})
            {:ok, vote}

          error ->
            error
        end
    end
  end

  @doc """
  Gets a player's vote for a specific category.
  Returns nil if the player hasn't voted in that category.
  """
  def get_vote(player_id, category_id) do
    Repo.get_by(Vote, player_id: player_id, category_id: category_id)
  end

  @doc """
  Lists all votes for a category, optionally preloading associations.
  """
  def list_votes_for_category(category_id, opts \\ []) do
    query = from(v in Vote, where: v.category_id == ^category_id)

    query =
      if opts[:preload] do
        from(v in query, preload: ^opts[:preload])
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Counts votes for each nominee in a category.
  Returns a map of %{nominee_id => count}.
  """
  def count_votes_by_nominee(category_id) do
    Vote
    |> where([v], v.category_id == ^category_id)
    |> group_by([v], v.nominee_id)
    |> select([v], {v.nominee_id, count(v.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets the current voting category for a game session.
  Returns the first category with status :voting_open, or nil if none.
  """
  def get_current_voting_category(game_session_id) do
    Category
    |> where([c], c.game_session_id == ^game_session_id and c.status == :voting_open)
    |> order_by([c], asc: c.display_order)
    |> limit(1)
    |> Repo.one()
    |> maybe_preload_nominees()
  end

  defp maybe_preload_nominees(nil), do: nil
  defp maybe_preload_nominees(category), do: Repo.preload(category, :nominees)

  @doc """
  Updates a category's status.
  """
  def update_category_status(%Category{} = category, status) do
    category
    |> Category.status_changeset(%{status: status})
    |> Repo.update()
  end

  # -------------------------------------------------------------------
  # Game Control (MC Live View Operations)
  # -------------------------------------------------------------------

  @doc """
  Opens voting for a category and broadcasts the event.
  """
  def open_voting(%Category{} = category) do
    with {:ok, category} <- update_category_status(category, :voting_open) do
      category = Repo.preload(category, :nominees)
      broadcast(category.game_session_id, :voting_opened, %{category: category})
      {:ok, category}
    end
  end

  @doc """
  Closes voting for a category and broadcasts the event.
  """
  def close_voting(%Category{} = category) do
    with {:ok, category} <- update_category_status(category, :voting_closed) do
      broadcast(category.game_session_id, :voting_closed, %{category: category})
      {:ok, category}
    end
  end

  @doc """
  Cancels voting for a category, deletes all votes, and returns it to pending status.
  Broadcasts the event so players can reset their UI.
  """
  def cancel_voting(%Category{} = category) do
    Repo.transaction(fn ->
      # Delete all votes for this category
      Vote
      |> where([v], v.category_id == ^category.id)
      |> Repo.delete_all()

      # Reset status to pending
      {:ok, category} = update_category_status(category, :pending)

      category = Repo.preload(category, :nominees)
      broadcast(category.game_session_id, :voting_canceled, %{category: category})

      category
    end)
  end

  @doc """
  Checks if a category can be edited (only pending categories can be edited).
  """
  def can_edit_category?(%Category{status: :pending}), do: true
  def can_edit_category?(%Category{}), do: false

  @doc """
  Reveals the votes for a category (shows vote distribution to all players).
  """
  def reveal_votes(%Category{} = category) do
    vote_counts = count_votes_by_nominee(category.id)
    category = Repo.preload(category, :nominees)
    broadcast(category.game_session_id, :votes_revealed, %{category: category, vote_counts: vote_counts})
    {:ok, category, vote_counts}
  end

  @doc """
  Sets the winner for a category, updates scores, and broadcasts the event.
  """
  def reveal_winner(%Category{} = category, %Nominee{} = winner) do
    Repo.transaction(fn ->
      # Set winner
      {:ok, category} =
        category
        |> Category.winner_changeset(%{winner_nominee_id: winner.id})
        |> Repo.update()

      # Update status to revealed
      {:ok, category} = update_category_status(category, :revealed)

      # Update scores for correct voters
      update_scores_for_category(category.id, winner.id)

      # Get vote counts to include in broadcast
      vote_counts = count_votes_by_nominee(category.id)

      category = Repo.preload(category, [:winner, :nominees])
      broadcast(category.game_session_id, :winner_revealed, %{
        category: category,
        winner: winner,
        vote_counts: vote_counts
      })

      # Broadcast updated leaderboard after scores change
      leaderboard = get_leaderboard(category.game_session_id)
      broadcast(category.game_session_id, :leaderboard_updated, %{leaderboard: leaderboard})

      category
    end)
  end

  defp update_scores_for_category(category_id, winner_nominee_id) do
    from(p in Player,
      join: v in Vote,
      on: v.player_id == p.id,
      where: v.category_id == ^category_id and v.nominee_id == ^winner_nominee_id
    )
    |> Repo.update_all(inc: [score: 1])
  end

  @doc """
  Advances to the next category and opens voting.
  Returns {:ok, category} or {:error, :no_more_categories}.
  """
  def advance_to_next_category(game_session_id) do
    next_category =
      Category
      |> where([c], c.game_session_id == ^game_session_id and c.status == :pending)
      |> order_by([c], asc: c.display_order)
      |> limit(1)
      |> Repo.one()

    case next_category do
      nil ->
        {:error, :no_more_categories}

      category ->
        open_voting(category)
    end
  end

  @doc """
  Ends the game session and broadcasts final results.
  """
  def end_game(%GameSession{} = session) do
    with {:ok, session} <- update_session_status(session, :completed) do
      players = list_players(session.id) |> Enum.sort_by(& &1.score, :desc)
      broadcast(session.id, :game_ended, %{session: session, leaderboard: players})
      {:ok, session}
    end
  end

  @doc """
  Gets the current active category for MC control.
  Returns the first voting_open category, or first pending if none open, or first voting_closed if waiting to reveal.
  """
  def get_current_category_for_mc(game_session_id) do
    # First try voting_open
    voting = get_current_voting_category(game_session_id)

    if voting do
      voting
    else
      # Try voting_closed (waiting to reveal votes or winner)
      closed =
        Category
        |> where([c], c.game_session_id == ^game_session_id and c.status == :voting_closed)
        |> order_by([c], asc: c.display_order)
        |> limit(1)
        |> Repo.one()
        |> maybe_preload_nominees()

      if closed do
        closed
      else
        # Get first pending
        Category
        |> where([c], c.game_session_id == ^game_session_id and c.status == :pending)
        |> order_by([c], asc: c.display_order)
        |> limit(1)
        |> Repo.one()
        |> maybe_preload_nominees()
      end
    end
  end

  @doc """
  Gets all categories for a session with their current states.
  """
  def get_categories_with_status(game_session_id) do
    Category
    |> where([c], c.game_session_id == ^game_session_id)
    |> order_by([c], asc: c.display_order)
    |> Repo.all()
    |> Repo.preload([:nominees, :winner])
  end

  @doc """
  Gets the count of players who have voted in a category.
  """
  def count_votes_for_category(category_id) do
    Vote
    |> where([v], v.category_id == ^category_id)
    |> Repo.aggregate(:count)
  end
end
