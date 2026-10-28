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
- A public, read-only catalog of payloads and recipes
- Per-browser private editions created with **Improve**; other cookies never see
  them and the public original is never modified
- No public delete: only a private edition can be discarded
- Saved recipe snapshots containing template, variable values, chain, target
  metadata, notes, tags, and favorite status
- Recipe reopen, search, and owner-scoped payload/recipe search
- A fixed tag vocabulary (24 tags, at most 3 per entry), shown read-only
- Favorite and tag filters for the current browser's editions
- Explicit limits for fields, variables, steps, tags, and private editions
- Responsive catalog pages, context pages, and a mobile navigation menu
- Curated starter catalog with target assumptions and usage context
- Nonce-based Content-Security-Policy
- Quality gates: Credo, Sobelow, Dialyzer, ExUnit

## Public catalog and private editions

The seeded payloads and recipes are public and read-only. **Improve** copies a
public entry into a private edition owned by your browser; **New private
payload/recipe** creates one from scratch. Your editions appear alongside the
public catalog only for your cookie.

- The public original is never hidden, edited, or deleted.
- Other browsers continue to see the public original and their own editions.
- `Discard edition` deletes only your private copy.
- Tags are a fixed vocabulary and cannot be created, renamed, or deleted in the
  UI.
- Clearing cookies starts a new empty identity; private editions are not
  recoverable without the original cookie.

This is intentionally **not** an account system. See the security note below.

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

**Security note:** there is no authentication. The public catalog is read-only,
and a signed one-year cookie scopes private editions to one browser, but that
cookie is identity, not access control. Anyone who can reach the app can read
the public catalog and create their own editions; clearing the cookie loses
access to the previous editions. If the app is exposed publicly, protect it with
network ACLs, a VPN, or an authenticating proxy. Do not expose it accidentally.

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
| `/payloads` | Public payload catalog + your editions |
| `/payloads/new` | New private payload |
| `/payloads/:id/edit` | Edit your payload edition |
| `/payloads/:id` | Payload context page (public or your edition) |
| `/recipes` | Public recipe catalog + your editions |
| `/recipes/new` | New private recipe |
| `/recipes/:id/edit` | Edit your recipe edition |
| `/recipes/:id` | Recipe snapshot page (public or your edition) |
| `/tags` | Read-only tag vocabulary and usage |
| `/health` | Container liveness check |
| `/dev/dashboard` | LiveDashboard, dev only |

## Starter catalog

`mix setup` and `mix ecto.reset` load an idempotent demo catalog:

- Bash TCP, netcat FIFO, Python 3, Socat PTY, PowerShell, Bash bind,
  netcat bind, and Perl reverse/bind templates
- Base64, URL-encode, and Bash-wrapper recipes, including transport-encoded
  variants
- A fixed 24-tag vocabulary, notes, target assumptions, and a “when to use”
  description for every entry; at most three tags per entry

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
- Public rows have `owner_id = nil`; private editions carry a cookie owner and a
  `source_*_id` pointing at the public row they improve. Catalog reads return
  public + current-owner rows only, and public writes are rejected.
- `Revkit.Limits` defines every field, variable, step, tag, and quota limit.
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
- No authentication or multi-user accounts. A signed cookie scopes private
  editions to one browser; clearing it loses them, and it is not a security
  boundary.
- The public catalog cannot be edited or deleted from the UI; changes are
  private editions.
- Tags are a fixed, seeded vocabulary; there is no tag CRUD.
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
