# Pineapple Portal

Minimal Rails 8 skeleton for the Pineapple Productions portal. Ships with PostgreSQL-backed `User` accounts, session-based authentication, event management, reusable questionnaires, versioned documents, and a welcome screen that lists seeded records so you can verify the database wiring right away.

## Stack
- Ruby 3.3.6 (managed with rbenv)
- Rails 8.0.2.1
- PostgreSQL 16
- Node.js 24 (runtime for Rails asset tooling)

## CSS Architecture

Rails 8 uses Propshaft, which serves whatever lives in `app/assets` exactly as-is. To stay modular without introducing a build step, we organise styles into partials inside `app/assets/stylesheets/{base,layout,components,pages,utilities}` and then list the ones we need explicitly in each layout.

### Layout load order
- `app/views/layouts/application.html.erb` (planner UI) loops over a curated list of base tokens/resets, layout chrome, shared components, and planner page styles and emits one `stylesheet_link_tag` for each file.
- `app/views/layouts/client.html.erb` does the same but with the slimmer client portal set.
- Auth screens use the planner layout as-is; you can trim that list or create a dedicated layout later if you need a lighter bundle.

Because every file referenced in the layout corresponds directly to a physical file (e.g. `components/buttons.css`), Propshaft can fingerprint and cache them without chasing CSS `@import` statements. HTTP/2 handles the parallel requests, and you get predictable cascade ordering by arranging the lists.

### Working with styles
1. Drop new rules into the appropriate partial, or create a new file under `components/` or `pages/` if it doesn’t exist yet. Avoid using CSS `@import`; the layout handles inclusion.
2. Add the logical path (without the `.css` extension) to the relevant layout list so it loads on the right surface.
3. Reload the page. In development Propshaft reads straight from disk, so no server restart or build step is required.

If you find yourself reusing a partial in both planner and client layouts, just add it to both lists. Keeping the inclusion explicit makes it easy to see which surfaces depend on which styles, and you can reorganise the order in one place.

## Generated Document Templates

Generated documents stitch together uploaded PDFs and branded HTML segments. All branded segments live under `app/views/generated_documents/sections` and share a common set of primitives so the builder preview, template gallery, and compiled Grover PDF stay in sync.

### Shared base styles & tokens

Every segment may opt-in to the shared base styles by rendering the partial at the top of the template:

```erb
<% if local_assigns.fetch(:render_base_styles, true) %>
  <%= render "generated_documents/sections/base_styles" %>
<% end %>
```

`_base_styles.html.erb` defines typography, table rules, and brand tokens (e.g. `--color-dark-brown`, `--color-light-cream`, `--color-white`). Templates should rely on these tokens rather than hard-coded colours (only black/white fallbacks are acceptable). Sections can override any token—for example, Section Break sets `--page-bg` and `--color-ink` so its title renders light-on-dark.

### Preview frame

`_preview_styles.html.erb` and `_preview_frame.html.erb` supply the 8.5"×11" preview chrome. The builder preview layout (`app/views/layouts/generated_preview.html.erb`) renders both partials; the template gallery loads the styles once and wraps each snippet with `_preview_frame`. Gallery cards apply `.template-card__preview-frame` overrides so the scaled page fills the card without the external shadow/padding.

### Creating a new branded section

1. Register the view in `DocumentSegment::HTML_VIEWS` (label, description, template path).
2. Add `app/views/generated_documents/sections/<key>.html.erb`. Keep the guarded `render_base_styles` call shown above.
3. Define any template-specific `<style>` blocks inside the view. Scope selectors to the template, use tokens (`--page-bg`, `--color-ink`, brand colours) instead of literals, and set additional tokens if needed.
4. Preview the segment from the builder and the template gallery—both paths now rely on the same preview frame, so what you see should match the compiled PDF.

### Event photo hook

Events may reference one of their uploaded image documents as a hero photo (`event.event_photo_document`). Branded templates can reuse it via helpers—e.g., the cover page calls `inline_document_image_data_uri(event.event_photo_document)` to embed the image when present.

## Local Environment

### Prerequisites
1. Update Homebrew and install toolchain dependencies:
   ```bash
   brew update
   brew install rbenv ruby-build postgresql@16 pkg-config node libyaml libffi
   ```
2. Ensure rbenv is available in every shell:
   ```bash
   echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
   echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
   exec zsh
   ```
3. Install Ruby 3.3.6 and set it globally:
   ```bash
   RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)" rbenv install 3.3.6
   rbenv global 3.3.6
   ```
4. Install Bundler, Rails, and PostgreSQL client headers:
   ```bash
   gem install bundler
   gem install rails -v "~> 8.0"
   echo 'export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"' >> ~/.zshrc
   echo 'export LDFLAGS="-L/opt/homebrew/opt/postgresql@16/lib $LDFLAGS"' >> ~/.zshrc
   echo 'export CPPFLAGS="-I/opt/homebrew/opt/postgresql@16/include $CPPFLAGS"' >> ~/.zshrc
   exec zsh
   ```

