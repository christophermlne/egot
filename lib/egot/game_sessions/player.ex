defmodule Egot.GameSessions.Player do
  use Ecto.Schema
  import Ecto.Changeset

  alias Egot.Accounts.User
  alias Egot.GameSessions.GameSession
  alias Egot.GameSessions.Vote

  schema "players" do
    field :score, :integer, default: 0

    belongs_to :user, User
    belongs_to :game_session, GameSession
    has_many :votes, Vote

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a player (joining a session).
  """
  def create_changeset(player, attrs) do
    player
    |> cast(attrs, [:user_id, :game_session_id])
    |> validate_required([:user_id, :game_session_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:game_session_id)
    |> unique_constraint([:user_id, :game_session_id],
      name: :players_user_session_unique,
      message: "already joined this session"
    )
  end

  @doc """
  Changeset for updating a player's score.
  """
  def score_changeset(player, attrs) do
    player
    |> cast(attrs, [:score])
    |> validate_required([:score])
    |> validate_number(:score, greater_than_or_equal_to: 0)
  end
end
