# EGOT - Golden Globe Voting Party App

A real-time voting web app where friends can vote on award show winners just before they're announced. One person acts as MC (master of ceremonies) controlling the game flow, while players connect via their phones to cast votes.

## Tech Stack

- **Elixir/Phoenix LiveView** - real-time UI updates without JavaScript
- **Ecto/PostgreSQL** - persistence (via Docker)
- **Tailwind CSS** - styling
- **phx.gen.auth** - passwordless authentication with magic links

## Prerequisites

- [mise](https://mise.jdx.dev/) - for Elixir/Erlang version management
- [Docker](https://www.docker.com/) - for PostgreSQL

## Getting Started

1. **Install Elixir and Erlang via mise:**
   ```bash
   mise install
   ```

2. **Start PostgreSQL:**
   ```bash
   docker compose up -d
   ```

3. **Setup the database:**
   ```bash
   mise exec -- mix setup
   ```

4. **Start the Phoenix server:**
   ```bash
   mise exec -- mix phx.server
   ```

5. **Visit the app:**
   - App: http://localhost:4000
   - Dev mailbox (for magic links): http://localhost:4000/dev/mailbox

## Current Features

- **User Authentication** - Passwordless magic link authentication
- **MC Dashboard** - Create and manage game sessions at `/mc`
- **Game Sessions** - Create sessions with unique 6-character join codes

## Development

### MC User

A seeded MC user is available for development:
- **Email:** mc@example.com
- **Password:** password123

### Routes

- `/` - Landing page
- `/mc` - MC Dashboard (requires MC user)

### Running Tests

```bash
mise exec -- mix test
```

### Database Commands

```bash
mise exec -- mix ecto.migrate    # Run migrations
mise exec -- mix ecto.reset      # Drop, create, migrate, and seed
```

## Project Structure

```
lib/
├── egot/                    # Business logic
│   ├── accounts/            # User accounts context
│   ├── game_sessions/       # Game sessions context
│   └── repo.ex              # Database repo
└── egot_web/                # Web layer
    ├── components/          # Phoenix components
    ├── controllers/         # Controllers
    ├── live/                # LiveView modules
    │   └── mc_live/         # MC dashboard views
    └── plugs/               # Custom plugs (RequireMC)
```

## License

Private project.
