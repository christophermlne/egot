defmodule Egot.GameSessions do
  @moduledoc """
  The GameSessions context.
  """

  import Ecto.Query, warn: false
  alias Egot.Repo
  alias Egot.GameSessions.GameSession

  @doc """
  Returns the list of game sessions created by a specific user.
  """
  def list_sessions_by_user(user_id) do
    GameSession
    |> where([gs], gs.created_by_id == ^user_id)
    |> order_by([gs], desc: gs.inserted_at, desc: gs.id)
    |> Repo.all()
  end

  @doc """
  Gets a single game_session.

  Raises `Ecto.NoResultsError` if the Game session does not exist.
  """
  def get_session!(id), do: Repo.get!(GameSession, id)

  @doc """
  Gets a game session by join code (case-insensitive).
  """
  def get_session_by_join_code(join_code) when is_binary(join_code) do
    join_code = String.upcase(join_code)
    Repo.get_by(GameSession, join_code: join_code)
  end

  @doc """
  Creates a game session with retry logic for join code collisions.
  """
  def create_session(attrs \\ %{}) do
    create_session_with_retry(attrs, 3)
  end

  defp create_session_with_retry(_attrs, 0) do
    {:error, :join_code_collision}
  end

  defp create_session_with_retry(attrs, attempts) do
    result =
      %GameSession{}
      |> GameSession.create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, session} ->
        {:ok, session}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :join_code) do
          # Join code collision - retry with new code
          create_session_with_retry(attrs, attempts - 1)
        else
          {:error, changeset}
        end
    end
  end

  @doc """
  Updates a game session's status.
  """
  def update_session_status(%GameSession{} = game_session, status) do
    game_session
    |> GameSession.status_changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game session changes.
  """
  def change_session(%GameSession{} = game_session, attrs \\ %{}) do
    GameSession.create_changeset(game_session, attrs)
  end

  @doc """
  Deletes a game session.
  """
  def delete_session(%GameSession{} = game_session) do
    Repo.delete(game_session)
  end
end
