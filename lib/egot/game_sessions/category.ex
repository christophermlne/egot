defmodule Egot.GameSessions.Category do
  use Ecto.Schema
  import Ecto.Changeset

  alias Egot.GameSessions.GameSession
  alias Egot.GameSessions.Nominee

  @status_values [:pending, :voting_open, :voting_closed, :revealed]

  schema "categories" do
    field :name, :string
    field :display_order, :integer, default: 0
    field :status, Ecto.Enum, values: @status_values, default: :pending

    belongs_to :game_session, GameSession
    belongs_to :winner, Nominee, foreign_key: :winner_nominee_id
    has_many :nominees, Nominee

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid status values.
  """
  def status_values, do: @status_values

  @doc """
  Changeset for creating a new category.
  """
  def create_changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :game_session_id, :display_order])
    |> validate_required([:name, :game_session_id])
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:game_session_id)
  end

  @doc """
  Changeset for updating a category.
  """
  def update_changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :display_order])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end

  @doc """
  Changeset for updating category status.
  """
  def status_changeset(category, attrs) do
    category
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end

  @doc """
  Changeset for setting the winner nominee.
  """
  def winner_changeset(category, attrs) do
    category
    |> cast(attrs, [:winner_nominee_id])
    |> foreign_key_constraint(:winner_nominee_id)
  end
end
