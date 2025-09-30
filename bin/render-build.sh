#!/usr/bin/env bash
set -o errexit

bundle install

PUPPETEER_CACHE_DIR="$PWD/.cache/puppeteer"
export PUPPETEER_CACHE_DIR
mkdir -p "$PUPPETEER_CACHE_DIR"

npm install
npx puppeteer browsers install chrome
bundle exec rails assets:precompile
bundle exec rails db:migrate
