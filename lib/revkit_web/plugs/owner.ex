defmodule RevkitWeb.Plugs.Owner do
  @moduledoc """
  Ensures the signed session cookie carries a stable owner identifier.

  The identifier scopes private editions to one browser. It is not an
  authentication mechanism: clearing the cookie starts a new, empty identity.
  """

  @behaviour Plug

  import Plug.Conn

  @session_key :owner_id
  @min_length 16

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      owner_id when is_binary(owner_id) and byte_size(owner_id) >= @min_length ->
        assign(conn, :owner_id, owner_id)

      _missing ->
        owner_id = generate_owner_id()

        conn
        |> put_session(@session_key, owner_id)
        |> assign(:owner_id, owner_id)
    end
  end

  defp generate_owner_id do
    Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
  end
end
