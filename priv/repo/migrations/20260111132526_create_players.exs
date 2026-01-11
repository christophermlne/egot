defmodule Egot.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_session_id, references(:game_sessions, on_delete: :delete_all), null: false
      add :score, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:players, [:user_id])
    create index(:players, [:game_session_id])
    create unique_index(:players, [:user_id, :game_session_id], name: :players_user_session_unique)
  end
end
