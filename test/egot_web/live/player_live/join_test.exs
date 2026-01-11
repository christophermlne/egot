defmodule EgotWeb.PlayerLive.JoinTest do
  use EgotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Egot.AccountsFixtures
  import Egot.GameSessionsFixtures

  describe "Join Page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/join")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders join form for logged in user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/join")

      assert html =~ "Join a Game"
      assert html =~ "Join Code"
    end

    test "shows error for invalid join code", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/join")

      result =
        lv
        |> form("#join-form", %{"join" => %{"join_code" => "INVALID"}})
        |> render_submit()

      assert result =~ "Invalid join code"
    end

    test "joins session and redirects to play page", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/join")

      result =
        lv
        |> form("#join-form", %{"join" => %{"join_code" => session.join_code}})
        |> render_submit()

      assert {:error, {:redirect, %{to: path}}} = result
      assert path == ~p"/play/#{session.id}"
    end

    test "handles lowercase join codes", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/join")

      result =
        lv
        |> form("#join-form", %{"join" => %{"join_code" => String.downcase(session.join_code)}})
        |> render_submit()

      assert {:error, {:redirect, %{to: path}}} = result
      assert path == ~p"/play/#{session.id}"
    end

    test "shows error when session is not joinable", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      {:ok, session} = Egot.GameSessions.update_session_status(session, :in_progress)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/join")

      result =
        lv
        |> form("#join-form", %{"join" => %{"join_code" => session.join_code}})
        |> render_submit()

      assert result =~ "no longer accepting players"
    end

    test "redirects to play page when already joined", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/join")

      result =
        lv
        |> form("#join-form", %{"join" => %{"join_code" => session.join_code}})
        |> render_submit()

      assert {:error, {:redirect, %{to: path}}} = result
      assert path == ~p"/play/#{session.id}"
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
