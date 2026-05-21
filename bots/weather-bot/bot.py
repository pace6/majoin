"""Majoin weather bot.

A plain Matrix user-account bot that:
  * exposes an HTTP webhook (/hooks/new-user) the Synapse register hook calls;
  * on a new registration, opens a direct chat with the user, sends a greeting
    and the current weather as a Majoin Flex message;
  * every morning broadcasts the forecast to every chat it is in.

Demo bot — no end-to-end encryption: it creates its own (unencrypted) DM
rooms, so it never needs olm.
"""

import asyncio
import logging
import os
import sys
from datetime import datetime, timedelta

from aiohttp import web
from nio import (
    AsyncClient,
    InviteMemberEvent,
    LoginError,
    RoomCreateError,
    RoomMessageText,
    RoomPreset,
)

from agent import ask_claude
from weather import BANGKOK, fetch_weather, weather_flex

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("weather-bot")

FLEX_EVENT_TYPE = "app.majoin.flex"


def _env(name: str, default: str | None = None) -> str:
    val = os.environ.get(name, default)
    if val is None:
        log.error("missing required env var %s", name)
        sys.exit(1)
    return val


class WeatherBot:
    def __init__(self) -> None:
        self.homeserver = _env("MATRIX_HOMESERVER")
        self.user_id = _env("BOT_USER_ID")
        self.password = _env("BOT_PASSWORD")
        self.hook_token = os.environ.get("HOOK_TOKEN", "")
        self.hook_port = int(os.environ.get("HOOK_PORT", "8470"))
        self.morning_hour = int(os.environ.get("MORNING_HOUR", "7"))
        self.client = AsyncClient(self.homeserver, self.user_id)
        # Ignore messages older than startup — avoids replaying history.
        self._start_ms = 0

    # ---- Matrix helpers ----

    async def login(self) -> None:
        resp = await self.client.login(self.password, device_name="weather-bot")
        if isinstance(resp, LoginError):
            log.error("login failed: %s", resp.message)
            sys.exit(1)
        log.info("logged in as %s", self.user_id)
        # Initial sync so self.client.rooms is populated before we broadcast.
        await self.client.sync(timeout=10000, full_state=True)
        self._start_ms = int(datetime.now(BANGKOK).timestamp() * 1000)
        self.client.add_event_callback(self._on_invite, InviteMemberEvent)
        self.client.add_event_callback(self._on_message, RoomMessageText)

    async def _on_invite(self, room, event) -> None:
        """Auto-join if someone invites the bot directly."""
        if event.state_key == self.user_id:
            await self.client.join(room.room_id)
            log.info("joined %s (invited)", room.room_id)

    async def _on_message(self, room, event) -> None:
        """Reply to a user message — routed through Claude (Agent SDK)."""
        if event.sender == self.user_id:
            return
        # Skip history replayed on (re)sync.
        if event.server_timestamp < self._start_ms:
            return
        text = (event.body or "").strip()
        if not text:
            return
        try:
            await self.client.room_typing(room.room_id, True, timeout=30000)
            reply = await ask_claude(text)
        except Exception as exc:  # noqa: BLE001 - demo bot, degrade gracefully
            log.warning("claude reply failed: %s", exc)
            reply = "ขออภัย ตอนนี้ตอบไม่ได้ ลองใหม่อีกครั้งนะ 🌧️"
        finally:
            await self.client.room_typing(room.room_id, False)
        await self._send_text(room.room_id, reply or "🤔")
        log.info("replied in %s", room.room_id)

    async def _direct_room(self, user_id: str) -> str | None:
        """Reuse an existing 1:1 room with the user, or create one."""
        for room in self.client.rooms.values():
            if len(room.users) <= 2 and user_id in room.users:
                return room.room_id
        resp = await self.client.room_create(
            is_direct=True,
            invite=[user_id],
            preset=RoomPreset.trusted_private_chat,
        )
        if isinstance(resp, RoomCreateError):
            log.error("room_create for %s failed: %s", user_id, resp.message)
            return None
        log.info("created DM %s with %s", resp.room_id, user_id)
        return resp.room_id

    async def _send_flex(self, room_id: str, bubble: dict, alt: str) -> None:
        await self.client.room_send(
            room_id,
            message_type=FLEX_EVENT_TYPE,
            content={"msgtype": "m.text", "body": alt, "app.majoin.flex": bubble},
        )

    async def _send_text(self, room_id: str, body: str) -> None:
        await self.client.room_send(
            room_id,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": body},
        )

    # ---- Flows ----

    async def greet(self, user_id: str) -> None:
        """New user: open a DM, say hello, send today's weather."""
        if user_id == self.user_id:
            return
        room_id = await self._direct_room(user_id)
        if room_id is None:
            return
        try:
            data = await fetch_weather()
            bubble, alt = weather_flex(data, greeting=True)
            await self._send_text(room_id, "ยินดีต้อนรับสู่ Majoin! 🌤️")
            await self._send_flex(room_id, bubble, alt)
            log.info("greeted %s", user_id)
        except Exception as exc:  # noqa: BLE001 - demo bot, log and move on
            log.warning("greet %s failed: %s", user_id, exc)

    async def morning_broadcast(self) -> None:
        try:
            data = await fetch_weather()
        except Exception as exc:  # noqa: BLE001
            log.warning("morning fetch failed: %s", exc)
            return
        bubble, alt = weather_flex(data)
        for room_id in list(self.client.rooms):
            try:
                await self._send_flex(room_id, bubble, alt)
            except Exception as exc:  # noqa: BLE001
                log.warning("broadcast to %s failed: %s", room_id, exc)
        log.info("morning broadcast sent to %d rooms", len(self.client.rooms))

    # ---- Loops ----

    async def scheduler(self) -> None:
        """Sleep until the next MORNING_HOUR (Asia/Bangkok), then broadcast."""
        while True:
            now = datetime.now(BANGKOK)
            nxt = now.replace(
                hour=self.morning_hour, minute=0, second=0, microsecond=0
            )
            if nxt <= now:
                nxt += timedelta(days=1)
            wait = (nxt - now).total_seconds()
            log.info("next broadcast at %s (%.0f min)", nxt, wait / 60)
            await asyncio.sleep(wait)
            await self.morning_broadcast()

    async def _handle_new_user(self, request: web.Request) -> web.Response:
        if self.hook_token:
            if request.headers.get("Authorization") != f"Bearer {self.hook_token}":
                return web.json_response({"error": "unauthorized"}, status=401)
        try:
            data = await request.json()
        except Exception:  # noqa: BLE001
            return web.json_response({"error": "bad json"}, status=400)
        user_id = data.get("user_id")
        if not user_id:
            return web.json_response({"error": "user_id required"}, status=400)
        # Greet in the background so the webhook returns immediately.
        asyncio.create_task(self.greet(user_id))
        return web.json_response({"ok": True})

    async def webhook(self) -> None:
        app = web.Application()
        app.router.add_post("/hooks/new-user", self._handle_new_user)
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, "0.0.0.0", self.hook_port)
        await site.start()
        log.info("webhook listening on :%d/hooks/new-user", self.hook_port)

    async def run(self) -> None:
        await self.login()
        await self.webhook()
        await asyncio.gather(
            self.client.sync_forever(timeout=30000),
            self.scheduler(),
        )


def main() -> None:
    bot = WeatherBot()
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        log.info("shutting down")


if __name__ == "__main__":
    main()
