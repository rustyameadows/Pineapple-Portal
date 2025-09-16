# Pineapple Portal

Minimal Rails 8 skeleton for the Pineapple Productions portal. Ships with a PostgreSQL-backed `User` table and a welcome screen that lists seeded records so you can verify the database wiring right away.

## Stack
- Ruby 3.3.6 (managed with rbenv)
- Rails 8.0.2.1
- PostgreSQL 16
- Node.js 24 (runtime for Rails asset tooling)

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
bin/rails server     # or bin/dev for the foreman/dev server
```

Visit http://localhost:3000 to see the welcome screen and seeded users. Run `bin/rails db:seed` any time you want to re-populate the demo data.

### Tests
```bash
bin/rails test
```

## Render Deployment
Render is configured via `render.yaml`, `Procfile`, and `bin/render-build.sh`.

1. Push this repository to GitHub/GitLab and connect it as a Render Blueprint.
2. Render will provision the `pineapple-portal-db` PostgreSQL instance defined in `render.yaml` and expose `DATABASE_URL` to the web service.
3. Add the `RAILS_MASTER_KEY` environment variable in the Render dashboard (grab it from `config/master.key` or `bin/rails credentials:edit`).
4. Deploy—Render runs `bin/render-build.sh`, which installs gems, precompiles assets, and migrates the database.

Health checks hit `/up`. Adjust the plan/region in `render.yaml` as needed before deploying.

## Next Steps
- Replace the sample welcome view with real content or a dashboard.
- Expand the `User` schema and add authentication/authorization when ready.
- Configure CI (GitHub Actions workflow scaffolded by Rails is ready in `.github/workflows/ci.yml`).
