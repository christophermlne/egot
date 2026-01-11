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
end
