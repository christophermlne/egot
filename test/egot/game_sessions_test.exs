defmodule Egot.GameSessionsTest do
  use Egot.DataCase

  alias Egot.GameSessions
  alias Egot.GameSessions.GameSession

  import Egot.AccountsFixtures
  import Egot.GameSessionsFixtures

  describe "list_sessions_by_user/1" do
    test "returns sessions for a specific user" do
      user1 = user_fixture()
      user2 = user_fixture()

      session1 = game_session_fixture(user1)
      _session2 = game_session_fixture(user2)

      sessions = GameSessions.list_sessions_by_user(user1.id)
      assert length(sessions) == 1
      assert hd(sessions).id == session1.id
    end

    test "returns empty list when user has no sessions" do
      user = user_fixture()
      assert GameSessions.list_sessions_by_user(user.id) == []
    end

    test "returns sessions ordered by newest first" do
      user = user_fixture()
      session1 = game_session_fixture(user, %{name: "First"})
      session2 = game_session_fixture(user, %{name: "Second"})

      sessions = GameSessions.list_sessions_by_user(user.id)
      assert [%{id: id2}, %{id: id1}] = sessions
      assert id2 == session2.id
      assert id1 == session1.id
    end
  end

  describe "get_session!/1" do
    test "returns the session with given id" do
      user = user_fixture()
      session = game_session_fixture(user)
      assert GameSessions.get_session!(session.id).id == session.id
    end

    test "raises if session does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        GameSessions.get_session!(-1)
      end
    end
  end

  describe "get_session_by_join_code/1" do
    test "returns session by join code" do
      user = user_fixture()
      session = game_session_fixture(user)
      assert GameSessions.get_session_by_join_code(session.join_code).id == session.id
    end

    test "returns session with case-insensitive join code" do
      user = user_fixture()
      session = game_session_fixture(user)
      assert GameSessions.get_session_by_join_code(String.downcase(session.join_code)).id == session.id
    end

    test "returns nil for invalid join code" do
      refute GameSessions.get_session_by_join_code("INVALID")
    end
  end

  describe "create_session/1" do
    test "creates a session with valid data" do
      user = user_fixture()
      attrs = %{name: "Test Session", created_by_id: user.id}

      assert {:ok, %GameSession{} = session} = GameSessions.create_session(attrs)
      assert session.name == "Test Session"
      assert session.status == :lobby
      assert String.length(session.join_code) == 6
      assert session.join_code == String.upcase(session.join_code)
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = GameSessions.create_session(%{})
    end

    test "returns error without created_by_id" do
      assert {:error, changeset} = GameSessions.create_session(%{name: "Test"})
      assert %{created_by_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with empty name" do
      user = user_fixture()
      assert {:error, changeset} = GameSessions.create_session(%{name: "", created_by_id: user.id})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_session_status/2" do
    test "updates session status to in_progress" do
      user = user_fixture()
      session = game_session_fixture(user)

      assert {:ok, updated} = GameSessions.update_session_status(session, :in_progress)
      assert updated.status == :in_progress
    end

    test "updates session status to completed" do
      user = user_fixture()
      session = game_session_fixture(user)

      assert {:ok, updated} = GameSessions.update_session_status(session, :completed)
      assert updated.status == :completed
    end
  end

  describe "delete_session/1" do
    test "deletes the session" do
      user = user_fixture()
      session = game_session_fixture(user)

      assert {:ok, %GameSession{}} = GameSessions.delete_session(session)
      assert_raise Ecto.NoResultsError, fn -> GameSessions.get_session!(session.id) end
    end
  end

  describe "GameSession.generate_join_code/0" do
    test "generates a 6-character uppercase code" do
      code = GameSession.generate_join_code()
      assert String.length(code) == 6
      assert code == String.upcase(code)
    end

    test "generates unique codes" do
      codes = for _ <- 1..100, do: GameSession.generate_join_code()
      assert length(Enum.uniq(codes)) == 100
    end
  end

  # -------------------------------------------------------------------
  # Categories
  # -------------------------------------------------------------------

  describe "list_categories/1" do
    test "returns categories for a game session ordered by display_order" do
      user = user_fixture()
      session = game_session_fixture(user)

      cat1 = category_fixture(session, %{name: "First"})
      cat2 = category_fixture(session, %{name: "Second"})

      categories = GameSessions.list_categories(session.id)
      assert length(categories) == 2
      assert [%{id: id1}, %{id: id2}] = categories
      assert id1 == cat1.id
      assert id2 == cat2.id
    end

    test "returns empty list when session has no categories" do
      user = user_fixture()
      session = game_session_fixture(user)

      assert GameSessions.list_categories(session.id) == []
    end
  end

  describe "get_category!/1" do
    test "returns the category with given id" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      assert GameSessions.get_category!(category.id).id == category.id
    end

    test "raises if category does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        GameSessions.get_category!(-1)
      end
    end
  end

  describe "create_category/2" do
    test "creates a category with valid data" do
      user = user_fixture()
      session = game_session_fixture(user)

      assert {:ok, category} = GameSessions.create_category(session.id, %{name: "Best Picture"})
      assert category.name == "Best Picture"
      assert category.game_session_id == session.id
      assert category.status == :pending
      assert category.display_order == 0
    end

    test "auto-assigns display_order to be after last category" do
      user = user_fixture()
      session = game_session_fixture(user)

      {:ok, cat1} = GameSessions.create_category(session.id, %{name: "First"})
      {:ok, cat2} = GameSessions.create_category(session.id, %{name: "Second"})
      {:ok, cat3} = GameSessions.create_category(session.id, %{name: "Third"})

      assert cat1.display_order == 0
      assert cat2.display_order == 1
      assert cat3.display_order == 2
    end

    test "returns error with empty name" do
      user = user_fixture()
      session = game_session_fixture(user)

      assert {:error, changeset} = GameSessions.create_category(session.id, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_category/2" do
    test "updates category name" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      assert {:ok, updated} = GameSessions.update_category(category, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_category/1" do
    test "deletes the category" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      assert {:ok, _} = GameSessions.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> GameSessions.get_category!(category.id) end
    end

    test "deletes associated nominees" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)
      nominee = nominee_fixture(category)

      assert {:ok, _} = GameSessions.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> GameSessions.get_nominee!(nominee.id) end
    end
  end

  describe "reorder_categories/2" do
    test "updates display_order based on new order" do
      user = user_fixture()
      session = game_session_fixture(user)

      {:ok, cat1} = GameSessions.create_category(session.id, %{name: "First"})
      {:ok, cat2} = GameSessions.create_category(session.id, %{name: "Second"})
      {:ok, cat3} = GameSessions.create_category(session.id, %{name: "Third"})

      # Reorder to: Third, First, Second
      GameSessions.reorder_categories(session.id, [cat3.id, cat1.id, cat2.id])

      categories = GameSessions.list_categories(session.id)
      assert [%{id: id1}, %{id: id2}, %{id: id3}] = categories
      assert id1 == cat3.id
      assert id2 == cat1.id
      assert id3 == cat2.id
    end
  end

  # -------------------------------------------------------------------
  # Nominees
  # -------------------------------------------------------------------

  describe "list_nominees/1" do
    test "returns nominees for a category" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      nominee1 = nominee_fixture(category, %{name: "First"})
      nominee2 = nominee_fixture(category, %{name: "Second"})

      nominees = GameSessions.list_nominees(category.id)
      assert length(nominees) == 2
      assert Enum.map(nominees, & &1.id) == [nominee1.id, nominee2.id]
    end

    test "returns empty list when category has no nominees" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      assert GameSessions.list_nominees(category.id) == []
    end
  end

  describe "get_nominee!/1" do
    test "returns the nominee with given id" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)
      nominee = nominee_fixture(category)

      assert GameSessions.get_nominee!(nominee.id).id == nominee.id
    end

    test "raises if nominee does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        GameSessions.get_nominee!(-1)
      end
    end
  end

  describe "create_nominee/2" do
    test "creates a nominee with valid data" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      assert {:ok, nominee} = GameSessions.create_nominee(category.id, %{name: "The Brutalist"})
      assert nominee.name == "The Brutalist"
      assert nominee.category_id == category.id
    end

    test "returns error with empty name" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)

      assert {:error, changeset} = GameSessions.create_nominee(category.id, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_nominee/2" do
    test "updates nominee name" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)
      nominee = nominee_fixture(category)

      assert {:ok, updated} = GameSessions.update_nominee(nominee, %{name: "New Title"})
      assert updated.name == "New Title"
    end
  end

  describe "delete_nominee/1" do
    test "deletes the nominee" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session)
      nominee = nominee_fixture(category)

      assert {:ok, _} = GameSessions.delete_nominee(nominee)
      assert_raise Ecto.NoResultsError, fn -> GameSessions.get_nominee!(nominee.id) end
    end
  end

  describe "get_session_with_categories!/1" do
    test "preloads categories and nominees" do
      user = user_fixture()
      session = game_session_fixture(user)
      category = category_fixture(session, %{name: "Best Picture"})
      nominee = nominee_fixture(category, %{name: "The Brutalist"})

      loaded_session = GameSessions.get_session_with_categories!(session.id)

      assert length(loaded_session.categories) == 1
      [loaded_category] = loaded_session.categories
      assert loaded_category.id == category.id
      assert loaded_category.name == "Best Picture"
      assert length(loaded_category.nominees) == 1
      [loaded_nominee] = loaded_category.nominees
      assert loaded_nominee.id == nominee.id
      assert loaded_nominee.name == "The Brutalist"
    end

    test "returns categories ordered by display_order" do
      user = user_fixture()
      session = game_session_fixture(user)

      {:ok, cat1} = GameSessions.create_category(session.id, %{name: "First"})
      {:ok, cat2} = GameSessions.create_category(session.id, %{name: "Second"})

      # Reorder
      GameSessions.reorder_categories(session.id, [cat2.id, cat1.id])

      loaded_session = GameSessions.get_session_with_categories!(session.id)
      assert [%{id: id1}, %{id: id2}] = loaded_session.categories
      assert id1 == cat2.id
      assert id2 == cat1.id
    end
  end

  # -------------------------------------------------------------------
  # Players
  # -------------------------------------------------------------------

  describe "get_player/2" do
    test "returns player when exists" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, player} = GameSessions.join_session(user, session)

      found = GameSessions.get_player(user.id, session.id)
      assert found.id == player.id
    end

    test "returns nil when player doesn't exist" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert GameSessions.get_player(user.id, session.id) == nil
    end
  end

  describe "get_player!/2" do
    test "returns player when exists" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, player} = GameSessions.join_session(user, session)

      found = GameSessions.get_player!(user.id, session.id)
      assert found.id == player.id
    end

    test "raises when player doesn't exist" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert_raise Ecto.NoResultsError, fn ->
        GameSessions.get_player!(user.id, session.id)
      end
    end
  end

  describe "join_session/2" do
    test "creates a player for a lobby session" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert {:ok, player} = GameSessions.join_session(user, session)
      assert player.user_id == user.id
      assert player.game_session_id == session.id
      assert player.score == 0
    end

    test "returns error when session is in_progress" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, session} = GameSessions.update_session_status(session, :in_progress)

      assert {:error, :session_not_joinable} = GameSessions.join_session(user, session)
    end

    test "returns error when session is completed" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, session} = GameSessions.update_session_status(session, :completed)

      assert {:error, :session_not_joinable} = GameSessions.join_session(user, session)
    end

    test "returns error when user already joined" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)

      {:ok, _} = GameSessions.join_session(user, session)
      assert {:error, changeset} = GameSessions.join_session(user, session)
      assert %{user_id: _} = errors_on(changeset)
    end
  end

  describe "list_players/1" do
    test "returns all players for a session" do
      user1 = user_fixture()
      user2 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)

      {:ok, _} = GameSessions.join_session(user1, session)
      {:ok, _} = GameSessions.join_session(user2, session)

      players = GameSessions.list_players(session.id)
      assert length(players) == 2
    end

    test "preloads user association" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, _} = GameSessions.join_session(user, session)

      [player] = GameSessions.list_players(session.id)
      assert player.user.email == user.email
    end

    test "returns empty list when session has no players" do
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert GameSessions.list_players(session.id) == []
    end
  end

  describe "count_players/1" do
    test "returns correct count" do
      user1 = user_fixture()
      user2 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert GameSessions.count_players(session.id) == 0

      {:ok, _} = GameSessions.join_session(user1, session)
      assert GameSessions.count_players(session.id) == 1

      {:ok, _} = GameSessions.join_session(user2, session)
      assert GameSessions.count_players(session.id) == 2
    end
  end

  describe "update_player_score/2" do
    test "updates player score" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, player} = GameSessions.join_session(user, session)

      assert {:ok, updated} = GameSessions.update_player_score(player, 10)
      assert updated.score == 10
    end

    test "validates score is non-negative" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, player} = GameSessions.join_session(user, session)

      assert {:error, changeset} = GameSessions.update_player_score(player, -1)
      assert %{score: _} = errors_on(changeset)
    end
  end

  # -------------------------------------------------------------------
  # Votes
  # -------------------------------------------------------------------

  describe "cast_vote/3" do
    test "casts a vote when category is voting_open" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      {:ok, _} = GameSessions.update_session_status(session, :in_progress)
      player = player_fixture(user, session)
      category = category_fixture(session)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      nominee = nominee_fixture(category)

      assert {:ok, vote} = GameSessions.cast_vote(player, category, nominee)
      assert vote.player_id == player.id
      assert vote.category_id == category.id
      assert vote.nominee_id == nominee.id
    end

    test "returns error when category is not voting_open" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category = category_fixture(session)
      nominee = nominee_fixture(category)

      assert {:error, :voting_not_open} = GameSessions.cast_vote(player, category, nominee)
    end

    test "returns error when nominee is not in category" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category1 = category_fixture(session)
      category2 = category_fixture(session)
      {:ok, category1} = GameSessions.update_category_status(category1, :voting_open)
      nominee_from_cat2 = nominee_fixture(category2)

      assert {:error, :nominee_not_in_category} =
               GameSessions.cast_vote(player, category1, nominee_from_cat2)
    end

    test "returns error when player already voted in category" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category = category_fixture(session)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      nominee1 = nominee_fixture(category)
      nominee2 = nominee_fixture(category)

      assert {:ok, _} = GameSessions.cast_vote(player, category, nominee1)
      assert {:error, changeset} = GameSessions.cast_vote(player, category, nominee2)
      assert %{player_id: _} = errors_on(changeset)
    end
  end

  describe "get_vote/2" do
    test "returns vote when exists" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category = category_fixture(session)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      nominee = nominee_fixture(category)
      {:ok, vote} = GameSessions.cast_vote(player, category, nominee)

      found = GameSessions.get_vote(player.id, category.id)
      assert found.id == vote.id
    end

    test "returns nil when vote doesn't exist" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category = category_fixture(session)

      assert GameSessions.get_vote(player.id, category.id) == nil
    end
  end

  describe "list_votes_for_category/2" do
    test "returns all votes for a category" do
      user1 = user_fixture()
      user2 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player1 = player_fixture(user1, session)
      player2 = player_fixture(user2, session)
      category = category_fixture(session)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      nominee = nominee_fixture(category)

      {:ok, _} = GameSessions.cast_vote(player1, category, nominee)
      {:ok, _} = GameSessions.cast_vote(player2, category, nominee)

      votes = GameSessions.list_votes_for_category(category.id)
      assert length(votes) == 2
    end

    test "returns empty list when no votes" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)

      assert GameSessions.list_votes_for_category(category.id) == []
    end
  end

  describe "count_votes_by_nominee/1" do
    test "returns vote counts per nominee" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player1 = player_fixture(user1, session)
      player2 = player_fixture(user2, session)
      player3 = player_fixture(user3, session)
      category = category_fixture(session)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      nominee1 = nominee_fixture(category)
      nominee2 = nominee_fixture(category)

      {:ok, _} = GameSessions.cast_vote(player1, category, nominee1)
      {:ok, _} = GameSessions.cast_vote(player2, category, nominee1)
      {:ok, _} = GameSessions.cast_vote(player3, category, nominee2)

      counts = GameSessions.count_votes_by_nominee(category.id)
      assert counts[nominee1.id] == 2
      assert counts[nominee2.id] == 1
    end
  end

  describe "get_current_voting_category/1" do
    test "returns category with voting_open status" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      _category1 = category_fixture(session)
      category2 = category_fixture(session)
      {:ok, _} = GameSessions.update_category_status(category2, :voting_open)

      found = GameSessions.get_current_voting_category(session.id)
      assert found.id == category2.id
      assert Ecto.assoc_loaded?(found.nominees)
    end

    test "returns first voting_open category by display_order" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      cat1 = category_fixture(session)
      cat2 = category_fixture(session)
      {:ok, _} = GameSessions.update_category_status(cat1, :voting_open)
      {:ok, _} = GameSessions.update_category_status(cat2, :voting_open)

      found = GameSessions.get_current_voting_category(session.id)
      assert found.id == cat1.id
    end

    test "returns nil when no voting_open categories" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      _category = category_fixture(session)

      assert GameSessions.get_current_voting_category(session.id) == nil
    end
  end

  describe "update_category_status/2" do
    test "updates category status to voting_open" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)

      assert {:ok, updated} = GameSessions.update_category_status(category, :voting_open)
      assert updated.status == :voting_open
    end

    test "updates category status to voting_closed" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)

      assert {:ok, updated} = GameSessions.update_category_status(category, :voting_closed)
      assert updated.status == :voting_closed
    end

    test "updates category status to revealed" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)

      assert {:ok, updated} = GameSessions.update_category_status(category, :revealed)
      assert updated.status == :revealed
    end
  end

  # -------------------------------------------------------------------
  # Game Control (MC Live View Operations)
  # -------------------------------------------------------------------

  describe "open_voting/1" do
    test "opens voting and broadcasts event" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)
      nominee_fixture(category)

      # Subscribe to the game topic
      Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{session.id}")

      assert {:ok, updated} = GameSessions.open_voting(category)
      assert updated.status == :voting_open
      assert Ecto.assoc_loaded?(updated.nominees)

      # Check broadcast received
      assert_receive {:voting_opened, %{category: broadcast_category}}
      assert broadcast_category.id == category.id
    end
  end

  describe "close_voting/1" do
    test "closes voting and broadcasts event" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)

      Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{session.id}")

      assert {:ok, updated} = GameSessions.close_voting(category)
      assert updated.status == :voting_closed

      assert_receive {:voting_closed, %{category: broadcast_category}}
      assert broadcast_category.id == category.id
    end
  end

  describe "reveal_votes/1" do
    test "broadcasts vote distribution" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category = category_fixture(session)
      nominee = nominee_fixture(category)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      {:ok, _} = GameSessions.cast_vote(player, category, nominee)
      {:ok, category} = GameSessions.close_voting(category)

      Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{session.id}")

      assert {:ok, _category, vote_counts} = GameSessions.reveal_votes(category)
      assert vote_counts[nominee.id] == 1

      assert_receive {:votes_revealed, %{category: _, vote_counts: broadcast_counts}}
      assert broadcast_counts[nominee.id] == 1
    end
  end

  describe "reveal_winner/2" do
    test "sets winner, updates scores, and broadcasts event" do
      user1 = user_fixture()
      user2 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player1 = player_fixture(user1, session)
      player2 = player_fixture(user2, session)
      category = category_fixture(session)
      winner = nominee_fixture(category, %{name: "Winner"})
      loser = nominee_fixture(category, %{name: "Loser"})
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      {:ok, _} = GameSessions.cast_vote(player1, category, winner)
      {:ok, _} = GameSessions.cast_vote(player2, category, loser)
      {:ok, category} = GameSessions.close_voting(category)

      Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{session.id}")

      assert {:ok, updated} = GameSessions.reveal_winner(category, winner)
      assert updated.status == :revealed
      assert updated.winner.id == winner.id

      # Check scores updated
      updated_player1 = GameSessions.get_player!(user1.id, session.id)
      updated_player2 = GameSessions.get_player!(user2.id, session.id)
      assert updated_player1.score == 1
      assert updated_player2.score == 0

      assert_receive {:winner_revealed, %{category: _, winner: broadcast_winner}}
      assert broadcast_winner.id == winner.id

      # Also broadcasts leaderboard update
      assert_receive {:leaderboard_updated, %{leaderboard: leaderboard}}
      assert length(leaderboard) == 2
      [first | _] = leaderboard
      assert first.score == 1
    end
  end

  describe "get_leaderboard/1" do
    test "returns players sorted by score descending" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player1 = player_fixture(user1, session)
      player2 = player_fixture(user2, session)
      player3 = player_fixture(user3, session)

      # Set different scores
      {:ok, _} = GameSessions.update_player_score(player1, 3)
      {:ok, _} = GameSessions.update_player_score(player2, 1)
      {:ok, _} = GameSessions.update_player_score(player3, 5)

      leaderboard = GameSessions.get_leaderboard(session.id)

      assert length(leaderboard) == 3
      assert Enum.at(leaderboard, 0).id == player3.id
      assert Enum.at(leaderboard, 1).id == player1.id
      assert Enum.at(leaderboard, 2).id == player2.id
    end

    test "returns empty list when no players" do
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert GameSessions.get_leaderboard(session.id) == []
    end
  end

  describe "advance_to_next_category/1" do
    test "opens voting for first pending category" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      cat1 = category_fixture(session)
      {:ok, _} = GameSessions.update_category_status(cat1, :revealed)
      cat2 = category_fixture(session)
      nominee_fixture(cat2)

      Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{session.id}")

      assert {:ok, opened} = GameSessions.advance_to_next_category(session.id)
      assert opened.id == cat2.id
      assert opened.status == :voting_open

      assert_receive {:voting_opened, %{category: broadcast_category}}
      assert broadcast_category.id == cat2.id
    end

    test "returns error when no more pending categories" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      cat1 = category_fixture(session)
      {:ok, _} = GameSessions.update_category_status(cat1, :revealed)

      assert {:error, :no_more_categories} = GameSessions.advance_to_next_category(session.id)
    end
  end

  describe "end_game/1" do
    test "completes session and broadcasts leaderboard" do
      user = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      {:ok, session} = GameSessions.update_session_status(session, :in_progress)

      Phoenix.PubSub.subscribe(Egot.PubSub, "game:#{session.id}")

      assert {:ok, updated} = GameSessions.end_game(session)
      assert updated.status == :completed

      assert_receive {:game_ended, %{session: _, leaderboard: players}}
      assert length(players) == 1
    end
  end

  describe "get_current_category_for_mc/1" do
    test "returns voting_open category first" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      _pending = category_fixture(session)
      voting = category_fixture(session)
      {:ok, _} = GameSessions.update_category_status(voting, :voting_open)

      found = GameSessions.get_current_category_for_mc(session.id)
      assert found.id == voting.id
    end

    test "returns voting_closed category when no voting_open" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      _pending = category_fixture(session)
      closed = category_fixture(session)
      {:ok, _} = GameSessions.update_category_status(closed, :voting_closed)

      found = GameSessions.get_current_category_for_mc(session.id)
      assert found.id == closed.id
    end

    test "returns first pending when no voting_open or voting_closed" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      pending = category_fixture(session)

      found = GameSessions.get_current_category_for_mc(session.id)
      assert found.id == pending.id
    end

    test "returns nil when no categories" do
      mc = user_fixture()
      session = game_session_fixture(mc)

      assert GameSessions.get_current_category_for_mc(session.id) == nil
    end
  end

  describe "get_categories_with_status/1" do
    test "returns all categories with nominees and winner preloaded" do
      mc = user_fixture()
      session = game_session_fixture(mc)
      category = category_fixture(session)
      nominee = nominee_fixture(category)

      categories = GameSessions.get_categories_with_status(session.id)
      assert length(categories) == 1
      [cat] = categories
      assert Ecto.assoc_loaded?(cat.nominees)
      assert Ecto.assoc_loaded?(cat.winner)
      assert hd(cat.nominees).id == nominee.id
    end
  end

  describe "count_votes_for_category/1" do
    test "returns correct count" do
      user1 = user_fixture()
      user2 = user_fixture()
      mc = user_fixture()
      session = game_session_fixture(mc)
      player1 = player_fixture(user1, session)
      player2 = player_fixture(user2, session)
      category = category_fixture(session)
      nominee = nominee_fixture(category)
      {:ok, category} = GameSessions.update_category_status(category, :voting_open)
      {:ok, _} = GameSessions.cast_vote(player1, category, nominee)
      {:ok, _} = GameSessions.cast_vote(player2, category, nominee)

      assert GameSessions.count_votes_for_category(category.id) == 2
    end
  end
end
