# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Egot.Repo.insert!(%Egot.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Egot.Repo
alias Egot.Accounts.User

# Create MC user if it doesn't exist
mc_email = "mc@example.com"

unless Repo.get_by(User, email: mc_email) do
  %User{}
  |> Ecto.Changeset.change(%{
    email: mc_email,
    hashed_password: Bcrypt.hash_pwd_salt("password123"),
    is_mc: true,
    confirmed_at: DateTime.utc_now(:second)
  })
  |> Repo.insert!()

  IO.puts("Created MC user: #{mc_email} / password123")
end

# Create player users
for email <- ["user1@egot.dev", "user2@egot.dev", "rivera.jocelyne@gmail.com", "milne.iain@gmail.com"] do
  unless Repo.get_by(User, email: email) do
    %User{}
    |> Ecto.Changeset.change(%{
      email: email,
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      is_mc: false,
      confirmed_at: DateTime.utc_now(:second)
    })
    |> Repo.insert!()

    IO.puts("Created player user: #{email} / password123")
  end
end
