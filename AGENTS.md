# RevKit

Phoenix 1.8 + LiveView 1.2 app (Elixir ~> 1.17) with a browser UI.
Persistence is SQLite via `ecto_sqlite3`, not Postgres. Assets are Tailwind v4 +
daisyUI + Heroicons, bundled by esbuild through Mix tasks; there is no
`package.json` or Node toolchain.

The app generates and validates offensive-security payloads (reverse shells,
wrappers, encoders). It is a pure-string pipeline: it does **not** execute
anything. The pure engine (`Revkit.Transform`, `Revkit.Engine.Chain`,
`Revkit.Engine.Transforms`, `Revkit.Engine.Template`, `Revkit.Engine.Validator`),
the persistence layer (`Revkit.Catalog`), and the LiveView UI (`GenerateLive`,
`PayloadLive.*`, `RecipeLive.*`, `TagLive.Index`) are in place. `/` and
`/generate` both open the generator. This file describes the target architecture;
update the stale lines as the code lands.

## Commands

```bash
mix setup        # deps, DB create/migrate/seed, build assets
mix phx.server   # http://localhost:4000 (Bandit); or: iex -S mix phx.server
mix test         # alias: ecto.create --quiet, ecto.migrate --quiet, test
mix test test/revkit_web/controllers/page_controller_test.exs
mix test test/path_test.exs:42
mix precommit    # compile --warnings-as-errors, deps.unlock --unused, format, credo, sobelow --skip, test, dialyzer
mix credo        # strict rules from .credo.exs
mix sobelow --skip # honors annotated # sobelow_skip findings
mix dialyzer     # type analysis; PLTs live in priv/plts (ignored)
mix ecto.reset   # drop, recreate, migrate, seed
mix assets.build # compile + tailwind + esbuild
mix assets.deploy # minified assets + phx.digest (production)
docker compose up --build # production image + SQLite volume
docker compose down -v # stop and delete the SQLite volume
```

`mix precommit` is the gate: compile warnings fail it, and it runs `format`
(writes files), not a check-only format. It also runs strict Credo, Sobelow,
the test suite, and Dialyzer. Run it before considering any task done. The first
`mix dialyzer` run builds PLTs in `priv/plts/`; they are gitignored. Do not
reintroduce ad-hoc lint/type/security commands outside the precommit alias.

## Structure

- `lib/revkit/` — domain and OTP: `Revkit.Repo`, `Revkit.Application`.
  - `lib/revkit/engine/` — pure payload engine: `Chain`, the `Transforms`
    registry, `Transforms.*`, `Template`, and `Validator`. **← NOVO**
  - `lib/revkit/catalog/` — Ecto schemas (`Payload`, `Recipe`, `Tag`) and the
    `Revkit.Catalog` context. `Payload` is a curated template with tags, target
    metadata, notes, and a favorite flag. `Recipe` is a saved generation
    snapshot: template, variable values, ordered transform steps as JSON
    (`%{"key" => ..., "options" => ...}`), target metadata, notes, favorite, and
    tags; reopening it must reproduce the exact saved combination. **← NOVO**
- `lib/revkit_web/` — endpoint, router, controllers, components, layouts.
- `lib/revkit_web.ex` — single macro entrypoint (`use RevkitWeb, :live_view |
  :controller | :html`). Put app-wide imports/aliases in `html_helpers`.
- `lib/revkit_web/router.ex` — `:browser` pipeline only; there is no JSON API.
  `/dev/dashboard` exists only when `:dev_routes` is true (set in
  `config/dev.exs`). The LiveDashboard is a **dev-only observability tool**, not
  a domain feature — do not surface it in the product, do not remove it from
  `dev`. **← NOVO**
- `lib/revkit_web/plugs/content_security_policy.ex` — nonce-based CSP for the
  browser pipeline. Inline scripts must use `nonce={@csp_nonce}`; the
  LiveDashboard is configured with `csp_nonce_assign_key: :csp_nonce`.
- `RevkitWeb.CoreComponents` — `flash`, `button`, `input`, `table`, `list`,
  `header`, `icon`. `RevkitWeb.Layouts` — `app/1`, `flash_group/1`,
  `theme_toggle/1`, plus `layouts/root.html.heex`.
