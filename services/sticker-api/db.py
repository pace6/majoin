"""SQLite storage for sticker packs. Single-file, no ORM."""
import json
import sqlite3
from pathlib import Path
from contextlib import contextmanager

DB_PATH = Path(__file__).parent / "stickers.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS packs (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    category     TEXT NOT NULL DEFAULT 'general',
    featured     INTEGER NOT NULL DEFAULT 0,
    is_new       INTEGER NOT NULL DEFAULT 0,
    price        INTEGER NOT NULL DEFAULT 0,
    cover_mxc    TEXT NOT NULL DEFAULT '',
    sort_order   INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS stickers (
    pack_id   TEXT NOT NULL,
    sticker_id TEXT NOT NULL,
    body      TEXT NOT NULL,
    mxc       TEXT NOT NULL,
    width     INTEGER NOT NULL DEFAULT 256,
    height    INTEGER NOT NULL DEFAULT 256,
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (pack_id, sticker_id),
    FOREIGN KEY (pack_id) REFERENCES packs(id) ON DELETE CASCADE
);
"""


@contextmanager
def conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA foreign_keys = ON")
    try:
        yield c
        c.commit()
    finally:
        c.close()


def init_db():
    with conn() as c:
        c.executescript(SCHEMA)


def upsert_pack(pack_id, name, category, featured, is_new, price,
                cover_mxc, sort_order):
    with conn() as c:
        c.execute(
            """INSERT INTO packs
               (id, name, category, featured, is_new, price, cover_mxc, sort_order)
               VALUES (?,?,?,?,?,?,?,?)
               ON CONFLICT(id) DO UPDATE SET
                 name=excluded.name, category=excluded.category,
                 featured=excluded.featured, is_new=excluded.is_new,
                 price=excluded.price, cover_mxc=excluded.cover_mxc,
                 sort_order=excluded.sort_order""",
            (pack_id, name, category, int(featured), int(is_new),
             price, cover_mxc, sort_order),
        )


def replace_stickers(pack_id, stickers):
    """stickers: list of dict(sticker_id, body, mxc, width, height)."""
    with conn() as c:
        c.execute("DELETE FROM stickers WHERE pack_id = ?", (pack_id,))
        for i, s in enumerate(stickers):
            c.execute(
                """INSERT INTO stickers
                   (pack_id, sticker_id, body, mxc, width, height, sort_order)
                   VALUES (?,?,?,?,?,?,?)""",
                (pack_id, s["sticker_id"], s["body"], s["mxc"],
                 s.get("width", 256), s.get("height", 256), i),
            )


def list_packs():
    with conn() as c:
        rows = c.execute(
            "SELECT * FROM packs ORDER BY sort_order, created_at"
        ).fetchall()
        return [dict(r) for r in rows]


def get_pack(pack_id):
    with conn() as c:
        p = c.execute("SELECT * FROM packs WHERE id = ?", (pack_id,)).fetchone()
        if not p:
            return None
        stickers = c.execute(
            "SELECT * FROM stickers WHERE pack_id = ? ORDER BY sort_order",
            (pack_id,),
        ).fetchall()
        return {"pack": dict(p), "stickers": [dict(s) for s in stickers]}


def delete_pack(pack_id):
    with conn() as c:
        c.execute("DELETE FROM packs WHERE id = ?", (pack_id,))
