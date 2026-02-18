# Slack Summary

Multi-workspace Slack event ingestion, summarization, and action-item extraction.
Built on Rails 8 (API-only + SQLite) running locally behind a cloudflared tunnel,
using the Slack Events API with user tokens.

## How It Works

A single Slack app is installed into each workspace with a **user token** (`xoxp-`).
All installations share one webhook endpoint exposed via a cloudflared tunnel.
Incoming events are stored in SQLite, then a recurring solid_queue job summarizes
activity and extracts action items using Claude. Stale data older than 3 days is
purged nightly.

## Schema

See [schema.mermaid](schema.mermaid) for the full ER diagram.

## Controllers & Jobs

| Component                    | Trigger            | Purpose                                    |
| ---------------------------- | ------------------ | ------------------------------------------ |
| `Api::SlackEventsController` | HTTP POST          | Receive and store Slack webhook events      |
| `SummarizeJob`               | solid_queue (daily + on-demand) | Generate channel digests and action items |
| `CleanupJob`                 | solid_queue (nightly) | Purge events/summaries older than 3 days |

## Requirements

- Ruby 3.3+
- Rails 8
- cloudflared
- Anthropic API key

## Setup

```sh
bin/setup              # install deps, create DB, run migrations
cp .env.example .env   # fill in Slack + Anthropic credentials
cloudflared tunnel run  # expose local server to Slack
bin/dev                # start Rails + solid_queue
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design decisions, database schema, and constraints.