- `lib/revkit_web/live/` — `GenerateLive` (`/` and `/generate`), `PayloadLive.Index`/
  `Form`/`Show` (`/payloads`), `RecipeLive.Index`/`Form`/`Show` (`/recipes`),
  and `TagLive.Index` (`/tags`). GenerateLive's `phx-change` handler updates the
  template/variable/chain form and `:preview` but never calls Catalog or Repo.
  CRUD forms own their form assigns.
- `lib/revkit_web/components/step_editor.ex` — shared ordered transform editor
  used by the generator and recipe form.
- `lib/revkit_web/components/ui.ex` — small shared presentation components
  (empty state, target/tag badges, favorite button, code block).
- New LiveViews belong in `lib/revkit_web/live/` as `RevkitWeb.XLive`; routes can
  use `live "/x", XLive` because the browser scope is aliased to `RevkitWeb`.
- `Dockerfile`, `compose.yaml`, `.env.example`, and `docker/entrypoint.sh` — the
  production image is a multi-stage Elixir release running as a non-root user.
  `lib/revkit/release.ex` runs migrations inside the release; the entrypoint
  migrates, then starts the server. `bin/seed` loads the curated demo catalog.

## Revkit Architecture (domain rules)

The most important rule in this project: **the engine is pure**. Break it and
the design collapses.

- **`Revkit.Engine.*` must be pure.** No `Ecto`, no `Phoenix`, no `Repo`, no
  `File`, no HTTP, no `GenServer`. Inputs are strings and maps; outputs are
  `{:ok, string} | {:error, term}`. This is what makes the LiveView preview
  cheap and the unit tests trivial.
- **`Revkit.Catalog` is the only place that touches `Revkit.Repo`.** LiveViews
  and the engine never call `Repo.*` directly. LiveViews call `Catalog` and
  `Engine`; the engine calls nothing outside itself.
- **Direction of dependency:** `RevkitWeb.Live → Revkit.Catalog → Revkit.Repo`
  and `RevkitWeb.Live → Revkit.Engine`. Never the reverse. The engine must not
  depend on the catalog.
- **Transforms are modules implementing `Revkit.Transform`.** New transforms
  go in `lib/revkit/engine/transforms/<name>.ex` and implement the `@behaviour`
  (`key/0`, `label/0`, `kind/0`, `apply/2`, `requires/0`, `pitfalls/0`).
  Register the module in `Revkit.Engine.Transforms` so recipe keys resolve;
  adding a transform is adding code — never a row in a table.
- **Chain application is `Enum.reduce_while/3`.** On the first `{:error, _}`,
  halt and return it. Do not rescue silently.
- **`Validator` compares metadata; it never executes.** It aggregates
  `requires/0` and `pitfalls/0` from the resolved chain and compares them with
  the payload's declared target metadata (OS, shell, and available tools).
  Missing target metadata produces an unknown-target warning; it never probes or
  executes the target.
- **Phoenix.LiveView uses `Phoenix.PubSub` internally.** Do not add custom
  PubSub topics, Presence, or real-time collaboration. `Revkit.PubSub` is
  framework infrastructure, not a product feature.
- **Offensive-security scope:** the system *generates* and *validates* strings.
  It must never execute, spawn, `System.cmd/3`, or shell out to any payload.
  If a feature would execute a command, it is out of scope.

## Conventions and gotchas

- daisyUI is an active dependency; existing components use its classes (`btn`,
  `alert`, `table`, `fieldset`, `input`, `select`, `checkbox`, `textarea`). Match
  that style instead of hand-rolling equivalents. The `light` (default) and
  `dark` themes are defined in `assets/css/app.css`.
- Branding is **RevKit** in the UI; module names remain `Revkit.*`. The shell is
  a responsive `max-w-7xl` layout with a mobile navigation dropdown, shared
  `RevkitWeb.UI` components, and a terminal-prompt logo in
  `priv/static/images/logo.svg`.
- Quality gates: Credo runs strict from `.credo.exs`; do not disable checks
  without a comment explaining why. Sobelow runs with `--skip`, so only
  annotated `# sobelow_skip` findings are suppressed. Dialyzer must stay at
  zero errors.
- The `# sobelow_skip ["Config.CSP"]` on the `:browser` pipeline is intentional:
  Sobelow only recognizes `put_secure_browser_headers/2`, while the real header
  comes from `RevkitWeb.Plugs.ContentSecurityPolicy`. Keep `--skip` in the
  precommit alias or Sobelow will report a false positive.
