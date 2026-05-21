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
    RoomMessageMedia,
    RoomMessageText,
    RoomPreset,
    StickerEvent,
)

from agent import ask_claude
from weather import BANGKOK, fetch_weather, weather_carousel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("weather-bot")

FLEX_EVENT_TYPE = "app.majoin.flex"

# Sent the first time the bot meets a user — a short guide to what it does.
_GREETING = (
    "ยินดีต้อนรับสู่ Majoin! 🌤️\n\n"
    "ฉันคือบอทพยากรณ์อากาศ สิ่งที่ฉันทำได้:\n"
    "• ถามอากาศเมืองไหนก็ได้ — พิมพ์มาเลย เช่น “อากาศโตเกียว”\n"
    "• ทุกเช้า 7 โมง ฉันส่งพยากรณ์ให้อัตโนมัติ\n"
    "• คุยเล่นกับฉันได้ ส่งสติกเกอร์มาก็ตอบ\n\n"
    "นี่คือพยากรณ์ 5 วันข้างหน้า 👇"
)


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
        # The bot replies to anything — stickers and media too, not just text.
        self.client.add_event_callback(self._on_sticker, StickerEvent)
        self.client.add_event_callback(self._on_media, RoomMessageMedia)

    async def _on_invite(self, room, event) -> None:
        """A user invited the bot — join and greet them."""
        if event.state_key != self.user_id:
            return
        await self.client.join(room.room_id)
        log.info("joined %s (invited)", room.room_id)
        await self._send_greeting(room.room_id)

    async def _on_message(self, room, event) -> None:
        """Reply to a text message."""
        await self._reply(room, event, (event.body or "").strip())

    async def _on_sticker(self, room, event) -> None:
        """Reply to a sticker — the bot always responds."""
        await self._reply(room, event, "(the user sent a sticker)")

    async def _on_media(self, room, event) -> None:
        """Reply to an image / file / audio / video."""
        await self._reply(room, event, "(the user sent an attachment)")

    async def _reply(self, room, event, prompt: str) -> None:
        """Route a user message through Claude and reply. Shared by every
        message type so the bot always responds."""
        if event.sender == self.user_id:
            return
        # Skip history replayed on (re)sync.
        if event.server_timestamp < self._start_ms:
            return
        if not prompt:
            return
        # Keep the "typing…" indicator alive for the whole Claude call —
        # a single typing notice expires, so re-assert it on a timer.
        typing = asyncio.create_task(self._keep_typing(room.room_id))
        location = None
        try:
            reply, location = await ask_claude(prompt)
        except Exception as exc:  # noqa: BLE001 - demo bot, degrade gracefully
            log.warning("claude reply failed: %s", exc)
            reply = "ขออภัย ตอนนี้ตอบไม่ได้ ลองใหม่อีกครั้งนะ 🌧️"
        finally:
            typing.cancel()
            await self.client.room_typing(room.room_id, False)
        await self._send_text(room.room_id, reply or "🤔")
        # Weather-related — always follow up with a forecast carousel.
        if location is not None:
            await self._send_forecast(room.room_id, location)
        log.info("replied in %s", room.room_id)

    async def _send_forecast(self, room_id: str, location: tuple) -> None:
        """Send a 5-day forecast carousel for a resolved (lat, lon, name)."""
        lat, lon, name = location
        try:
            data = await fetch_weather(lat, lon, days=5)
            carousel, alt = weather_carousel(data, place=name)
            await self._send_flex(room_id, carousel, alt)
        except Exception as exc:  # noqa: BLE001
            log.warning("forecast carousel for %s failed: %s", name, exc)

    async def _keep_typing(self, room_id: str) -> None:
        """Re-send the typing indicator every 15s until cancelled."""
        try:
            while True:
                await self.client.room_typing(room_id, True, timeout=20000)
                await asyncio.sleep(15)
        except asyncio.CancelledError:
            pass

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

    async def _send_flex(self, room_id: str, payload: dict, alt: str) -> None:
        """Send a Flex payload — a bubble or a carousel."""
        await self.client.room_send(
            room_id,
            message_type=FLEX_EVENT_TYPE,
            content={"msgtype": "m.text", "body": alt, "app.majoin.flex": payload},
        )

    async def _send_text(self, room_id: str, body: str) -> None:
        await self.client.room_send(
            room_id,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": body},
        )

    # ---- Flows ----

    async def _send_greeting(self, room_id: str) -> None:
        """Welcome + a short guide to what the bot does, then a carousel."""
        try:
            data = await fetch_weather(days=5)
            carousel, alt = weather_carousel(data)
            await self._send_text(room_id, _GREETING)
            await self._send_flex(room_id, carousel, alt)
        except Exception as exc:  # noqa: BLE001 - demo bot, log and move on
            log.warning("greeting in %s failed: %s", room_id, exc)

    async def greet(self, user_id: str) -> None:
        """New user (from the register hook): open a DM, say hello."""
        if user_id == self.user_id:
            return
        room_id = await self._direct_room(user_id)
        if room_id is None:
            return
        await self._send_greeting(room_id)
        log.info("greeted %s", user_id)

    async def morning_broadcast(self) -> None:
        try:
            data = await fetch_weather(days=5)
        except Exception as exc:  # noqa: BLE001
            log.warning("morning fetch failed: %s", exc)
            return
        carousel, alt = weather_carousel(data)
        for room_id in list(self.client.rooms):
            try:
                await self._send_flex(room_id, carousel, alt)
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
