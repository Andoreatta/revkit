defmodule Revkit.Repo do
  use Ecto.Repo,
    otp_app: :revkit,
    adapter: Ecto.Adapters.SQLite3
end
