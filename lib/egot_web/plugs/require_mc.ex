defmodule EgotWeb.Plugs.RequireMC do
  @moduledoc """
  Plug that requires the current user to be an MC.
  Redirects to the home page if the user is not an MC.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_scope] && conn.assigns[:current_scope].user

    if user && user.is_mc do
      conn
    else
      conn
      |> put_flash(:error, "You must be an MC to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
