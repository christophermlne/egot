defmodule Egot.GameSessionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Egot.GameSessions` context.
  """

  alias Egot.GameSessions

  def unique_session_name, do: "Session #{System.unique_integer([:positive])}"

  def valid_session_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_session_name()
    })
  end

  def game_session_fixture(user, attrs \\ %{}) do
    attrs =
      attrs
      |> valid_session_attributes()
      |> Map.put(:created_by_id, user.id)

    {:ok, session} = GameSessions.create_session(attrs)
    session
  end
end
