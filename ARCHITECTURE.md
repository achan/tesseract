# Slack Summary — Architecture

Multi-workspace Slack event ingestion, summarization, and action-item extraction.
Built on Supabase (Edge Functions + Postgres) and the Slack Events API with user tokens.

## Overview

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Workspace A │   │  Workspace B │   │  Workspace C │
│  (user token)│   │  (user token)│   │  (user token)│
└──────┬───────┘   └───────┬──────┘   └───────┬──────┘
       │  Events API       │                  │
       └──────────────┬────┴──────────────────┘
                      ▼
          ┌───────────────────────┐
          │  Supabase Edge Func   │
          │  POST /slack-events   │
          │  (single endpoint)    │
          └───────────┬───────────┘
                      ▼
          ┌───────────────────────┐
          │     Supabase DB       │
          │  - raw events         │
          │  - channels config    │
          │  - workspace tokens   │
          └───────────┬───────────┘
                      ▼
          ┌───────────────────────┐
          │  Summarize + Actions  │
          │  (scheduled edge fn   │
          │   or on-demand)       │
          └───────────────────────┘
```

## Design Decisions

### One Slack app, many installs

A single Slack app is created and installed into each workspace the consultant
belongs to. Each installation yields a **user token** (`xoxp-`). All
installations share the same Events API request URL (one Supabase Edge Function
endpoint). The `team_id` in each event payload identifies the source workspace.

### User tokens, not bot tokens

As a full member of each workspace, user tokens provide visibility into
everything the user can see — public channels, private channels, group DMs —
without needing to be "invited" as a bot to each channel.

### Channel filtering at our layer

The Events API delivers every event the token has access to. The Edge Function
checks the `channel` field against a configurable allow-list and drops events
for channels we don't care about.

---

## Slack App Configuration

### User Token Scopes

| Scope              | Purpose                              |
| ------------------ | ------------------------------------ |
| `channels:history` | Read messages in public channels     |
| `groups:history`   | Read messages in private channels    |
| `channels:read`    | Channel metadata                     |
| `groups:read`      | Private channel metadata             |
| `reactions:read`   | Emoji reactions                      |
| `files:read`       | File shares                          |
| `pins:read`        | Pins                                 |
| `users:read`       | Resolve user IDs → display names     |
| `team:read`        | Workspace info                       |

### Event Subscriptions

| Event                      | What it captures             |
| -------------------------- | ---------------------------- |
| `message.channels`         | Messages in public channels  |
| `message.groups`           | Messages in private channels |
| `reaction_added`           | Emoji reactions added        |
| `reaction_removed`         | Emoji reactions removed      |
| `member_joined_channel`    | Members joining channels     |
| `member_left_channel`      | Members leaving channels     |
| `pin_added`                | Pinned items                 |
| `pin_removed`              | Unpinned items               |
| `file_shared`              | File uploads                 |

---

## Database Schema

### `workspaces`

Stores one row per Slack workspace installation.

| Column             | Type        | Notes                              |
| ------------------ | ----------- | ---------------------------------- |
| `id`               | uuid (PK)   | Generated                          |
| `team_id`          | text UNIQUE | Slack workspace ID                 |
| `team_name`        | text        | Human-readable name                |
| `user_token`       | text        | Encrypted `xoxp-` token            |
| `signing_secret`   | text        | Per-app (same for all rows)        |
| `created_at`       | timestamptz | Default `now()`                    |

### `channels`

Configures which channels to track per workspace.

| Column             | Type        | Notes                              |
| ------------------ | ----------- | ---------------------------------- |
| `id`               | uuid (PK)   | Generated                          |
| `workspace_id`     | uuid (FK)   | → `workspaces.id`                 |
| `channel_id`       | text        | Slack channel ID                   |
| `channel_name`     | text        | Human-readable name                |
| `active`           | boolean     | Toggle tracking on/off             |
| `created_at`       | timestamptz | Default `now()`                    |

Unique constraint: `(workspace_id, channel_id)`.

### `events`

Raw event storage. Rows older than 3 days are purged nightly.

| Column             | Type        | Notes                              |
| ------------------ | ----------- | ---------------------------------- |
| `id`               | uuid (PK)   | Generated                          |
| `workspace_id`     | uuid (FK)   | → `workspaces.id`                 |
| `event_id`         | text UNIQUE | Slack event ID (dedup key)         |
| `channel_id`       | text        | Slack channel ID                   |
| `event_type`       | text        | e.g. `message`, `reaction_added`   |
| `user_id`          | text        | Slack user who triggered event     |
| `ts`               | text        | Slack message timestamp            |
| `thread_ts`        | text        | Parent thread ts (nullable)        |
| `payload`          | jsonb       | Full raw event object              |
| `created_at`       | timestamptz | Default `now()`                    |

Index: `(workspace_id, channel_id, created_at)`.

### `summaries`

LLM-generated digests for a channel over a time window.

| Column             | Type        | Notes                              |
| ------------------ | ----------- | ---------------------------------- |
| `id`               | uuid (PK)   | Generated                          |
| `workspace_id`     | uuid (FK)   | → `workspaces.id`                 |
| `channel_id`       | text        | Slack channel ID                   |
| `period_start`     | timestamptz | Start of summarized window         |
| `period_end`       | timestamptz | End of summarized window           |
| `summary_text`     | text        | Generated summary                  |
| `model_used`       | text        | e.g. `claude-sonnet-4-5-20250929`  |
| `created_at`       | timestamptz | Default `now()`                    |

### `action_items`

Action items extracted during summarization.

| Column             | Type        | Notes                              |
| ------------------ | ----------- | ---------------------------------- |
| `id`               | uuid (PK)   | Generated                          |
| `summary_id`       | uuid (FK)   | → `summaries.id`                  |
| `workspace_id`     | uuid (FK)   | → `workspaces.id`                 |
| `channel_id`       | text        | Slack channel ID                   |
| `description`      | text        | What needs to be done              |
| `assignee_user_id` | text        | Slack user ID (nullable)           |
| `source_ts`        | text        | Link to originating message        |
| `status`           | text        | `open` / `done` / `dismissed`     |
| `created_at`       | timestamptz | Default `now()`                    |

---

## Edge Functions

### 1. `slack-events` — Webhook Receiver

**Trigger:** HTTP POST from Slack Events API.

Responsibilities:
1. Handle Slack's `url_verification` challenge (return `challenge` value).
2. Verify request signature using the app's `signing_secret`.
3. Look up `team_id` → workspace.
4. Check if `channel` is in the active channels list.
5. Upsert into `events` table (dedup on `event_id`).
6. Return `200 OK` immediately.

**Critical:** Must respond within 3 seconds. No LLM calls here.

### 2. `summarize` — Digest Generator

**Trigger:** Cron schedule (e.g. daily) or on-demand invocation.

Responsibilities:
1. Query `events` for a time window (e.g. last 24h) per active channel.
2. Group messages by channel and thread.
3. Call Claude API with a summarization + action-item-extraction prompt.
4. Write results to `summaries` and `action_items` tables.

### 3. `slack-backfill` — Historical Import

**Trigger:** Manual / on-demand.

Responsibilities:
1. Use the user token to call `conversations.history` and `conversations.replies`.
2. Insert historical messages into the `events` table.
3. Respect Slack rate limits (~50 requests/min) with backoff.
4. Useful when onboarding a new channel or workspace.

### 4. `cleanup` — Stale Data Purge

**Trigger:** Cron schedule (nightly).

Responsibilities:
1. Delete rows from `events` where `created_at < now() - interval '3 days'`.
2. Delete rows from `summaries` where `created_at < now() - interval '3 days'`.
3. Delete rows from `action_items` where `created_at < now() - interval '3 days'`
   and `status != 'open'` (keep unresolved action items).
4. Log deleted row counts per table.

---

## Important Constraints

### 3-second response rule
Slack drops the webhook connection if the response takes longer than 3 seconds.
The event handler must write to the DB and return immediately — never call an
LLM or do heavy processing in the request path.

### Duplicate event delivery
Slack may retry delivery. The `event_id` column with a UNIQUE constraint
ensures idempotent inserts (use `ON CONFLICT DO NOTHING`).

### Token security
User tokens (`xoxp-`) grant broad access. Store them encrypted using Supabase
Vault or application-level encryption. Never expose in client-side code or logs.

### Rate limits on backfill
`conversations.history` is Tier 3 (~50 req/min). The backfill function must
pace requests and use exponential backoff on `429` responses.

### Signing secret is per app
Since all workspaces share one Slack app, there is a single signing secret used
for request verification across all workspace installations.

---

## Build Order

1. Supabase project + database schema + RLS policies
2. `slack-events` edge function (webhook receiver + signature verification)
3. Slack app creation + install into one test workspace
4. Verify events flow into the database
5. Channel config + filtering logic
6. `summarize` edge function with Claude API
7. `action_items` extraction
8. `slack-backfill` function
9. `cleanup` edge function (nightly cron)
10. Install into remaining workspaces

---

## Project Structure

```
slack-summary/
├── ARCHITECTURE.md
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   └── 001_initial_schema.sql
│   └── functions/
│       ├── slack-events/
│       │   └── index.ts
│       ├── summarize/
│       │   └── index.ts
│       ├── slack-backfill/
│       │   └── index.ts
│       └── cleanup/
│           └── index.ts
└── .env.example
```