- Tailwind v4 has no `tailwind.config.js`. Keep the
  `@import "tailwindcss" source(none)` block and all `@source` lines in
  `assets/css/app.css`, including the `_build/dev/phoenix-colocated/revkit/*/`
  entry used for dev reloads.
- Icons: `<.icon name="hero-x-mark" />`. Heroicons are bundled from
  `deps/heroicons` by `assets/vendor/heroicons.js`.
- esbuild resolves packages from `deps/` via `NODE_PATH`. Vendored browser code
  goes in `assets/vendor/` and is imported from `assets/js/app.js`; do not add
  CDN tags or inline `<script>` tags to templates.
- Colocated hooks/CSS: `app.js` merges `phoenix-colocated/revkit` hooks and
  `app.css` imports its `colocated.css`. Use `phx-hook=".Name"` with a unique DOM
  id and a matching `<script :type={Phoenix.LiveView.ColocatedHook} name=".Name">`;
  add `phx-update="ignore"` when the hook owns its DOM.
  - **The "Copy to clipboard" button uses a colocated hook** (e.g.
    `.CopyToClipboard`), reading the value from a `data-*` attribute bound to
    the preview. Do not add a vendored JS file for this. It does **not** use
    `phx-update="ignore"`: the hook reads `data-copy-value`, which must keep
    updating with the preview. Only ignore updates when the hook owns its DOM.
    **← NOVO**
  - **No CodeMirror/Monaco.** The template field is a plain `<textarea>` with
    monospace classes; a syntax-highlighting editor would require vendoring or
    Node tooling, which is out of scope. **← NOVO**
- HEEx: interpolate attributes with `{...}`; `<%= %>` only works in tag bodies
  and for block constructs (`if`, `for`, `cond`).
- Templates: start with `<Layouts.app flash={@flash}>`, build forms from
  `to_form/2` and render fields with `<.input field={@form[:field]}>`, and give
  forms/buttons stable DOM ids for `has_element?/2` assertions.
- SQLite: dev uses `revkit_dev.db`, test uses `revkit_test.db`, both at the repo
  root. Do not mark DB tests `async: true` (single writer). Use
  `RevkitWeb.ConnCase` / `Revkit.DataCase`; the sandbox is `:manual` in
  `test_helper.exs`. The engine tests, being pure, **can** and **should** be
  `async: true`. **← NOVO (segunda frase)**
- Migrations: `mix ecto.gen.migration name_using_underscores`; schema timestamps
  are `:utc_datetime`.
- Production requires `DATABASE_PATH` and `SECRET_KEY_BASE`
  (`config/runtime.exs`); the SQLite file must live on persistent storage.
- Docker/release: migrations run in the container entrypoint via
  `Revkit.Release.migrate/0`; SQLite is single-writer, so run one container only.
  Keep the app on a private interface and terminate TLS in a reverse proxy. The
  app has **no auth and no JSON API**; protect a public deployment at the network
  layer. `DATABASE_PATH` defaults to `/data/revkit.db`, backed by a volume.
  Docker is packaging/deployment only: the application must not integrate with
  Docker/VM/Vagrant APIs, spawn containers, or manage VMs.
- Quality infrastructure (Credo, Sobelow, Dialyzer, CSP, health checks, and
  packaging) is exempt from the product's five-gap rule; do not expose it as a
  product feature.
- Docker context must exclude `priv/plts`; otherwise Dialyzer PLTs can bloat the
  release image.

## Workflow with the coding agent

- Build in this order: (1) pure engine + ExUnit tests, (2) `Catalog` schemas +
  context, (3) LiveViews, (4) validation/warnings in the UI, (5) colocated hook
  for copy, (6) template variables and target metadata, (7) full saved-generation
  Recipe snapshots and reopening, (8) curation (tags, favorites, notes, search).
  Do not skip ahead — LiveViews generated before the engine works will get
  rewritten.
- Prompt the agent with the layer boundaries explicitly, e.g. *"pure functions
  only, no Ecto, no Phoenix"* for engine work.
- `/undo` relies on Git. Commit after each layer passes `mix precommit`. Use
  `/new` to reset context when the agent drifts; `AGENTS.md` re-establishes the
  rules.
- Do not ask the agent to design the DER, the 5 use cases, or the video
  narrative. Those are decisions you own.
