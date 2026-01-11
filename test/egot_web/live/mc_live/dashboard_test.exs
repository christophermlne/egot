defmodule EgotWeb.MCLive.DashboardTest do
  use EgotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Egot.AccountsFixtures
  import Egot.GameSessionsFixtures

  describe "MC Dashboard" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/mc")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not an MC", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/mc")
      assert %{"error" => "You must be an MC to access this page."} = flash
    end

    test "renders dashboard for MC user", %{conn: conn} do
      user = user_fixture() |> make_mc()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/mc")

      assert html =~ "MC Dashboard"
      assert html =~ "Create New Session"
    end

    test "lists existing sessions", %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user, %{name: "Test Session"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/mc")

      assert html =~ "Test Session"
      assert html =~ session.join_code
    end

    test "shows empty state when no sessions exist", %{conn: conn} do
      user = user_fixture() |> make_mc()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/mc")

      assert html =~ "No sessions yet"
    end
  end

  describe "create session" do
    setup %{conn: conn} do
      user = user_fixture() |> make_mc()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "creates a new session", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/mc")

      result =
        lv
        |> form("#new-session-form", %{"game_session" => %{"name" => "Golden Globes 2026"}})
        |> render_submit()

      assert result =~ "Session created!"
      assert result =~ "Golden Globes 2026"
    end

    test "shows validation errors for empty name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/mc")

      result =
        lv
        |> form("#new-session-form", %{"game_session" => %{"name" => ""}})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "session status changes" do
    setup %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user)
      %{conn: log_in_user(conn, user), user: user, session: session}
    end

    test "starts a session", %{conn: conn, session: _session} do
      {:ok, lv, html} = live(conn, ~p"/mc")

      assert html =~ "Lobby"
      assert html =~ "Start"

      result =
        lv
        |> element("button", "Start")
        |> render_click()

      assert result =~ "In Progress"
      refute result =~ ">Start<"
    end

    test "completes a session", %{conn: conn, session: session} do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, lv, html} = live(conn, ~p"/mc")

      assert html =~ "In Progress"
      assert html =~ "Complete"

      result =
        lv
        |> element("button", "Complete")
        |> render_click()

      assert result =~ "Completed"
      refute result =~ ">Complete<"
    end
  end

  # Helper to make a user an MC
  defp make_mc(user) do
    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{is_mc: true})
      |> Egot.Repo.update()

    user
  end
end
