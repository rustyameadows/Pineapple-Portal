#!/usr/bin/env bash
set -o errexit

bundle install
npm install
npx puppeteer browsers install chrome
bundle exec rails assets:precompile
bundle exec rails db:migrate
