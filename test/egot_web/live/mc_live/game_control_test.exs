defmodule EgotWeb.MCLive.GameControlTest do
  use EgotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Egot.AccountsFixtures
  import Egot.GameSessionsFixtures

  describe "MC Game Control View" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/mc/sessions/1/live")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not an MC", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/mc/sessions/#{session.id}/live")

      assert %{"error" => "You must be an MC to access this page."} = flash
    end

    test "redirects if MC doesn't own the session", %{conn: conn} do
      mc1 = user_fixture() |> make_mc()
      mc2 = user_fixture() |> make_mc()
      session = game_session_fixture(mc1)
      conn = log_in_user(conn, mc2)

      assert {:error, {:redirect, %{to: "/mc", flash: flash}}} =
               live(conn, ~p"/mc/sessions/#{session.id}/live")

      assert %{"error" => "You don't have access to this session."} = flash
    end

    test "shows lobby state with start button", %{conn: conn} do
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      conn = log_in_user(conn, mc)

      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      assert html =~ "Game in Lobby"
      assert html =~ "Start Game"
    end

    test "shows player count", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      _player = player_fixture(user, session)
      conn = log_in_user(conn, mc)

      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      assert html =~ "1 player(s)"
    end
  end

  describe "game flow control" do
    setup %{conn: conn} do
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      category = category_fixture(session, %{name: "Best Picture"})
      nominee = nominee_fixture(category, %{name: "The Brutalist"})

      %{
        conn: log_in_user(conn, mc),
        mc: mc,
        session: session,
        category: category,
        nominee: nominee
      }
    end

    test "starts game and shows first category", %{conn: conn, session: session} do
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      html =
        lv
        |> element("button", "Start Game")
        |> render_click()

      assert html =~ "Best Picture"
      assert html =~ "Open Voting"
    end

    test "opens voting for category", %{conn: conn, session: session} do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      html =
        lv
        |> element("button", "Open Voting")
        |> render_click()

      assert html =~ "Close Voting"
      assert html =~ "Voting Open"
    end

    test "closes voting for category", %{conn: conn, session: session, category: category} do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _} = Egot.GameSessions.open_voting(category)
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      html =
        lv
        |> element("button", "Close Voting")
        |> render_click()

      assert html =~ "Reveal Votes"
      assert html =~ "Voting Closed"
    end

    test "cancels voting and returns category to pending", %{conn: conn, session: session, category: category} do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _} = Egot.GameSessions.open_voting(category)
      {:ok, lv, html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      # Should see Cancel Voting button when voting is open
      assert html =~ "Cancel Voting"

      html =
        lv
        |> element("button", "Cancel Voting")
        |> render_click()

      # Category should now show Open Voting button (pending state)
      assert html =~ "Open Voting"
      assert html =~ "Pending"
    end

    test "reveals votes", %{conn: conn, session: session, category: category} do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _} = Egot.GameSessions.open_voting(category)
      {:ok, _category} = Egot.GameSessions.close_voting(category)
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      html =
        lv
        |> element("button", "Reveal Votes")
        |> render_click()

      assert html =~ "Vote Distribution"
      assert html =~ "Select the Actual Winner"
    end

    test "selects and reveals winner", %{
      conn: conn,
      session: session,
      category: category,
      nominee: nominee
    } do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _} = Egot.GameSessions.open_voting(category)
      {:ok, _category} = Egot.GameSessions.close_voting(category)
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      # Click Reveal Votes to show the dropdown
      lv
      |> element("button", "Reveal Votes")
      |> render_click()

      # Select winner from dropdown (form has phx-change)
      lv
      |> form("form", %{"winner_id" => to_string(nominee.id)})
      |> render_change()

      # Click reveal winner
      html =
        lv
        |> element("button", "Reveal Winner")
        |> render_click()

      assert html =~ "Next Category"
      assert html =~ "Complete"
    end

    test "shows all complete state when no more categories", %{
      conn: conn,
      session: session,
      category: category,
      nominee: nominee
    } do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _} = Egot.GameSessions.open_voting(category)
      {:ok, category} = Egot.GameSessions.close_voting(category)
      {:ok, _} = Egot.GameSessions.reveal_winner(category, nominee)
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      assert render(lv) =~ "All Categories Complete"
      assert render(lv) =~ "End Game"
    end

    test "ends game and shows leaderboard", %{
      conn: conn,
      session: session,
      category: category,
      nominee: nominee
    } do
      user = user_fixture()
      _player = player_fixture(user, session)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _} = Egot.GameSessions.open_voting(category)
      {:ok, category} = Egot.GameSessions.close_voting(category)
      {:ok, _} = Egot.GameSessions.reveal_winner(category, nominee)
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      html =
        lv
        |> element("button", "End Game")
        |> render_click()

      assert html =~ "Game Complete!"
      assert html =~ "Final Leaderboard"
    end
  end

  describe "real-time vote updates" do
    test "shows vote count updates when players vote", %{conn: conn} do
      user = user_fixture()
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      player = player_fixture(user, session)
      category = category_fixture(session, %{name: "Best Picture"})
      nominee = nominee_fixture(category, %{name: "The Brutalist"})
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, category} = Egot.GameSessions.open_voting(category)
      conn = log_in_user(conn, mc)

      {:ok, lv, html} = live(conn, ~p"/mc/sessions/#{session.id}/live")
      # Check initial state - 0 out of 1 has voted (HTML has the span around the number)
      assert html =~ ">0</span> / 1 voted"

      # Player casts vote (this will broadcast)
      {:ok, _} = Egot.GameSessions.cast_vote(player, category, nominee)

      # Give the LiveView time to process the broadcast
      :timer.sleep(100)

      html = render(lv)
      assert html =~ ">1</span> / 1 voted"
    end
  end

  describe "category reordering" do
    test "can reorder categories during in_progress session", %{conn: conn} do
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      cat1 = category_fixture(session, %{name: "First Category"})
      cat2 = category_fixture(session, %{name: "Second Category"})
      _nominee1 = nominee_fixture(cat1)
      _nominee2 = nominee_fixture(cat2)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      conn = log_in_user(conn, mc)

      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      # Move second category up
      lv
      |> element("button[phx-click='move_category_down'][phx-value-id='#{cat1.id}']")
      |> render_click()

      # Verify order changed
      updated_session = Egot.GameSessions.get_session_with_categories!(session.id)
      [first_cat | _] = updated_session.categories
      assert first_cat.name == "Second Category"
    end
  end

  describe "no categories state" do
    test "shows message when no categories configured", %{conn: conn} do
      mc = user_fixture() |> make_mc()
      session = game_session_fixture(mc)
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      conn = log_in_user(conn, mc)

      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}/live")

      assert html =~ "No categories configured"
      assert html =~ "Return to Session Editor"
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
