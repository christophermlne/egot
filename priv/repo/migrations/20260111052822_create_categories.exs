defmodule Egot.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :game_session_id, references(:game_sessions, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :display_order, :integer, null: false, default: 0
      add :status, :string, null: false, default: "pending"
      add :winner_nominee_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:categories, [:game_session_id])
    create index(:categories, [:game_session_id, :display_order])
  end
end
