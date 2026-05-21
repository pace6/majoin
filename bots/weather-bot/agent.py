"""Conversational layer — routes user messages through Claude (Anthropic
Agent SDK) with a custom weather tool.

Needs ANTHROPIC_API_KEY in the environment.
"""

import contextvars
import logging

from claude_agent_sdk import (
    ClaudeAgentOptions,
    ClaudeSDKClient,
    create_sdk_mcp_server,
    tool,
)

from weather import CITY, LAT, LON, fetch_weather, geocode

log = logging.getLogger("weather-bot")

# Per-call collector — the get_weather tool records the location it resolved
# so the bot can follow up with a forecast carousel.
_weather_hits: contextvars.ContextVar[list | None] = contextvars.ContextVar(
    "weather_hits", default=None
)

_SYSTEM = (
    "You are Majoin's friendly weather bot. Keep replies short and warm. "
    "When the user asks anything about the weather, call the get_weather "
    "tool — never invent numbers. Pass the city the user names; if they "
    "name none, leave location empty (defaults to Bangkok). When you have "
    "called get_weather, keep your text reply to ONE short warm sentence — "
    "a detailed forecast card is shown to the user separately, so do not "
    "list the numbers yourself. Reply in the user's language (Thai or "
    "English). For chit-chat unrelated to weather, answer briefly and, if "
    "natural, offer to share the forecast. A message in parentheses like "
    "'(the user sent a sticker)' is a note about a non-text message — "
    "react warmly and invite them to chat."
)


@tool(
    "get_weather",
    "Get the current weather and today's forecast for a city. "
    "Pass the city name in 'location'; leave it empty for Bangkok.",
    {"location": str},
)
async def _get_weather(args):
    place = (args.get("location") or "").strip()
    if place:
        geo = await geocode(place)
        if geo is None:
            return {
                "content": [
                    {"type": "text", "text": f"Couldn't find a place called '{place}'."}
                ]
            }
        lat, lon, name = geo
    else:
        lat, lon, name = LAT, LON, CITY

    # Record the resolved location for the caller (drives the carousel).
    hits = _weather_hits.get()
    if hits is not None:
        hits.append((lat, lon, name))

    data = await fetch_weather(lat, lon)
    cur = data["current"]
    daily = data["daily"]
    text = (
        f"{name}: {round(cur['temperature_2m'])}°C, "
        f"humidity {round(cur['relative_humidity_2m'])}%, "
        f"wind {round(cur['wind_speed_10m'])} km/h, "
        f"high {round(daily['temperature_2m_max'][0])}°C / "
        f"low {round(daily['temperature_2m_min'][0])}°C"
    )
    return {"content": [{"type": "text", "text": text}]}


_server = create_sdk_mcp_server(
    name="weather", version="1.0.0", tools=[_get_weather]
)


def _extract_text(message) -> str:
    """Pull plain text out of an Agent SDK message (duck-typed so it
    survives minor SDK shape changes)."""
    parts = []
    content = getattr(message, "content", None)
    if isinstance(content, list):
        for block in content:
            text = getattr(block, "text", None)
            if isinstance(text, str):
                parts.append(text)
    return "".join(parts)


async def ask_claude(message: str) -> tuple[str, tuple | None]:
    """Single-turn reply. Returns (reply_text, location) where location is
    (lat, lon, name) if the message turned out to be weather-related, else
    None. Each call is a fresh conversation (no memory) — fine for a demo."""
    options = ClaudeAgentOptions(
        system_prompt=_SYSTEM,
        mcp_servers={"weather": _server},
        allowed_tools=["mcp__weather__get_weather"],
    )
    hits: list = []
    token = _weather_hits.set(hits)
    reply = ""
    try:
        async with ClaudeSDKClient(options=options) as client:
            await client.query(message)
            async for msg in client.receive_response():
                chunk = _extract_text(msg)
                if chunk:
                    reply += chunk
    finally:
        _weather_hits.reset(token)
    location = hits[-1] if hits else None
    return reply.strip(), location
