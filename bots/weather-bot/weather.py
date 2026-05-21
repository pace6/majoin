"""Weather fetch (open-meteo, no API key) + Majoin Flex bubble builder."""

from datetime import datetime, timedelta, timezone

import aiohttp

BANGKOK = timezone(timedelta(hours=7))

CITY = "Bangkok"
LAT, LON = 13.7563, 100.5018

# WMO weather codes -> (emoji, short description).
_WMO = {
    0: ("☀️", "Clear sky"),
    1: ("\U0001f324️", "Mainly clear"),
    2: ("⛅", "Partly cloudy"),
    3: ("☁️", "Overcast"),
    45: ("\U0001f32b️", "Fog"),
    48: ("\U0001f32b️", "Rime fog"),
    51: ("\U0001f327️", "Light drizzle"),
    53: ("\U0001f327️", "Drizzle"),
    55: ("\U0001f327️", "Dense drizzle"),
    61: ("\U0001f326️", "Light rain"),
    63: ("\U0001f327️", "Rain"),
    65: ("\U0001f327️", "Heavy rain"),
    71: ("\U0001f328️", "Light snow"),
    73: ("\U0001f328️", "Snow"),
    75: ("❄️", "Heavy snow"),
    80: ("\U0001f326️", "Light showers"),
    81: ("\U0001f327️", "Showers"),
    82: ("⛈️", "Violent showers"),
    95: ("⛈️", "Thunderstorm"),
    96: ("⛈️", "Thunderstorm + hail"),
    99: ("⛈️", "Severe thunderstorm"),
}


async def fetch_weather() -> dict:
    """Return the raw open-meteo forecast payload for Bangkok."""
    params = {
        "latitude": LAT,
        "longitude": LON,
        "current": "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m",
        "daily": "weather_code,temperature_2m_max,temperature_2m_min",
        "timezone": "Asia/Bangkok",
        "forecast_days": 1,
    }
    async with aiohttp.ClientSession() as session:
        async with session.get(
            "https://api.open-meteo.com/v1/forecast",
            params=params,
            timeout=aiohttp.ClientTimeout(total=10),
        ) as resp:
            resp.raise_for_status()
            return await resp.json()


def _text(text, **kw):
    return {"type": "text", "text": text, "wrap": True, **kw}


def _row(label, value):
    return {
        "type": "box",
        "layout": "horizontal",
        "justifyContent": "space-between",
        "contents": [
            _text(label, size="sm", color="#888888"),
            _text(value, size="sm", color="#1A1A1A"),
        ],
    }


def weather_flex(data: dict, greeting: bool = False) -> tuple[dict, str]:
    """Build a Majoin Flex bubble (and a plain-text alt) from forecast data."""
    cur = data["current"]
    daily = data["daily"]
    code = int(cur["weather_code"])
    emoji, desc = _WMO.get(code, ("\U0001f321️", "Unknown"))
    temp = round(cur["temperature_2m"])
    humidity = round(cur["relative_humidity_2m"])
    wind = round(cur["wind_speed_10m"])
    hi = round(daily["temperature_2m_max"][0])
    lo = round(daily["temperature_2m_min"][0])
    date = datetime.now(BANGKOK).strftime("%a %d %b")

    contents = []
    if greeting:
        contents += [
            _text(
                "สวัสดี! ฉันจะคอยรายงานอากาศให้ทุกเช้า \U0001f324️",
                size="sm",
                color="#06C755",
                weight="bold",
            ),
            {"type": "separator"},
        ]
    contents += [
        _text(f"{emoji}  {CITY}", weight="bold", size="lg", color="#1A1A1A"),
        _text(date, size="sm", color="#888888"),
        {"type": "separator"},
        {
            "type": "box",
            "layout": "horizontal",
            "justifyContent": "space-between",
            "contents": [
                _text(f"{temp}°", weight="bold", size="xl", color="#2563EB"),
                _text(desc, size="sm", color="#555555"),
            ],
        },
        _row("High / Low", f"{hi}° / {lo}°"),
        _row("Humidity", f"{humidity}%"),
        _row("Wind", f"{wind} km/h"),
    ]

    alt = f"{CITY} {temp}°C {desc} (H:{hi}° L:{lo}°)"
    bubble = {
        "type": "bubble",
        "altText": alt,
        "body": {"type": "box", "layout": "vertical", "spacing": "md", "contents": contents},
    }
    return bubble, alt
