# RevKit

RevKit generates and validates offensive-security payload strings: reverse
shells, wrappers, and encoders. It is a **pure-string pipeline** — it never
executes, spawns, or shells out to a payload.

The app is a Phoenix 1.8 + LiveView browser UI with SQLite persistence. There is
no JSON API and no authentication by design.

## Features

- Payload templates with `{{NAME}}` variables and live substitution
- Ordered transform chains with live preview
- Built-in transforms: Base64 encode, URL encode, Bash wrapper
- Target metadata (`target_os`, `target_shell`, `target_tools`) with
  compatibility warnings for transform requirements
- Transform pitfalls surfaced before the copy control
- Copy-to-clipboard preview button (colocated LiveView hook)
- Payload CRUD with tags, notes, favorites, and target metadata
- Saved recipe snapshots containing template, variable values, chain, target
  metadata, notes, tags, and favorite status
- Recipe reopen, fork, search, and payload/recipe search
- Tag management (create, rename, delete) plus payload/recipe tag assignment
- Favorite and tag filters in the payload and recipe catalogs
- Responsive catalog pages, context pages, and a mobile navigation menu
- Curated starter catalog with target assumptions and usage context
- Nonce-based Content-Security-Policy
- Quality gates: Credo, Sobelow, Dialyzer, ExUnit

## Requirements

- Elixir ~> 1.17 / OTP 27+ for local development
- Docker and Docker Compose for containerized runs

## Local development

```bash
mix setup
mix phx.server
```

Visit <http://localhost:4000>.

Run the full gate before committing:

```bash
mix precommit
```

The first `mix dialyzer` run builds PLTs under `priv/plts/` (gitignored).

## Docker

### Quick start

```bash
cp .env.example .env
# Put a real secret in .env:
openssl rand -base64 48

docker compose up --build
```

Visit <http://localhost:4000>. The compose file binds to `127.0.0.1` by
default, which is intentional because the app has no authentication.

Useful commands:

```bash
docker compose logs -f revkit
docker compose down          # keeps the SQLite volume
docker compose down -v       # deletes the database volume
docker compose exec revkit /app/bin/seed   # load the curated demo catalog
```

The image is a multi-stage production build: assets are compiled in the builder,
and the runtime image contains an Elixir release running as a non-root user.

### Environment

| Variable | Purpose | Default |
|---|---|---|
| `SECRET_KEY_BASE` | Cookie/session signing secret; **required** | — |
| `PHX_HOST` | Public host used by URL generation and `force_ssl` | `example.com` |
| `PORT` | Container HTTP port | `4000` |
| `DATABASE_PATH` | SQLite file inside the container | `/data/revkit.db` |
| `REVKIT_BIND` | Compose host binding | `127.0.0.1` |
| `REVKIT_PORT` | Compose host port | `4000` |
| `POOL_SIZE` | Ecto pool size | `5` |

`REVKIT_BIND` and `REVKIT_PORT` are Compose interpolation variables; the rest are
passed to the release.

### Database and migrations

The SQLite database lives at `DATABASE_PATH` (`/data/revkit.db` by default) and
is persisted in the `revkit_data` Docker volume. Migrations run automatically in
the container entrypoint before the server starts.

SQLite supports one writer. Run a single container; do not horizontally scale
this service. Back up the volume or the `.db` file (and its WAL files) while the
app is stopped or with SQLite's backup tooling.

### Hosting online

Put a TLS-terminating reverse proxy in front of the container. Keep the app on
a private interface and point the proxy at it. Example Caddy config:

```caddyfile
revkit.example.com {
  reverse_proxy 127.0.0.1:4000
}
```

Then set:

```env
PHX_HOST=revkit.example.com
REVKIT_BIND=127.0.0.1
```

The production config enables `force_ssl` and trusts `X-Forwarded-Proto`; make
sure the proxy sets that header. `localhost` and `127.0.0.1` are excluded from
the redirect so local Docker access works without TLS.

**Security note:** there is no authentication. Anyone who can reach the app can
generate payloads and edit the catalog. If it is exposed publicly, protect it
with network ACLs, a VPN, or an authenticating proxy. Do not expose it
accidentally.

### Building and running without Compose

```bash
docker build -t revkit:local .
docker run --rm \
  -p 127.0.0.1:4000:4000 \
  -e SECRET_KEY_BASE="$(openssl rand -base64 48)" \
  -e PHX_HOST=localhost \
  -v revkit_data:/data \
  revkit:local
```

The image includes a `HEALTHCHECK` against `/health`. To customize the base
images, pass build arguments:

```bash
docker build \
  --build-arg ELIXIR_IMAGE=hexpm/elixir:1.20.4-erlang-29.1.1-debian-bookworm-20261005-slim \
  --build-arg RUNTIME_IMAGE=debian:bookworm-slim \
  -t revkit:local .
```

## Routes

| Path | Purpose |
|---|---|
| `/`, `/generate` | Generator and live preview |
| `/payloads` | Payload catalog |
| `/payloads/new`, `/payloads/:id/edit` | Payload forms |
| `/payloads/:id` | Payload context page |
| `/recipes` | Saved recipe snapshots |
| `/recipes/new`, `/recipes/:id/edit` | Recipe forms |
| `/recipes/:id` | Recipe snapshot page |
| `/tags` | Tag curation |
| `/health` | Container liveness check |
| `/dev/dashboard` | LiveDashboard, dev only |

## Starter catalog

`mix setup` and `mix ecto.reset` load an idempotent demo catalog:

- Bash TCP, netcat FIFO, Python 3, Socat PTY, PowerShell, Bash bind,
  netcat bind, and Perl reverse/bind templates
- Base64, URL-encode, and Bash-wrapper recipes, including transport-encoded
  variants
- Tags, favorites, notes, target assumptions, and a “when to use” description
  for every entry

The seeds are templates for **authorized labs, CTFs, and scoped engagements**.
They are strings only; RevKit never executes them. Encoded recipes are transport
payloads and must be decoded before use.

For Docker, load the same catalog once with:

```bash
docker compose exec revkit /app/bin/seed
```

## Architecture

- `Revkit.Engine.*` is pure: no Ecto, Phoenix, IO, or process state.
- `Revkit.Catalog` is the only domain module that touches `Revkit.Repo`.
- Transforms implement `Revkit.Transform`; recipe keys are resolved through
  `Revkit.Engine.Transforms`.
- `Revkit.Engine.Template` performs `{{NAME}}` substitution without escaping or
  execution.
- `Revkit.Engine.Chain` halts on the first error.
- `Revkit.Engine.Validator` compares transform requirements with payload target
  metadata and reports pitfalls; it never probes the target.
- LiveViews call `Catalog` and `Engine`; they never call `Repo`.
- The copy button reads the preview from a `data-*` attribute via a colocated
  hook; there is no vendored JS file.

## Known limitations

- No JSON API.
- No authentication or multi-user accounts.
- SQLite single-instance deployment only.
- Transform `requires` are capability strings compared with target metadata;
  they cannot prove that a remote host actually has the capability.
- Variable values are plain strings; there is no shell escaping or execution.
- The copy hook is browser-side; its markup/CSP wiring is tested, but a full
  clipboard test is manual.

## Quality gate

`mix precommit` runs:

```text
compile --warnings-as-errors
deps.unlock --unused
format
credo
sobelow --skip
test
dialyzer
```

See [`AGENTS.md`](AGENTS.md) for architecture rules and contributor conventions.
