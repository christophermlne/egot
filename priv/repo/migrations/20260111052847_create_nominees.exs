defmodule Egot.Repo.Migrations.CreateNominees do
  use Ecto.Migration

  def change do
    create table(:nominees) do
      add :category_id, references(:categories, on_delete: :delete_all), null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:nominees, [:category_id])
  end
end
