defmodule Egot.Repo do
  use Ecto.Repo,
    otp_app: :egot,
    adapter: Ecto.Adapters.Postgres
end
