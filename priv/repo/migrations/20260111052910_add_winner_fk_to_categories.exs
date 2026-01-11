defmodule Egot.Repo.Migrations.AddWinnerFkToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      modify :winner_nominee_id, references(:nominees, on_delete: :nilify_all),
        from: :integer
    end
  end
end
