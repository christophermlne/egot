defmodule EgotWeb.PageController do
  use EgotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