Node.js 24.8.0 (or any current LTS) is sufficient—no extra configuration needed beyond Homebrew install.

### Project Setup
```bash
bundle install
bin/rails db:setup   # creates databases, runs migrations, seeds sample users
npm install          # installs Puppeteer dependency for Grover
bin/rails server     # or bin/dev for the foreman/dev server
```

Chromium for Grover/Puppeteer downloads automatically via the `postinstall` script. If you prefer to run it manually, execute `npx puppeteer browsers install chrome` after `npm install`.

Visit http://localhost:3000 after boot (you’ll be redirected to log in first). The seed data creates two demo accounts with password `password123`, a sample event with questionnaires (including a template), and a placeholder document.

### Authentication & First User
- Log in at http://localhost:3000/login using any seeded account (`ada@example.com` / `password123`).
- If the database is empty, visit http://localhost:3000/users/new to create the first account; the app automatically signs you in after that.
- Once signed in, you’ll land on the event dashboard. Head to `/users` (linked in the sidebar) whenever you need to invite more teammates.
- Client users sign in at http://localhost:3000/portal/login. Create a client user via `/users` (set the role to “client”), then grant event access from **Event → Settings → Planning Team → Client Access**.
- Need to help a client who forgot their password? From that same Client Access table, hit “Generate Reset Link” to mint a shareable URL. Links stay valid for 30 days (or until used) and surface right in the table so you can copy them any time.

### Tests
```bash
bin/rails test
```

## Event Planning Features

- **Events** – create and manage engagements, each with its own questionnaires, documents, and attachments. Events now support archiving via `archived_at`, letting the dashboard separate active and archived work.
- **Dashboard** – signed-in users see an event card grid with quick links to settings and documents, plus direct access to the questionnaire template library.
- **Event View** – each event renders inside the new sidebar layout with a hero panel (dates/location/status), grouped event links, and a recent activity rail. The sidebar navigation doubles as the primary app chrome and includes placeholders for upcoming areas (calendars, payments, signatures, etc.).
- **Questionnaires** – build checklists for an event and optionally flag them as templates for later reuse. Questionnaires now support ordered sections with helper copy, so planners can organize large forms. The editor lets you drag sections and questions, and move questions between sections. Templates display in `/questionnaires/templates`.
- **Documents** – upload documents to Cloudflare R2 (via the presign flow), keep a full version history by reusing a logical ID, and attach them to events, questionnaires, or individual questions.
- **Attachments** – tie documents to prompts/help/answers with ordered positions so questionnaires can surface supporting files. Answer attachments accept one-off uploads; just drop a file and the app stores a new document for that response.
- **Settings Stubs** – `/events/:id/settings` and related sub-pages provide placeholders for upcoming configuration flows (team permissions, notifications) while designers iterate.

## Cloudflare R2 Configuration

The app talks to R2 via `app/services/r2/storage.rb` using the AWS SDK. Set these environment variables before running features that generate signed URLs:

```
R2_ACCOUNT_ID=xxxx
R2_BUCKET=pineapple-portal
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
# Optional overrides
R2_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com
R2_REGION=auto
```

Provide those values locally (e.g. in `.env`) and on Render. When deploying, add them to the Render service environment along with `DATABASE_URL` and `RAILS_MASTER_KEY`.

### Local secrets file

`dotenv-rails` loads environment files automatically in development and test. Copy the example file and fill in your credentials:

```bash
cp config/r2.env.example .env.local
```

Edit `.env.local` with your actual keys. The file is already ignored by git (`.gitignore`). `bin/rails server` / `bin/dev` will pick it up automatically after restart.

## Render Deployment
Render is configured via `render.yaml`, `Procfile`, and `bin/render-build.sh`.

1. Push this repository to GitHub/GitLab and connect it as a Render Blueprint.
2. Render will provision the `pineapple-portal-db` PostgreSQL instance defined in `render.yaml` and expose `DATABASE_URL` to the web service.
3. Add the `RAILS_MASTER_KEY` environment variable in the Render dashboard (grab it from `config/master.key` or `bin/rails credentials:edit`).
4. Deploy—Render runs `bin/render-build.sh`, which installs gems, precompiles assets, and migrates the database. Seed data does not run automatically; log in and add users/events/questionnaires through the UI once deployed.

Health checks hit `/up`. Adjust the plan/region in `render.yaml` as needed before deploying.

## Next Steps
- Replace the placeholder welcome view with production UI.
- Layer on authorization (roles/permissions) once requirements are defined.
- Build flows for generating questionnaires from templates per event.
- Configure CI (GitHub Actions workflow scaffolded by Rails is ready in `.github/workflows/ci.yml`).
