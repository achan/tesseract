# Tesseract — Architecture

Multi-workspace Slack event ingestion, summarization, and action-item extraction.
Built on Rails 8 (API-only + SQLite) running locally behind a cloudflared tunnel,
using the Slack Events API with user tokens.

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
          │     cloudflared       │
          │  (tunnel to local)    │
          └───────────┬───────────┘
                      ▼
          ┌───────────────────────┐
          │  Rails API (local)    │
          │  POST /api/slack/     │
          │       events          │
          └───────────┬───────────┘
                      ▼
          ┌───────────────────────┐
          │       SQLite          │
          │  - raw events         │
          │  - channels config    │
          │  - workspace tokens   │
          └───────────┬───────────┘
                      ▼
          ┌───────────────────────┐
          │  SummarizeJob         │
          │  (solid_queue         │
          │   recurring/on-demand)│
          └───────────────────────┘
```

## Key Design Decisions

- **One Slack app, many installs** — single app installed per workspace, each yielding a user token (`xoxp-`); all share one Events API request URL
- **User tokens, not bot tokens** — gives visibility into public channels, private channels, and group DMs without bot invitations
- **Channel filtering at our layer** — Events API delivers everything the token can see; controller checks against a configurable allow-list and drops the rest
- **Signing secret is per app** — single secret shared across all workspace installations

## Database Schema

Five tables: `workspaces`, `channels`, `events`, `summaries`, `action_items`.

- **workspaces** — one row per Slack install; stores `team_name` and encrypted `user_token`
- **channels** — which channels to track per workspace; unique on `(workspace_id, channel_id)`; has `active` toggle
- **events** — raw event storage; deduped on `event_id` (UNIQUE); indexed on `(workspace_id, channel_id, created_at)`; purged after 3 days
- **summaries** — LLM-generated digests per channel over a time window; stores `period_start`/`period_end`, `summary_text`, `model_used`
- **action_items** — extracted during summarization; linked to a summary; has `status` (`open`/`done`/`dismissed`); open items survive cleanup

## API Endpoints & Jobs

- **`POST /api/slack/events`** — webhook receiver; handles `url_verification`, verifies signing secret, upserts event, returns 200 immediately
- **`SummarizeJob`** — runs on schedule (daily) or on-demand via `POST /api/summaries/generate`; groups events by channel/thread, calls Claude, writes summaries + action items
- **`CleanupJob`** — nightly; deletes events/summaries older than 3 days; keeps open action items

## Important Constraints

- **3-second response rule** — Slack drops the connection after 3s; never do heavy processing in the request path
- **Duplicate delivery** — Slack retries; `event_id` UNIQUE constraint ensures idempotent inserts
- **Token security** — `xoxp-` tokens grant broad access; stored with Active Record Encryption; never expose in client code or logs
- **cloudflared must be running** — Rails runs locally; tunnel must be up for Slack to deliver events

## Slack App Configuration

**User token scopes:** `channels:history`, `groups:history`, `channels:read`, `groups:read`, `reactions:read`, `files:read`, `pins:read`, `users:read`, `team:read`

**Event subscriptions:** `message.channels`, `message.groups`, `reaction_added`, `reaction_removed`, `member_joined_channel`, `member_left_channel`, `pin_added`, `pin_removed`, `file_shared`

## Build Order

1. `rails new` (API-only + SQLite)
2. Migrations, models, associations
3. `SlackEventsController` + signature verification
4. Slack app creation + test install
5. Channel config + filtering
6. `SummarizeJob` with Claude API
7. Action items extraction
8. `CleanupJob` (nightly via solid_queue)
9. cloudflared tunnel setup
10. Install into remaining workspaces
