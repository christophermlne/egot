defmodule EgotWeb.PlayerLive.Join do
  use EgotWeb, :live_view

  alias Egot.GameSessions

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[60vh] flex flex-col items-center justify-center px-4">
        <div class="w-full max-w-sm space-y-6">
          <div class="text-center mb-8">
            <div class="text-5xl mb-4">&#127915;</div>
            <h1 class="text-2xl sm:text-3xl font-bold mb-2">Join a Game</h1>
            <p class="text-base-content/60">Enter the 6-character code from your MC</p>
          </div>

          <.form for={@form} id="join-form" phx-submit="join" phx-change="validate">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-base-content/70">Join Code</span>
              </label>
              <input
                type="text"
                name={@form[:join_code].name}
                id={@form[:join_code].id}
                value={Phoenix.HTML.Form.normalize_value("text", @form[:join_code].value)}
                placeholder="ABC123"
                maxlength="6"
                autocomplete="off"
                autocapitalize="characters"
                class="input input-lg input-bordered w-full uppercase text-center text-3xl tracking-[0.3em] font-mono"
                required
              />
            </div>

            <div class="mt-6">
              <.button variant="primary" class="w-full btn-lg h-14 text-lg" phx-disable-with="Joining...">
                <.icon name="hero-play" class="size-5 mr-2" />
                Join Game
              </.button>
            </div>
          </.form>

          <div class="text-center mt-8">
            <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="size-4" />
              Back to Home
            </.link>
          </div>
        </div>
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
        {:noreply, redirect(socket, to: ~p"/play/#{game_session.id}")}

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
