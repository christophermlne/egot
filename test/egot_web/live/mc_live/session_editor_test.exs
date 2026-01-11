defmodule EgotWeb.MCLive.SessionEditorTest do
  use EgotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Egot.AccountsFixtures
  import Egot.GameSessionsFixtures

  describe "Session Editor - Authorization" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/mc/sessions/1")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not an MC", %{conn: conn} do
      user = user_fixture()
      session = game_session_fixture(make_mc(user_fixture()))
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/mc/sessions/#{session.id}")
      assert %{"error" => "You must be an MC to access this page."} = flash
    end

    test "redirects if session does not belong to user", %{conn: conn} do
      other_mc = user_fixture() |> make_mc()
      session = game_session_fixture(other_mc)

      user = user_fixture() |> make_mc()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/mc", flash: flash}}} = live(conn, ~p"/mc/sessions/#{session.id}")
      assert %{"error" => "You don't have access to this session."} = flash
    end
  end

  describe "Session Editor - Rendering" do
    setup %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user, %{name: "Golden Globes 2026"})
      %{conn: log_in_user(conn, user), user: user, session: session}
    end

    test "renders session editor", %{conn: conn, session: session} do
      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "Golden Globes 2026"
      assert html =~ session.join_code
      assert html =~ "Add Category"
      assert html =~ "Categories (0)"
    end

    test "shows existing categories and nominees", %{conn: conn, session: session} do
      category = category_fixture(session, %{name: "Best Picture"})
      _nominee = nominee_fixture(category, %{name: "The Brutalist"})

      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "Best Picture"
      assert html =~ "The Brutalist"
      assert html =~ "Categories (1)"
    end

    test "shows start game button for lobby sessions", %{conn: conn, session: session} do
      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "Start Game"
    end

    test "hides editing controls for in-progress sessions", %{conn: conn, session: session} do
      {:ok, _} = Egot.GameSessions.update_session_status(session, :in_progress)
      {:ok, _lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "Categories and nominees cannot be edited"
      refute html =~ "Add Category"
    end
  end

  describe "Session Editor - Categories" do
    setup %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user)
      %{conn: log_in_user(conn, user), user: user, session: session}
    end

    test "adds a new category", %{conn: conn, session: session} do
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}")

      result =
        lv
        |> form("#new-category-form", %{"category" => %{"name" => "Best Picture"}})
        |> render_submit()

      assert result =~ "Category added!"
      assert result =~ "Best Picture"
      assert result =~ "Categories (1)"
    end

    test "shows validation error for empty category name", %{conn: conn, session: session} do
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}")

      result =
        lv
        |> form("#new-category-form", %{"category" => %{"name" => ""}})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "deletes a category", %{conn: conn, session: session} do
      category = category_fixture(session, %{name: "Best Picture"})
      {:ok, lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "Best Picture"

      result =
        lv
        |> element("button[phx-click='delete_category'][phx-value-id='#{category.id}']")
        |> render_click()

      assert result =~ "Category deleted!"
      refute result =~ "Best Picture"
    end

    test "moves category up", %{conn: conn, session: session} do
      _cat1 = category_fixture(session, %{name: "First Category"})
      cat2 = category_fixture(session, %{name: "Second Category"})

      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}")

      lv
      |> element("button[phx-click='move_category_up'][phx-value-id='#{cat2.id}']")
      |> render_click()

      # Verify order changed - Second should now be first
      session = Egot.GameSessions.get_session_with_categories!(session.id)
      [first_cat | _] = session.categories
      assert first_cat.name == "Second Category"
    end

    test "moves category down", %{conn: conn, session: session} do
      cat1 = category_fixture(session, %{name: "First Category"})
      _cat2 = category_fixture(session, %{name: "Second Category"})

      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}")

      lv
      |> element("button[phx-click='move_category_down'][phx-value-id='#{cat1.id}']")
      |> render_click()

      # Verify order changed - First should now be second
      session = Egot.GameSessions.get_session_with_categories!(session.id)
      [first_cat | _] = session.categories
      assert first_cat.name == "Second Category"
    end
  end

  describe "Session Editor - Nominees" do
    setup %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user)
      category = category_fixture(session, %{name: "Best Picture"})
      %{conn: log_in_user(conn, user), user: user, session: session, category: category}
    end

    test "adds a nominee to a category", %{conn: conn, session: session, category: category} do
      {:ok, lv, _html} = live(conn, ~p"/mc/sessions/#{session.id}")

      result =
        lv
        |> form("#new-nominee-#{category.id}", %{"nominee" => %{"name" => "The Brutalist"}})
        |> render_submit()

      assert result =~ "The Brutalist"
    end

    test "deletes a nominee", %{conn: conn, session: session, category: category} do
      nominee = nominee_fixture(category, %{name: "The Brutalist"})
      {:ok, lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "The Brutalist"

      result =
        lv
        |> element("button[phx-click='delete_nominee'][phx-value-id='#{nominee.id}']")
        |> render_click()

      refute result =~ "The Brutalist"
    end
  end

  describe "Session Editor - Start Game" do
    setup %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user)
      %{conn: log_in_user(conn, user), user: user, session: session}
    end

    test "starts the game", %{conn: conn, session: session} do
      {:ok, lv, html} = live(conn, ~p"/mc/sessions/#{session.id}")

      assert html =~ "Start Game"
      assert html =~ "Lobby"

      result =
        lv
        |> element("button", "Start Game")
        |> render_click()

      assert result =~ "Game started!"
      assert result =~ "In Progress"
      refute result =~ ">Start Game<"
    end
  end

  describe "Dashboard - Manage Link" do
    test "shows manage link for sessions", %{conn: conn} do
      user = user_fixture() |> make_mc()
      session = game_session_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/mc")

      assert html =~ ~s(href="/mc/sessions/#{session.id}")
      assert html =~ "Manage"
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
