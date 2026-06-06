# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

A scheduled data pipeline that scrapes Mozilla SUMO (support.mozilla.org) for Thunderbird desktop forum questions ("Ask a Question" / AAQ) and their answers, stores them as per-day CSV files, and provides Ruby/[Miller (`mlr`)](https://miller.readthedocs.io/) scripts to aggregate, classify, and report on them. The CSVs are checked into git and queried with [Datasette Lite](https://lite.datasette.io/) / SQLite. This is a data archive, not a deployed application — there are no automated tests.

## Setup & running

```bash
bundle install          # Ruby 3.2; re-run whenever the Gemfile changes
```

Scripts are run via `bundle exec ./<script>.rb`. Most data-fetching scripts take `yyyy mm dd` date arguments and **must be run from inside the year directory** (e.g. `cd 2025`) because output filenames and the questions→answers lookup are resolved relative to the cwd. The `..` prefixes in the orchestrator scripts reflect this.

```bash
# Fetch questions for a date range (run from inside e.g. 2025/)
cd 2025 && ../get-tb-creator-answers-questions-for-arbitrary-time-period.rb 2025 6 1 2025 6 1

# Fetch answers — requires the matching questions CSV to already exist
cd 2025 && ../get-tb-answers-from-questions-file-for-arbitrary-time-period.rb 2025 6 1 2025 6 1

# Fetch both questions+answers for N consecutive days (orchestrator, run from repo root)
./get_questions_answers_for_n_days_starting.rb 2025 6 1 30

# What the GitHub Actions cron actually runs each time (today + 1 of the last 13 days)
bundle exec ./get_answers_for_last_2_days_and_1_of_last_12.rb
```

## Architecture

### Data flow
1. **Fetch questions** (`get-tb-creator-answers-questions-for-arbitrary-time-period.rb`) — pages the SUMO API `/api/2/question/` filtered by `product=thunderbird`, flattens nested fields (tags, answers, involved, metadata, creator) into a single CSV row each, and writes `YYYY-MM-DD-YYYY-MM-DD-thunderbird-creator-answers-desktop-all-locales.csv`.
2. **Fetch answers** (`get-tb-answers-from-questions-file-for-arbitrary-time-period.rb`) — reads the question IDs out of that questions CSV, queries `/api/2/answer/?question=<id>` for each, and writes `...-thunderbird-answers-for-questions-desktop.csv`.
3. **Aggregate / report** — Miller and Ruby scripts combine the daily CSVs into yearly/all-time files, classify content, and render reports.

Output files always span a single day (`start == end`); the date range capability exists but the schedulers only ever request one day at a time. Filenames are the integration contract between stages — `get_questions_filename.rb` centralizes the questions-CSV name format so the answers stage can find its input.

### Shared helpers (`require_relative`)
- `get-kitsune-response.rb` — the single HTTP entry point (`getKitsuneResponse`). Uses Typhoeus, retries JSON parse failures up to 4× with backoff (60s on 429/500/502, else 2s), returns `nil` on giving up. All scripts sleep ~2s between API calls to be polite to SUMO.
- `fix-kludged-time.rb` — **obsolete timezone correction, no longer called.** The SUMO/Kitsune API *used to* return Pacific-time timestamps mislabeled with a `Z` (UTC) suffix (Kitsune bugs [#3961](https://github.com/mozilla/kitsune/issues/3961), [#3946](https://github.com/mozilla/kitsune/issues/3946)), and `kludge_time_from_bogusZ_to_utc` corrected for it. The API now returns truthful UTC, so the fetch scripts store `created`/`updated` as-is via `Time.parse(...).utc` (verified against question HTML sources, 2026-06). The kludge file is kept only as historical reference. **Consequence:** CSVs are formatted `YYYY-MM-DD HH:MM:SS +0000` from the fix forward, but `-0700`/`-0800` (Pacific-offset) before it; rows scraped while the API had already switched but the kludge was still active are wrong by +7h/+8h and need backfilling. Date-range queries still pad ±1 day (Kitsune [#3686](https://github.com/mozilla/kitsune/issues/3686)) and re-filter in Ruby.
- `regexes.rb` — large table of regexes mapping question text to emoji + tag names for OS (macOS/Linux/Windows), antivirus vendors, and email providers (Gmail/Microsoft/Yahoo/etc.). Consumed by the classification/reporting scripts.

### Reporting & classification scripts
- `get-regular-expression-matches.rb`, `create-daily-summary-csv.rb` — apply `regexes.rb` to classify questions; emit regex-match and daily-summary CSVs.
- `create-daily-report.rb` — Markdown report with SUMO links and tag chips.
- `get-response-metrics.rb` — response-time metrics from question/answer timestamps.
- `create-sparkline-for-dates.rb` / `create-unicode-sparkline-for-dates.rb` / `create-bar-for-dates.rb` — visualizations; `spark_pr.rb` is a vendored pure-Ruby sparkline (PNG/ASCII) library.
- `generate_datasette_url_for_questions_for_a_month.rb` — builds a Datasette Lite URL preloading a month of CSVs.
- `.mlr` files are Miller DSL snippets: `make-question-link.mlr` / `make-question-link-for-replies.mlr` derive a `link` column from an id; `get-unanswered.mlr` filters to questions with no answers.

### Directory layout
- `2022/`–`2030/` — per-year directories of daily CSVs; scripts cd into these. (Future years are empty placeholders.)
- `ALLTIME/` — yearly and all-time concatenated CSVs.
- `CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/` — arbitrary multi-day concatenations.
- `SQLITE/` — generated SQLite databases (via `csvs-to-sqlite`) and Metabase files.

### Automation
Two GitHub Actions workflows (`.github/workflows/main.yml`, `answers.yml`) run on cron (a few times per hour), execute `get_answers_for_last_2_days_and_1_of_last_12.rb`, and auto-commit any changed CSVs back to `main`. That script tracks how many times it has run in `.answer_poll_count.txt` and uses the count to rotate which of the last ~13 days it refreshes alongside today. Expect frequent automated "Latest Thunderbird desktop questions" commits on `main`.

## Aggregation idioms

Prefer Miller (`mlr`) over the Ruby concat scripts for combining CSVs (see README for many examples). Common patterns:

```bash
# Concatenate + sort a year of daily question CSVs
mlr --csv sort -f id 2025/*thunderbird-creator-answers-desktop-all-locales.csv > year.csv

# Open every question link for a day in the browser, paced
mlr --csv --headerless-csv-output put -f ../make-question-link.mlr then cut -f link <daily.csv> \
  | xargs -n 1 -I % sh -c 'sleep 5; open %;'

# Build a SQLite DB from a CSV with datetime columns
csvs-to-sqlite questions.csv -dt created -dt updated questions.db
```
