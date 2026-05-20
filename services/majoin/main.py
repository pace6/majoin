"""majoin sticker store API.

Read-only public endpoints for the app + an admin-keyed register endpoint.
Images live in Synapse media (mxc://); the app resolves them with its own
access token, so this service never proxies image bytes.

Run:  uv run uvicorn main:app --host 127.0.0.1 --port 8410
"""
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import db

ADMIN_KEY = os.environ.get("STICKER_ADMIN_KEY", "change-me-admin-key")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Schema is managed externally via Alembic CLI migrations.
    yield


app = FastAPI(
    title="Majoin API backend",
    description="Backend API for Majoin sticker store and user directory",
    docs_url=None,
    redoc_url=None,
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)


def _pack_summary(p):
    return {
        "id": p["id"],
        "name": p["name"],
        "category": p["category"],
        "featured": bool(p["featured"]),
        "isNew": bool(p["is_new"]),
        "price": p["price"],
        "coverMxc": p["cover_mxc"],
    }


@app.get("/api/stickers/catalog")
async def catalog():
    packs = [_pack_summary(p) for p in await db.list_packs()]
    return {
        "packs": packs,
        "featured": [p for p in packs if p["featured"]],
        "categories": sorted({p["category"] for p in packs}),
    }


@app.get("/api/stickers/pack/{pack_id}")
async def pack(pack_id: str):
    data = await db.get_pack(pack_id)
    if not data:
        raise HTTPException(404, "pack not found")
    p = data["pack"]
    return {
        **_pack_summary(p),
        "stickers": [
            {
                "id": s["sticker_id"],
                "body": s["body"],
                "mxc": s["mxc"],
                "w": s["width"],
                "h": s["height"],
            }
            for s in data["stickers"]
        ],
    }


class StickerIn(BaseModel):
    sticker_id: str
    body: str
    mxc: str
    width: int = 256
    height: int = 256


class PackIn(BaseModel):
    id: str
    name: str
    category: str = "general"
    featured: bool = False
    is_new: bool = False
    price: int = 0
    cover_mxc: str = ""
    sort_order: int = 0
    stickers: list[StickerIn]


def _require_admin(key: str | None):
    if key != ADMIN_KEY:
        raise HTTPException(401, "bad admin key")


@app.post("/api/stickers/admin/pack")
async def register_pack(body: PackIn, x_admin_key: str | None = Header(default=None)):
    _require_admin(x_admin_key)
    await db.upsert_pack(
        body.id, body.name, body.category, body.featured, body.is_new,
        body.price, body.cover_mxc, body.sort_order,
    )
    await db.replace_stickers(
        body.id,
        [s.model_dump() for s in body.stickers],
    )
    return {"ok": True, "pack": body.id, "count": len(body.stickers)}


@app.delete("/api/stickers/admin/pack/{pack_id}")
async def remove_pack(pack_id: str, x_admin_key: str | None = Header(default=None)):
    _require_admin(x_admin_key)
    await db.delete_pack(pack_id)
    return {"ok": True}


@app.get("/api/users")
async def list_users():
    users = await db.list_users()
    formatted = []
    for u in users:
        user_id = u["user_id"]
        displayname = u["displayname"]
        if not displayname:
            # Fallback to the localpart of the Matrix ID (e.g. @ball:localhost -> ball)
            localpart = user_id.split(":")[0][1:]
            displayname = localpart
        formatted.append({
            "userId": user_id,
            "displayname": displayname,
            "avatarUrl": u["avatar_url"] or ""
        })
    return {"users": formatted}


@app.get("/api/stickers/health")
async def health():
    return {"ok": True}
