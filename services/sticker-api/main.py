"""majoin sticker store API.

Read-only public endpoints for the app + an admin-keyed register endpoint.
Images live in Synapse media (mxc://); the app resolves them with its own
access token, so this service never proxies image bytes.

Run:  uv run uvicorn main:app --host 127.0.0.1 --port 8410
"""
import os
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import db

ADMIN_KEY = os.environ.get("STICKER_ADMIN_KEY", "change-me-admin-key")

app = FastAPI(title="majoin sticker store", docs_url=None, redoc_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)
db.init_db()


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
def catalog():
    packs = [_pack_summary(p) for p in db.list_packs()]
    return {
        "packs": packs,
        "featured": [p for p in packs if p["featured"]],
        "categories": sorted({p["category"] for p in packs}),
    }


@app.get("/api/stickers/pack/{pack_id}")
def pack(pack_id: str):
    data = db.get_pack(pack_id)
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
def register_pack(body: PackIn, x_admin_key: str | None = Header(default=None)):
    _require_admin(x_admin_key)
    db.upsert_pack(
        body.id, body.name, body.category, body.featured, body.is_new,
        body.price, body.cover_mxc, body.sort_order,
    )
    db.replace_stickers(
        body.id,
        [s.model_dump() for s in body.stickers],
    )
    return {"ok": True, "pack": body.id, "count": len(body.stickers)}


@app.delete("/api/stickers/admin/pack/{pack_id}")
def remove_pack(pack_id: str, x_admin_key: str | None = Header(default=None)):
    _require_admin(x_admin_key)
    db.delete_pack(pack_id)
    return {"ok": True}


@app.get("/api/stickers/health")
def health():
    return {"ok": True}
