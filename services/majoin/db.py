"""PostgreSQL storage for sticker packs. No ORM. Async.

Shares the Synapse database, so majoin-owned tables are prefixed
`majoin_<module>_<table>` (module: sticker). The `users`/`profiles` tables
read by list_users() belong to Synapse and are queried as-is.
"""
import os
import psycopg
from psycopg.rows import dict_row
from contextlib import asynccontextmanager

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://synapse:synapse@localhost:5432/synapse"
)

@asynccontextmanager
async def conn():
    # psycopg.AsyncConnection.connect resolves an async connection context manager
    async with await psycopg.AsyncConnection.connect(DATABASE_URL, row_factory=dict_row) as connection:
        async with connection.cursor() as cur:
            yield cur


async def init_db():
    # Database schema is now managed externally via Alembic CLI migrations.
    pass


async def upsert_pack(pack_id, name, category, featured, is_new, price,
                      cover_mxc, sort_order):
    async with conn() as c:
        await c.execute(
            """INSERT INTO majoin_sticker_packs
               (id, name, category, featured, is_new, price, cover_mxc, sort_order)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
               ON CONFLICT(id) DO UPDATE SET
                 name=EXCLUDED.name, category=EXCLUDED.category,
                 featured=EXCLUDED.featured, is_new=EXCLUDED.is_new,
                 price=EXCLUDED.price, cover_mxc=EXCLUDED.cover_mxc,
                 sort_order=EXCLUDED.sort_order""",
            (pack_id, name, category, bool(featured), bool(is_new),
             price, cover_mxc, sort_order),
        )


async def replace_stickers(pack_id, stickers):
    """stickers: list of dict(sticker_id, body, mxc, width, height)."""
    async with conn() as c:
        await c.execute(
            "DELETE FROM majoin_sticker_stickers WHERE pack_id = %s", (pack_id,))
        for i, s in enumerate(stickers):
            await c.execute(
                """INSERT INTO majoin_sticker_stickers
                   (pack_id, sticker_id, body, mxc, width, height, sort_order)
                   VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                (pack_id, s["sticker_id"], s["body"], s["mxc"],
                 s.get("width", 256), s.get("height", 256), i),
            )


async def list_packs():
    async with conn() as c:
        await c.execute(
            "SELECT * FROM majoin_sticker_packs ORDER BY sort_order, created_at")
        rows = await c.fetchall()
        return [dict(r) for r in rows]


async def get_pack(pack_id):
    async with conn() as c:
        await c.execute(
            "SELECT * FROM majoin_sticker_packs WHERE id = %s", (pack_id,))
        p = await c.fetchone()
        if not p:
            return None
        await c.execute(
            "SELECT * FROM majoin_sticker_stickers WHERE pack_id = %s "
            "ORDER BY sort_order",
            (pack_id,),
        )
        stickers = await c.fetchall()
        return {"pack": dict(p), "stickers": [dict(s) for s in stickers]}


async def delete_pack(pack_id):
    async with conn() as c:
        await c.execute(
            "DELETE FROM majoin_sticker_packs WHERE id = %s", (pack_id,))


async def list_users():
    async with conn() as c:
        await c.execute(
            """SELECT u.name AS user_id, p.displayname, p.avatar_url
               FROM users u
               LEFT JOIN profiles p ON u.name = p.full_user_id
               WHERE u.deactivated = 0 
                 AND (u.user_type IS NULL OR u.user_type != 'support')
                 AND u.is_guest = 0
               ORDER BY COALESCE(p.displayname, u.name) ASC"""
        )
        rows = await c.fetchall()
        return [dict(r) for r in rows]
