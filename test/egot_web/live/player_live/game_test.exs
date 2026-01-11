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
      assert html =~ "in progress" || html =~ "In Progress"
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
      assert html =~ "Your Score"
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

  defp make_mc(user) do
    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{is_mc: true})
      |> Egot.Repo.update()

    user
  end
end
