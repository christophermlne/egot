defmodule Egot.GameSessions.Nominee do
  use Ecto.Schema
  import Ecto.Changeset

  alias Egot.GameSessions.Category

  schema "nominees" do
    field :name, :string

    belongs_to :category, Category

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a nominee.
  """
  def changeset(nominee, attrs) do
    nominee
    |> cast(attrs, [:name, :category_id])
    |> validate_required([:name, :category_id])
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:category_id)
  end
end
