defmodule Egot.GameSessions.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias Egot.Accounts.User
  alias Egot.GameSessions.Category

  @status_values [:lobby, :in_progress, :completed]

  schema "game_sessions" do
    field :name, :string
    field :join_code, :string
    field :status, Ecto.Enum, values: @status_values, default: :lobby

    belongs_to :created_by, User, foreign_key: :created_by_id
    has_many :categories, Category

    timestamps(type: :utc_datetime)
  end

  # Characters used for join code generation.
  # Excludes easily confused characters (0/O, 1/I/L).
  @join_code_chars ~c"ABCDEFGHJKMNPQRSTUVWXYZ23456789"

  @doc """
  Generates a random 6-character uppercase join code.
  """
  def generate_join_code do
    1..6
    |> Enum.map(fn _ -> Enum.random(@join_code_chars) end)
    |> List.to_string()
  end

  @doc """
  Returns the list of valid status values.
  """
  def status_values, do: @status_values

  @doc """
  Changeset for creating a new game session.
  """
  def create_changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:name, :created_by_id])
    |> validate_required([:name, :created_by_id])
    |> validate_length(:name, min: 1, max: 100)
    |> put_join_code()
    |> unique_constraint(:join_code)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc """
  Changeset for updating game session status.
  """
  def status_changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end

  defp put_join_code(changeset) do
    if get_field(changeset, :join_code) do
      changeset
    else
      put_change(changeset, :join_code, generate_join_code())
    end
  end
end
