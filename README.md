# Tesseract

Multi-workspace Slack event ingestion, summarization, and action-item
extraction. Built on Rails 8 with SQLite, running locally behind a
cloudflared tunnel.

A single Slack app is installed into each workspace. User tokens
(`xoxp-`) give visibility into public channels, private channels, and
group DMs without needing bot invitations. Incoming events are stored
in SQLite, then a background job summarizes activity and extracts
action items using Claude.

See [ARCHITECTURE.md](ARCHITECTURE.md) for full design details,
database schema, and API documentation.

## Slack App Setup

Create a Slack app at [api.slack.com/apps](https://api.slack.com/apps) and
configure the following:

### User Token Scopes (OAuth & Permissions)

- `channels:history` — view messages in public channels
- `channels:read` — list public channels
- `groups:history` — view messages in private channels
- `groups:read` — list private channels
- `im:history` — view messages in DMs
- `im:read` — list DMs
- `mpim:history` — view messages in group DMs
- `mpim:read` — list group DMs
- `reactions:read` — view emoji reactions
- `search:read` — search workspace content
- `users:read` — resolve user names

### Event Subscriptions

Enable events and set the Request URL to your cloudflared tunnel
(e.g., `https://your-tunnel.example.com/api/slack/events`).

Subscribe to these events **on behalf of users** (not bot events):

- `message.channels`
- `message.groups`
- `message.im`
- `message.mpim`
- `reaction_added`

After configuring scopes and events, install the app to your workspace
and copy the **User OAuth Token** (`xoxp-...`) and **Signing Secret**
into your `.env.local`.

## Prerequisites

- Ruby 3.4.2
- SQLite
- tmux (for the worktree dev environment)
- [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) (for receiving Slack webhooks)

## Getting Started

Clone the repo and install dependencies:

```sh
git clone <repo-url>
cd tesseract
bin/setup --skip-server
```

Copy the example env file and fill in your Slack signing secret and
encryption keys:

```sh
cp .env.example .env
bin/rails db:encryption:init  # paste output into .env
```

Start the development server:

```sh
bin/dev
```

This runs the Rails server (port 6000) and Solid Queue job worker via
`Procfile.dev`.

## Worktree Development

This repo uses git worktrees so multiple feature branches can run
simultaneously, each with its own server on a separate port.

### Create a worktree

From the main repo directory:

```sh
bin/create-worktree.sh my-feature
```

This creates a worktree at `~/repos/tesseract-worktrees/my-feature`
on a new `feature/my-feature` branch, symlinks your `.env`, and runs
`bundle install`.

### Start a worktree session

From inside the worktree directory:

```sh
bin/start-worktree.sh
```

This launches a tmux session with:
- **Window 1 (main):** vim (top), shell (bottom-left), Claude Code
  (bottom-right)
- **Window 2 (server):** Rails server + job worker on the first
  available port starting from 6000

### Remove a worktree

From the main repo directory:

```sh
bin/remove-worktree.sh my-feature
```

## Production

The app runs on a macOS server behind a cloudflared tunnel via
`bin/prod`. A launchd service manages the process and a GitHub
webhook triggers auto-deploys on push.

### Server setup

Create a dedicated `tesseract` standard (non-Admin) user on the
Mac, then clone the repo and populate `.env`:

```sh
git clone <repo-url> /Users/tesseract/tesseract
cd /Users/tesseract/tesseract
cp .env.example .env
# fill in .env values
bin/rails db:encryption:init  # paste output into .env
```

Install and start the launchd service:

```sh
sudo cp deploy/com.tesseract.web.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.tesseract.web.plist
```

### Auto-deploy via GitHub webhook

1. Generate a webhook secret:

   ```sh
   ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
   ```

2. Add it to your `.env` as `GITHUB_WEBHOOK_SECRET`.

3. In your GitHub repo, go to **Settings → Webhooks → Add webhook**:
   - **Payload URL:** `https://<your-tunnel>/api/deploy`
   - **Content type:** `application/json`
   - **Secret:** the value from step 1
   - **Events:** select **Just the push event**

Pushes to `main` will now trigger `bin/deploy`, which pulls the
latest code, installs dependencies and precompiles assets only when
their source files changed, runs `db:prepare`, and restarts the
service.

### Useful commands

```sh
sudo launchctl print system/com.tesseract.web  # service status
tail -f log/production.log                      # follow app logs
tail -f log/deploy.log                          # deploy history
bin/deploy --force                              # manual deploy
```

### Configuration

`bin/deploy` reads these environment variables (all optional):

| Variable | Default | Description |
|---|---|---|
| `DEPLOY_BRANCH` | `main` | Branch to deploy from |
| `DEPLOY_REMOTE` | `origin` | Git remote to fetch |
| `DEPLOY_SERVICE` | `com.tesseract.web` | launchd service label to restart |
