defmodule EgotWeb.MCLive.SessionEditor do
  use EgotWeb, :live_view

  alias Egot.GameSessions
  alias Egot.GameSessions.Category
  alias Egot.GameSessions.Nominee

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {session_name(@session)}
        <:subtitle>
          Join Code: <span class="font-mono font-bold">{@session.join_code}</span>
          &bull; Status: <.status_badge status={@session.status} />
        </:subtitle>
        <:actions>
          <.link navigate={~p"/mc"} class="btn btn-ghost btn-sm">
            &larr; Back to Dashboard
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 space-y-8">
        <div :if={@session.status == :lobby} class="flex gap-2">
          <.button variant="primary" phx-click="start_game">
            Start Game
          </.button>
        </div>

        <div :if={@session.status == :in_progress} class="alert alert-info">
          <span>
            Game in progress. You can add categories and edit pending categories. Categories being voted on or completed are locked.
          </span>
          <.link navigate={~p"/mc/sessions/#{@session.id}/live"} class="btn btn-primary btn-sm">
            Go to Live Control &rarr;
          </.link>
        </div>

        <div :if={@session.status == :completed} class="alert alert-neutral">
          <span>
            Session completed. Categories and nominees cannot be edited.
          </span>
        </div>

        <div :if={@session.status != :completed} class="card bg-base-200 p-6">
          <h2 class="text-lg font-semibold mb-4">Add Category</h2>
          <.form for={@category_form} id="new-category-form" phx-submit="add_category" phx-change="validate_category">
            <div class="flex gap-4">
              <div class="flex-1">
                <.input
                  field={@category_form[:name]}
                  type="text"
                  placeholder="Best Motion Picture - Drama"
                  required
                />
              </div>
              <.button variant="primary" phx-disable-with="Adding...">
                Add Category
              </.button>
            </div>
          </.form>
        </div>

        <div class="space-y-4">
          <h2 class="text-lg font-semibold">Categories ({length(@session.categories)})</h2>

          <div :if={@session.categories == []} class="text-center py-8 text-base-content/60">
            No categories yet. Add one above to get started!
          </div>

          <div :for={{category, index} <- Enum.with_index(@session.categories)} class="card bg-base-200 p-4">
            <div class="flex justify-between items-start mb-4">
              <div class="flex-1">
                <div :if={@editing_category_id == category.id}>
                  <.form
                    for={@edit_category_form}
                    id={"edit-category-#{category.id}"}
                    phx-submit="save_category"
                    phx-value-id={category.id}
                    class="flex gap-2"
                  >
                    <div class="flex-1">
                      <.input field={@edit_category_form[:name]} type="text" required />
                    </div>
                    <.button type="submit" variant="primary">Save</.button>
                    <.button type="button" phx-click="cancel_edit_category">Cancel</.button>
                  </.form>
                </div>
                <div :if={@editing_category_id != category.id} class="flex items-center gap-2">
                  <h3 class="font-semibold text-lg">{category.name}</h3>
                  <.category_status_badge status={category.status} />
                </div>
                <p :if={@editing_category_id != category.id} class="text-sm text-base-content/60">
                  {length(category.nominees)} nominee(s)
                </p>
              </div>

              <div :if={@session.status != :completed && @editing_category_id != category.id} class="flex gap-1 items-center">
                <%!-- Reorder buttons - available for all categories during lobby/in_progress --%>
                <.button
                  :if={index > 0}
                  phx-click="move_category_up"
                  phx-value-id={category.id}
                  class="btn-sm btn-ghost"
                  title="Move up"
                >
                  &uarr;
                </.button>
                <.button
                  :if={index < length(@session.categories) - 1}
                  phx-click="move_category_down"
                  phx-value-id={category.id}
                  class="btn-sm btn-ghost"
                  title="Move down"
                >
                  &darr;
                </.button>

                <%!-- Edit/Delete only for pending categories --%>
                <.button
                  :if={category.status == :pending}
                  phx-click="edit_category"
                  phx-value-id={category.id}
                  class="btn-sm btn-ghost"
                >
                  Edit
                </.button>
                <.button
                  :if={category.status == :pending}
                  phx-click="delete_category"
                  phx-value-id={category.id}
                  class="btn-sm btn-ghost text-error"
                  data-confirm="Delete this category and all its nominees?"
                >
                  Delete
                </.button>

                <%!-- Cancel Voting button for voting_open categories --%>
                <.button
                  :if={category.status == :voting_open}
                  phx-click="cancel_voting"
                  phx-value-id={category.id}
                  class="btn-sm btn-warning"
                  data-confirm="This will delete all votes for this category and return it to pending status. Are you sure?"
                >
                  Cancel Voting
                </.button>

                <%!-- Lock icon for non-editable categories --%>
                <span :if={category.status in [:voting_closed, :revealed]} class="text-base-content/40 ml-2" title="Category locked">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
                  </svg>
                </span>
              </div>
            </div>

            <div class="ml-4 space-y-2">
              <div :for={nominee <- category.nominees} class="flex items-center gap-2">
                <div :if={@editing_nominee_id == nominee.id} class="flex-1">
                  <.form
                    for={@edit_nominee_form}
                    id={"edit-nominee-#{nominee.id}"}
                    phx-submit="save_nominee"
                    phx-value-id={nominee.id}
                    class="flex gap-2"
                  >
                    <div class="flex-1">
                      <.input field={@edit_nominee_form[:name]} type="text" required />
                    </div>
                    <.button type="submit" variant="primary" class="btn-sm">Save</.button>
                    <.button type="button" phx-click="cancel_edit_nominee" class="btn-sm">Cancel</.button>
                  </.form>
                </div>
                <div :if={@editing_nominee_id != nominee.id} class="flex-1 flex items-center gap-2">
                  <span class="text-base-content/60">&bull;</span>
                  <span>{nominee.name}</span>
                  <div :if={category.status == :pending} class="flex gap-1 ml-auto">
                    <.button
                      phx-click="edit_nominee"
                      phx-value-id={nominee.id}
                      class="btn-xs btn-ghost"
                    >
                      Edit
                    </.button>
                    <.button
                      phx-click="delete_nominee"
                      phx-value-id={nominee.id}
                      class="btn-xs btn-ghost text-error"
                      data-confirm="Delete this nominee?"
                    >
                      Delete
                    </.button>
                  </div>
                </div>
              </div>

              <div :if={category.status == :pending}>
                <.form
                  for={@nominee_forms[category.id]}
                  id={"new-nominee-#{category.id}"}
                  phx-submit="add_nominee"
                  phx-value-category-id={category.id}
                  class="flex gap-2 mt-2"
                >
                  <div class="flex-1">
                    <.input
                      field={@nominee_forms[category.id][:name]}
                      id={"nominee_name_#{category.id}"}
                      type="text"
                      placeholder="Add nominee..."
                    />
                  </div>
                  <.button type="submit" class="btn-sm">Add</.button>
                </.form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp session_name(session) do
    session.name
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

  defp category_status_badge(assigns) do
    {text, class} =
      case assigns.status do
        :pending -> {"Pending", "badge-ghost"}
        :voting_open -> {"Voting", "badge-success"}
        :voting_closed -> {"Closed", "badge-warning"}
        :revealed -> {"Complete", "badge-neutral"}
      end

    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"badge badge-sm #{@class}"}>{@text}</span>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    session = GameSessions.get_session_with_categories!(id)

    # Verify ownership
    if session.created_by_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this session.")
       |> redirect(to: ~p"/mc")}
    else
      socket =
        socket
        |> assign(:session, session)
        |> assign(:category_form, to_form(GameSessions.change_category(%Category{}, %{})))
        |> assign(:editing_category_id, nil)
        |> assign(:edit_category_form, nil)
        |> assign(:editing_nominee_id, nil)
        |> assign(:edit_nominee_form, nil)
        |> assign(:nominee_forms, build_nominee_forms(session.categories))

      {:ok, socket}
    end
  end

  defp build_nominee_forms(categories) do
    Map.new(categories, fn category ->
      {category.id, to_form(GameSessions.change_nominee(%Nominee{}, %{}))}
    end)
  end

  @impl true
  def handle_event("validate_category", %{"category" => params}, socket) do
    form =
      %Category{}
      |> GameSessions.change_category(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :category_form, form)}
  end

  def handle_event("add_category", %{"category" => params}, socket) do
    case GameSessions.create_category(socket.assigns.session.id, params) do
      {:ok, _category} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)

        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:category_form, to_form(GameSessions.change_category(%Category{}, %{})))
         |> assign(:nominee_forms, build_nominee_forms(session.categories))}

      {:error, changeset} ->
        {:noreply, assign(socket, :category_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("edit_category", %{"id" => id}, socket) do
    category = GameSessions.get_category!(id)
    form = to_form(GameSessions.change_category(category, %{}))

    socket =
      socket
      |> assign(:editing_category_id, String.to_integer(id))
      |> assign(:edit_category_form, form)

    {:noreply, socket}
  end

  def handle_event("cancel_edit_category", _params, socket) do
    socket =
      socket
      |> assign(:editing_category_id, nil)
      |> assign(:edit_category_form, nil)

    {:noreply, socket}
  end

  def handle_event("save_category", %{"id" => id, "category" => params}, socket) do
    category = GameSessions.get_category!(id)

    case GameSessions.update_category(category, params) do
      {:ok, _category} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)

        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:editing_category_id, nil)
         |> assign(:edit_category_form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_category_form, to_form(changeset, action: :update))}
    end
  end

  def handle_event("delete_category", %{"id" => id}, socket) do
    category = GameSessions.get_category!(id)

    case GameSessions.delete_category(category) do
      {:ok, _} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)

        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:nominee_forms, build_nominee_forms(session.categories))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete category.")}
    end
  end

  def handle_event("cancel_voting", %{"id" => id}, socket) do
    category = GameSessions.get_category!(id)

    case GameSessions.cancel_voting(category) do
      {:ok, _category} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)
        {:noreply, assign(socket, :session, session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel voting.")}
    end
  end

  def handle_event("move_category_up", %{"id" => id}, socket) do
    reorder_category(socket, String.to_integer(id), :up)
  end

  def handle_event("move_category_down", %{"id" => id}, socket) do
    reorder_category(socket, String.to_integer(id), :down)
  end

  def handle_event("add_nominee", %{"category-id" => category_id, "nominee" => params}, socket) do
    category_id = String.to_integer(category_id)

    case GameSessions.create_nominee(category_id, params) do
      {:ok, _nominee} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)

        # Reset the nominee form for this category
        nominee_forms =
          Map.put(
            socket.assigns.nominee_forms,
            category_id,
            to_form(GameSessions.change_nominee(%Nominee{}, %{}))
          )

        socket =
          socket
          |> assign(:session, session)
          |> assign(:nominee_forms, nominee_forms)

        {:noreply, socket}

      {:error, changeset} ->
        nominee_forms =
          Map.put(socket.assigns.nominee_forms, category_id, to_form(changeset, action: :insert))

        {:noreply, assign(socket, :nominee_forms, nominee_forms)}
    end
  end

  def handle_event("edit_nominee", %{"id" => id}, socket) do
    nominee = GameSessions.get_nominee!(id)
    form = to_form(GameSessions.change_nominee(nominee, %{}))

    socket =
      socket
      |> assign(:editing_nominee_id, String.to_integer(id))
      |> assign(:edit_nominee_form, form)

    {:noreply, socket}
  end

  def handle_event("cancel_edit_nominee", _params, socket) do
    socket =
      socket
      |> assign(:editing_nominee_id, nil)
      |> assign(:edit_nominee_form, nil)

    {:noreply, socket}
  end

  def handle_event("save_nominee", %{"id" => id, "nominee" => params}, socket) do
    nominee = GameSessions.get_nominee!(id)

    case GameSessions.update_nominee(nominee, params) do
      {:ok, _nominee} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)

        socket =
          socket
          |> assign(:session, session)
          |> assign(:editing_nominee_id, nil)
          |> assign(:edit_nominee_form, nil)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_nominee_form, to_form(changeset, action: :update))}
    end
  end

  def handle_event("delete_nominee", %{"id" => id}, socket) do
    nominee = GameSessions.get_nominee!(id)

    case GameSessions.delete_nominee(nominee) do
      {:ok, _} ->
        session = GameSessions.get_session_with_categories!(socket.assigns.session.id)
        {:noreply, assign(socket, :session, session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete nominee.")}
    end
  end

  def handle_event("start_game", _params, socket) do
    session = socket.assigns.session

    case GameSessions.update_session_status(session, :in_progress) do
      {:ok, updated_session} ->
        # Broadcast session started for any players waiting
        Phoenix.PubSub.broadcast(
          Egot.PubSub,
          "game:#{updated_session.id}",
          {:session_started, %{session: updated_session}}
        )

        # Redirect to live control
        {:noreply, redirect(socket, to: ~p"/mc/sessions/#{updated_session.id}/live")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to start game.")}
    end
  end

  defp reorder_category(socket, category_id, direction) do
    categories = socket.assigns.session.categories
    index = Enum.find_index(categories, &(&1.id == category_id))

    new_index =
      case direction do
        :up -> max(0, index - 1)
        :down -> min(length(categories) - 1, index + 1)
      end

    if new_index != index do
      # Swap the categories
      category_ids =
        categories
        |> Enum.map(& &1.id)
        |> List.delete_at(index)
        |> List.insert_at(new_index, category_id)

      GameSessions.reorder_categories(socket.assigns.session.id, category_ids)
      session = GameSessions.get_session_with_categories!(socket.assigns.session.id)
      {:noreply, assign(socket, :session, session)}
    else
      {:noreply, socket}
    end
  end
end
