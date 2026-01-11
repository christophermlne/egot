defmodule EgotWeb.PlayerLive.GameTest do
  use EgotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Egot.AccountsFixtures
  import Egot.GameSessionsFixtures

  describe "Player Game View" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/play/1")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user has not joined the session", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/play/#{session.id}")

      assert path == ~p"/join"
      assert flash["error"] =~ "haven't joined"
    end

    test "renders lobby waiting state", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ session.name
      assert html =~ "Waiting for game to start"
      assert html =~ "Lobby"
    end

    test "renders in_progress state", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      {:ok, session} = Egot.GameSessions.update_session_status(session, :in_progress)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ session.name
      assert html =~ "Game in Progress"
    end

    test "renders completed state with score", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :completed)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ session.name
      assert html =~ "Game Complete"
      assert html =~ "Your Final Score"
    end

    test "shows player count", %{conn: conn} do
      user1 = user_fixture()
      user2 = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player1 = player_fixture(user1, session)
      _player2 = player_fixture(user2, session)
      conn = log_in_user(conn, user1)

      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ "2 player(s)"
    end
  end

  describe "Voting Interface" do
    test "shows waiting message when no category is voting_open", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      _category = category_fixture(session)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ "Waiting for Next Category"
    end

    test "shows voting UI when category is voting_open", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      category = category_fixture(session, %{name: "Best Picture"})
      {:ok, _} = Egot.GameSessions.update_category_status(category, :voting_open)
      _nominee = nominee_fixture(category, %{name: "The Brutalist"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ "Best Picture"
      assert html =~ "The Brutalist"
      assert html =~ "Select your prediction"
    end

    test "casts vote when nominee is clicked", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      category = category_fixture(session, %{name: "Best Picture"})
      {:ok, _} = Egot.GameSessions.update_category_status(category, :voting_open)
      nominee = nominee_fixture(category, %{name: "The Brutalist"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/play/#{session.id}")

      html =
        lv
        |> element("button", "The Brutalist")
        |> render_click()

      assert html =~ "Vote Submitted"
      assert html =~ "Vote recorded"

      # Verify vote was saved
      vote = Egot.GameSessions.get_vote(player.id, category.id)
      assert vote != nil
      assert vote.nominee_id == nominee.id
    end

    test "shows vote submitted state after voting", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      category = category_fixture(session, %{name: "Best Picture"})
      {:ok, category} = Egot.GameSessions.update_category_status(category, :voting_open)
      nominee = nominee_fixture(category, %{name: "The Brutalist"})

      # Pre-cast vote
      {:ok, _} = Egot.GameSessions.cast_vote(player, category, nominee)

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/play/#{session.id}")

      assert html =~ "Vote Submitted"
      assert html =~ "Waiting for voting to close"
      refute html =~ "Select your prediction"
    end
  end

  defp make_mc(user) do
    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{is_mc: true})
      |> Egot.Repo.update()

    user
  end
end
