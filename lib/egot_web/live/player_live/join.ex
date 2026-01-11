defmodule EgotWeb.PlayerLive.Join do
  use EgotWeb, :live_view

  alias Egot.GameSessions

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <.header>
          Join a Game
          <:subtitle>Enter the 6-character code to join a voting session</:subtitle>
        </.header>

        <.form for={@form} id="join-form" phx-submit="join" phx-change="validate">
          <.input
            field={@form[:join_code]}
            type="text"
            label="Join Code"
            placeholder="ABC123"
            maxlength="6"
            autocomplete="off"
            class="uppercase text-center text-2xl tracking-widest font-mono"
            required
          />
          <div class="mt-4">
            <.button variant="primary" class="w-full" phx-disable-with="Joining...">
              Join Game
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"join_code" => ""}, as: "join")
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("validate", %{"join" => params}, socket) do
    params = Map.update(params, "join_code", "", &String.upcase/1)
    form = to_form(params, as: "join")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("join", %{"join" => %{"join_code" => join_code}}, socket) do
    user = socket.assigns.current_scope.user
    join_code = String.upcase(String.trim(join_code))

    case GameSessions.get_session_by_join_code(join_code) do
      nil ->
        form = to_form(%{"join_code" => join_code}, as: "join")

        {:noreply,
         socket
         |> assign(form: form)
         |> put_flash(:error, "Invalid join code. Please check and try again.")}

      game_session ->
        handle_join(socket, user, game_session, join_code)
    end
  end

  defp handle_join(socket, user, game_session, join_code) do
    case GameSessions.join_session(user, game_session) do
      {:ok, _player} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined #{game_session.name}!")
         |> redirect(to: ~p"/play/#{game_session.id}")}

      {:error, :session_not_joinable} ->
        form = to_form(%{"join_code" => join_code}, as: "join")

        {:noreply,
         socket
         |> assign(form: form)
         |> put_flash(:error, "This session is no longer accepting players.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        if already_joined_error?(changeset) do
          {:noreply, redirect(socket, to: ~p"/play/#{game_session.id}")}
        else
          form = to_form(%{"join_code" => join_code}, as: "join")

          {:noreply,
           socket
           |> assign(form: form)
           |> put_flash(:error, "Unable to join session. Please try again.")}
        end
    end
  end

  defp already_joined_error?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {msg, _}} ->
      msg =~ "already joined"
    end)
  end
end
