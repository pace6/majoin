# bots

Simple Matrix bots — each logs in as an **ordinary user account** and reacts.

Not to be confused with `appservices/`: an appservice is registered with
Synapse via a registration file, owns a user-id namespace, and can act on
behalf of many users (needed for bridges and puppeting). A bot here is just
one user account.

## Bots

| Bot | What it does |
|-----|--------------|
| [`weather-bot/`](weather-bot/) | On registration, requests friendship and reports the weather — once on greeting, then every morning — as a Majoin Flex message. |

## Adding a bot

1. Register the bot's account: `infra/scripts/register-user.sh <name> <pass>`.
2. Put the bot in its own directory under `bots/`.
3. Read credentials/config from the environment (`.env`), never commit them.
4. Ship a `README.md`, a dependency manifest, and a `.env.example`.
5. For production, add a unit file under `infra/systemd/`.
