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

  def unique_category_name, do: "Category #{System.unique_integer([:positive])}"

  def valid_category_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_category_name()
    })
  end

  def category_fixture(game_session, attrs \\ %{}) do
    attrs = valid_category_attributes(attrs)
    {:ok, category} = GameSessions.create_category(game_session.id, attrs)
    category
  end

  def unique_nominee_name, do: "Nominee #{System.unique_integer([:positive])}"

  def valid_nominee_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_nominee_name()
    })
  end

  def nominee_fixture(category, attrs \\ %{}) do
    attrs = valid_nominee_attributes(attrs)
    {:ok, nominee} = GameSessions.create_nominee(category.id, attrs)
    nominee
  end

  def player_fixture(user, game_session) do
    {:ok, player} = GameSessions.join_session(user, game_session)
    player
  end
end
