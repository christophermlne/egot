defmodule Mix.Tasks.Seed.GoldenGlobes do
  @moduledoc """
  Seeds a Golden Globes 2026 game session with all 28 categories and nominees.

  ## Usage

      mix seed.golden_globes

  This will create a new game session with all the official Golden Globes 2026
  categories and nominees. The MC user must already exist (run `mix ecto.setup` first).
  """

  use Mix.Task

  @shortdoc "Seeds a Golden Globes 2026 game session"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    alias Egot.Repo
    alias Egot.Accounts.User
    alias Egot.GameSessions

    # Find the MC user
    mc_user = Repo.get_by(User, is_mc: true)

    unless mc_user do
      Mix.shell().error("No MC user found. Please run `mix ecto.setup` first.")
      exit({:shutdown, 1})
    end

    # Create the game session
    {:ok, session} =
      GameSessions.create_session(%{
        name: "Golden Globes 2026",
        created_by_id: mc_user.id
      })

    # Seed all categories and nominees
    categories_data()
    |> Enum.each(fn {category_name, nominees} ->
      {:ok, category} = GameSessions.create_category(session.id, %{name: category_name})

      Enum.each(nominees, fn nominee_name ->
        {:ok, _nominee} = GameSessions.create_nominee(category.id, %{name: nominee_name})
      end)
    end)

    # Count totals
    categories = GameSessions.list_categories(session.id)
    total_nominees = categories |> Enum.map(&length(&1.nominees)) |> Enum.sum()

    Mix.shell().info("""

    Created Golden Globes 2026 game session!
    Join code: #{session.join_code}
    Categories: #{length(categories)}
    Total nominees: #{total_nominees}
    """)
  end

  defp categories_data do
    [
      # Film Categories
      {"Best Motion Picture - Drama", [
        "Frankenstein",
        "Hamnet",
        "It Was Just an Accident",
        "The Secret Agent",
        "Sentimental Value",
        "Sinners"
      ]},
      {"Best Motion Picture - Musical or Comedy", [
        "Blue Moon",
        "Bugonia",
        "Marty Supreme",
        "No Other Choice",
        "Nouvelle Vague",
        "One Battle After Another"
      ]},
      {"Best Female Actor - Motion Picture Drama", [
        "Jessie Buckley (Hamnet)",
        "Jennifer Lawrence (Die My Love)",
        "Renate Reinsve (Sentimental Value)",
        "Julia Roberts (After The Hunt)",
        "Tessa Thompson (Hedda)",
        "Eva Victor (Sorry, Baby)"
      ]},
      {"Best Male Actor - Motion Picture Drama", [
        "Joel Edgerton (Train Dreams)",
        "Oscar Isaac (Frankenstein)",
        "Dwayne Johnson (The Smashing Machine)",
        "Michael B. Jordan (Sinners)",
        "Wagner Moura (The Secret Agent)",
        "Jeremy Allen White (Springsteen: Deliver Me From Nowhere)"
      ]},
      {"Best Female Actor - Motion Picture Musical or Comedy", [
        "Rose Byrne (If I Had Legs I'd Kick You)",
        "Cynthia Erivo (Wicked: For Good)",
        "Kate Hudson (Song Sung Blue)",
        "Chase Infiniti (One Battle After Another)",
        "Amanda Seyfried (The Testament Of Ann Lee)",
        "Emma Stone (Bugonia)"
      ]},
      {"Best Male Actor - Motion Picture Musical or Comedy", [
        "Timothee Chalamet (Marty Supreme)",
        "George Clooney (Jay Kelly)",
        "Leonardo DiCaprio (One Battle After Another)",
        "Ethan Hawke (Blue Moon)",
        "Lee Byung-Hun (No Other Choice)",
        "Jesse Plemons (Bugonia)"
      ]},
      {"Best Supporting Male Actor - Motion Picture", [
        "Benicio Del Toro (One Battle After Another)",
        "Jacob Elordi (Frankenstein)",
        "Paul Mescal (Hamnet)",
        "Sean Penn (One Battle After Another)",
        "Adam Sandler (Jay Kelly)",
        "Stellan Skarsgard (Sentimental Value)"
      ]},
      {"Best Supporting Female Actor - Motion Picture", [
        "Emily Blunt (The Smashing Machine)",
        "Elle Fanning (Sentimental Value)",
        "Ariana Grande (Wicked: For Good)",
        "Inga Ibsdotter Lilleaas (Sentimental Value)",
        "Amy Madigan (Weapons)",
        "Teyana Taylor (One Battle After Another)"
      ]},
      {"Best Director - Motion Picture", [
        "Paul Thomas Anderson (One Battle After Another)",
        "Ryan Coogler (Sinners)",
        "Guillermo del Toro (Frankenstein)",
        "Jafar Panahi (It Was Just an Accident)",
        "Joachim Trier (Sentimental Value)",
        "Chloe Zhao (Hamnet)"
      ]},
      {"Best Motion Picture - Animated", [
        "Arco",
        "Demon Slayer",
        "Elio",
        "KPop Demon Hunters",
        "Little Amelie or the Character of Rain",
        "Zootopia 2"
      ]},
      {"Best Motion Picture - Non-English Language", [
        "It Was Just An Accident",
        "No Other Choice",
        "The Secret Agent",
        "Sentimental Value",
        "Sirat",
        "The Voice of Hind Rajab"
      ]},
      {"Best Original Score - Motion Picture", [
        "Alexandre Desplat (Frankenstein)",
        "Ludwig Goransson (Sinners)",
        "Jonny Greenwood (One Battle After Another)",
        "Max Richter (Hamnet)",
        "Hans Zimmer (F1: The Movie)",
        "Kangding Ray (Sirat)"
      ]},
      {"Best Original Song - Motion Picture", [
        "\"Dream as One\" - Avatar: Fire and Ash",
        "\"Golden\" - KPop Demon Hunters",
        "\"I Lied to You\" - Sinners",
        "\"No Place Like Home\" - Wicked: For Good",
        "\"The Girl in the Bubble\" - Wicked: For Good",
        "\"Train Dreams\" - Train Dreams"
      ]},
      {"Best Screenplay - Motion Picture", [
        "One Battle After Another",
        "Marty Supreme",
        "Sinners",
        "It Was Just An Accident",
        "Sentimental Value",
        "Hamnet"
      ]},
      {"Cinematic and Box Office Achievement", [
        "Avatar: Fire And Ash",
        "F1",
        "KPop Demon Hunters",
        "Mission: Impossible - The Final Reckoning",
        "Sinners",
        "Weapons",
        "Wicked: For Good",
        "Zootopia 2"
      ]},

      # Television Categories
      {"Best Television Series - Drama", [
        "The Diplomat",
        "The Pitt",
        "Pluribus",
        "Severance",
        "Slow Horses",
        "The White Lotus"
      ]},
      {"Best Female Actor - Television Series Drama", [
        "Kathy Bates (Matlock)",
        "Britt Lower (Severance)",
        "Helen Mirren (MobLand)",
        "Bella Ramsey (The Last of Us)",
        "Keri Russell (The Diplomat)",
        "Rhea Seehorn (Pluribus)"
      ]},
      {"Best Male Actor - Television Series Drama", [
        "Sterling K. Brown (Paradise)",
        "Diego Luna (Andor)",
        "Gary Oldman (Slow Horses)",
        "Mark Ruffalo (Task)",
        "Adam Scott (Severance)",
        "Noah Wyle (The Pitt)"
      ]},
      {"Best Television Series - Musical or Comedy", [
        "Abbott Elementary",
        "The Bear",
        "Hacks",
        "Nobody Wants This",
        "Only Murders In The Building",
        "The Studio"
      ]},
      {"Best Female Actor - Television Series Musical or Comedy", [
        "Kristen Bell (Nobody Wants This)",
        "Ayo Edebiri (The Bear)",
        "Selena Gomez (Only Murders in the Building)",
        "Natasha Lyonne (Poker Face)",
        "Jenna Ortega (Wednesday)",
        "Jean Smart (Hacks)"
      ]},
      {"Best Male Actor - Television Series Musical or Comedy", [
        "Adam Brody (Nobody Wants This)",
        "Steve Martin (Only Murders in the Building)",
        "Glen Powell (Chad Powers)",
        "Seth Rogen (The Studio)",
        "Martin Short (Only Murders in the Building)",
        "Jeremy Allen White (The Bear)"
      ]},
      {"Best Supporting Female Actor - Television", [
        "Carrie Coon (The White Lotus)",
        "Erin Doherty (Adolescence)",
        "Hannah Einbinder (Hacks)",
        "Catherine O'Hara (The Studio)",
        "Parker Posey (The White Lotus)",
        "Aimee Lou Wood (The White Lotus)"
      ]},
      {"Best Supporting Male Actor - Television", [
        "Owen Cooper (Adolescence)",
        "Billy Crudup (The Morning Show)",
        "Walton Goggins (The White Lotus)",
        "Jason Isaacs (The White Lotus)",
        "Tramell Tillman (Severance)",
        "Ashley Walters (Adolescence)"
      ]},
      {"Best Limited Series, Anthology Series, or TV Movie", [
        "Adolescence",
        "All Her Fault",
        "The Beast in Me",
        "Black Mirror",
        "Dying for Sex",
        "The Girlfriend"
      ]},
      {"Best Female Actor - Limited Series or TV Movie", [
        "Claire Danes (The Beast in Me)",
        "Rashida Jones (Black Mirror)",
        "Amanda Seyfried (Long Bright River)",
        "Sarah Snook (All Her Fault)",
        "Michelle Williams (Dying for Sex)",
        "Robin Wright (The Girlfriend)"
      ]},
      {"Best Male Actor - Limited Series or TV Movie", [
        "Jacob Elordi (The Narrow Road to the Deep North)",
        "Paul Giamatti (Black Mirror)",
        "Stephen Graham (Adolescence)",
        "Charlie Hunnam (Monster: The Ed Gein Story)",
        "Jude Law (Black Rabbit)",
        "Matthew Rhys (The Beast in Me)"
      ]},
      {"Best Stand-Up Comedy Performance", [
        "Bill Maher (Is Anyone Else Seeing This?)",
        "Brett Goldstein (The Second Best Night Of Your Life)",
        "Kevin Hart (Acting My Age)",
        "Kumail Nanjiani (Night Thoughts)",
        "Ricky Gervais (Mortality)",
        "Sarah Silverman (Postmortem)"
      ]},

      # Podcast Category
      {"Best Podcast", [
        "SmartLess",
        "Armchair Expert With Dax Shepard",
        "Good Hang With Amy Poehler",
        "The Mel Robbins Podcast",
        "Call Her Daddy",
        "Up First"
      ]}
    ]
  end
end
