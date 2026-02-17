# Slack Summary

Multi-workspace Slack event ingestion, summarization, and action-item extraction.
Built on Supabase (Edge Functions + Postgres) and the Slack Events API with user tokens.

## How It Works

A single Slack app is installed into each workspace with a **user token** (`xoxp-`).
All installations share one webhook endpoint. Incoming events are stored in Postgres,
then a scheduled edge function summarizes activity and extracts action items using Claude.
Stale data older than 3 days is purged nightly.

## Schema

See [schema.mermaid](schema.mermaid) for the full ER diagram.

## Edge Functions

| Function         | Trigger        | Purpose                                    |
| ---------------- | -------------- | ------------------------------------------ |
| `slack-events`   | HTTP POST      | Receive and store Slack webhook events      |
| `summarize`      | Cron (daily)   | Generate channel digests and action items   |
| `cleanup`        | Cron (nightly) | Purge events/summaries older than 3 days   |

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design decisions, database schema, and constraints.
