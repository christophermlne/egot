defmodule Egot.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions) do
      add :name, :string, null: false
      add :join_code, :string, null: false, size: 6
      add :status, :string, null: false, default: "lobby"
      add :created_by_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_sessions, [:join_code])
    create index(:game_sessions, [:created_by_id])
    create index(:game_sessions, [:status])
  end
end
