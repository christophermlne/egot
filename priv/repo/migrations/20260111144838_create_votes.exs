defmodule Egot.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false
      add :nominee_id, references(:nominees, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:votes, [:player_id])
    create index(:votes, [:category_id])
    create index(:votes, [:nominee_id])
    create unique_index(:votes, [:player_id, :category_id], name: :votes_player_category_unique)
  end
end
