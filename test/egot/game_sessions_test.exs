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
end
