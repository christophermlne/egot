defmodule Egot.GameSessions.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Egot.GameSessions.Player
  alias Egot.GameSessions.Category
  alias Egot.GameSessions.Nominee

  schema "votes" do
    belongs_to :player, Player
    belongs_to :category, Category
    belongs_to :nominee, Nominee

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a vote.
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:player_id, :category_id, :nominee_id])
    |> validate_required([:player_id, :category_id, :nominee_id])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:category_id)
    |> foreign_key_constraint(:nominee_id)
    |> unique_constraint([:player_id, :category_id],
      name: :votes_player_category_unique,
      message: "already voted in this category"
    )
  end
end
