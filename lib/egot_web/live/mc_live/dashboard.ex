defmodule EgotWeb.MCLive.Dashboard do
  use EgotWeb, :live_view

  alias Egot.GameSessions
  alias Egot.GameSessions.GameSession

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        MC Dashboard
        <:subtitle>Manage your Golden Globe voting sessions</:subtitle>
      </.header>

      <div class="mt-8 space-y-8">
        <div class="card bg-base-200 p-6">
          <h2 class="text-lg font-semibold mb-4">Create New Session</h2>
          <.form for={@form} id="new-session-form" phx-submit="create_session" phx-change="validate">
            <.input
              field={@form[:name]}
              type="text"
              label="Session Name"
              placeholder="Golden Globes 2026"
              required
            />
            <div class="mt-4">
              <.button variant="primary" phx-disable-with="Creating...">
                Create Session
              </.button>
            </div>
          </.form>
        </div>

        <div class="space-y-4">
          <h2 class="text-lg font-semibold">Your Sessions</h2>

          <div :if={@sessions == []} class="text-center py-8 text-base-content/60">
            No sessions yet. Create one above to get started!
          </div>

          <div :for={session <- @sessions} class="card bg-base-200 p-4">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="font-semibold">{session.name}</h3>
                <p class="text-sm text-base-content/60">
                  Join Code: <span class="font-mono font-bold">{session.join_code}</span>
                </p>
                <p class="text-sm">
                  Status: <.status_badge status={session.status} />
                </p>
              </div>
              <div class="flex gap-2">
                <.button
                  :if={session.status == :lobby}
                  phx-click="start_session"
                  phx-value-id={session.id}
                >
                  Start
                </.button>
                <.button
                  :if={session.status == :in_progress}
                  phx-click="complete_session"
                  phx-value-id={session.id}
                >
                  Complete
                </.button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge(assigns) do
    {text, class} =
      case assigns.status do
        :lobby -> {"Lobby", "badge-info"}
        :in_progress -> {"In Progress", "badge-success"}
        :completed -> {"Completed", "badge-neutral"}
      end

    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"badge #{@class}"}>{@text}</span>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = GameSessions.list_sessions_by_user(user.id)
    changeset = GameSessions.change_session(%GameSession{}, %{})

    socket =
      socket
      |> assign(:sessions, sessions)
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"game_session" => params}, socket) do
    form =
      %GameSession{}
      |> GameSessions.change_session(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("create_session", %{"game_session" => params}, socket) do
    user = socket.assigns.current_scope.user
    params = Map.put(params, "created_by_id", user.id)

    case GameSessions.create_session(params) do
      {:ok, session} ->
        sessions = [session | socket.assigns.sessions]
        changeset = GameSessions.change_session(%GameSession{}, %{})

        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:form, to_form(changeset))
          |> put_flash(:info, "Session created! Join code: #{session.join_code}")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}

      {:error, :join_code_collision} ->
        socket =
          socket
          |> put_flash(:error, "Failed to generate unique join code. Please try again.")

        {:noreply, socket}
    end
  end

  def handle_event("start_session", %{"id" => id}, socket) do
    session = GameSessions.get_session!(id)

    case GameSessions.update_session_status(session, :in_progress) do
      {:ok, updated_session} ->
        sessions = update_session_in_list(socket.assigns.sessions, updated_session)
        {:noreply, assign(socket, :sessions, sessions)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to start session.")}
    end
  end

  def handle_event("complete_session", %{"id" => id}, socket) do
    session = GameSessions.get_session!(id)

    case GameSessions.update_session_status(session, :completed) do
      {:ok, updated_session} ->
        sessions = update_session_in_list(socket.assigns.sessions, updated_session)
        {:noreply, assign(socket, :sessions, sessions)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to complete session.")}
    end
  end

  defp update_session_in_list(sessions, updated_session) do
    Enum.map(sessions, fn session ->
      if session.id == updated_session.id, do: updated_session, else: session
    end)
  end
end
