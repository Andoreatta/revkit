Read this in: [English](README.md) | [Português (Brasil)](README.pt-BR.md)

# RevKit

RevKit is a Phoenix/LiveView payload studio for composing, validating, and
copying offensive-security payload strings for authorized testing. It is a
pure-string pipeline: it never executes or spawns a payload.

## Identification

- **Course:** Software Development Project I and II
- **Mode:** Pair project
- **Authors:** Lucas Andreatta and Leandro Sakae Kobayashi Ostruka
- **Repository:** https://github.com/andoreatta/revkit

## Status

- **Part I — Documentation:** available in the [PDF](docs/documentacao.pdf).
- **Part II — Implementation:** working Phoenix/LiveView application, verified
  with `mix precommit`, and packaged for Docker.

## Stack

**Elixir, Phoenix, LiveView, Ecto, SQLite.**

## What the system does

- Composes reverse-shell, bind-shell, wrapper, and encoder templates with
  `{{VARIABLE}}` placeholders and target metadata.
- Renders an ordered transform chain with live preview and copy support.
- Validates compatibility against the declared target OS, shell, and available
  tools, surfacing requirements and pitfalls before copying.
- Saves complete generation recipes and maintains a public read-only catalog
  with cookie-scoped private editions.

## How to run

**Requirements:** Elixir 1.17+ and OTP 27+. SQLite is embedded through
`ecto_sqlite3`; no separate database server is required.

### Local

```bash
mix setup
mix phx.server
```

Open <http://localhost:4000>. `mix setup` installs dependencies, creates,
migrates, and seeds the SQLite database, and builds the assets.

Tests and quality gate:

```bash
mix test
mix precommit
```

Reset the database and reload the starter catalog:

```bash
mix ecto.reset
```

### Docker

```bash
cp .env.example .env
# Generate a secret and put it in SECRET_KEY_BASE in .env:
openssl rand -base64 48
docker compose up --build
```

Open <http://localhost:4000>. The Compose file binds to `127.0.0.1:4000` by
default and persists SQLite in the `revkit_data` volume. Docker starts with an
empty catalog; load the starter catalog with:

```bash
docker compose exec revkit /app/bin/seed
```

Stop the container:

```bash
docker compose down     # keeps the SQLite volume
docker compose down -v  # deletes the volume
```

## Documentation

- [Full documentation (PDF)](docs/documentacao.pdf)
- [Project diagrams](docs/diagramas/) — Use Case, activity, class, DER,
  architecture, one sequence diagram per use case (UC01–UC09), and
  deployment (Portuguese labels). Regenerate with `./docs/build.sh`.

## Defense videos

- **Part I — Documentation:** [video link](VIDEO_URL_PART_I)
- **Part II — Implementation:** [video link](VIDEO_URL_PART_II)

## Project structure

- `lib/revkit/engine/` — pure string-transform engine; no Ecto, Phoenix, or
  side effects.
- `lib/revkit/catalog/` — Ecto schemas and the `Revkit.Catalog` context;
  SQLite persistence and owner-scoped queries.
- `lib/revkit_web/` — Phoenix/LiveView interface, routes, components, and
  cookie-based ownership.

## Scope and notes

- The project generates and validates strings only; it never executes payloads.
- There is no authentication or JSON API. A signed cookie scopes private
  editions to one browser; it is not a security boundary, and clearing the
  cookie loses access to those editions.
- SQLite is single-writer; run one application instance.
