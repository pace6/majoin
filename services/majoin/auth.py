"""Authenticate custom API requests with a Matrix access token.

The majoin app is already logged in to Synapse, so a custom endpoint can
reuse that identity instead of inventing its own login: the caller sends its
Synapse access token as a bearer token, and this module verifies it against
the homeserver's `/account/whoami` endpoint.

Usage in an endpoint:

    from fastapi import Depends
    from auth import require_matrix_user

    @app.get("/api/something")
    async def something(user_id: str = Depends(require_matrix_user)):
        # user_id is a verified @name:server — trust it
        ...

See docs/custom-api-auth.md for the full rationale.
"""
import os
import time

import httpx
from fastapi import Header, HTTPException

# Internal Synapse address — the API runs on the same host as the homeserver.
MATRIX_HOMESERVER = os.environ.get("MATRIX_HOMESERVER", "http://127.0.0.1:8008")

# whoami is cheap but not free; cache verified tokens briefly.
_TTL_SECONDS = 300
_cache: dict[str, tuple[str, float]] = {}


async def require_matrix_user(
    authorization: str | None = Header(default=None),
) -> str:
    """FastAPI dependency. Returns the caller's verified Matrix user id
    (`@name:server`), or raises 401.

    The caller must send `Authorization: Bearer <matrix-access-token>`.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "missing bearer token")
    token = authorization[len("Bearer ") :]

    now = time.time()
    cached = _cache.get(token)
    if cached and cached[1] > now:
        return cached[0]

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{MATRIX_HOMESERVER}/_matrix/client/v3/account/whoami",
                headers={"Authorization": f"Bearer {token}"},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(503, "homeserver unreachable") from exc

    if resp.status_code != 200:
        raise HTTPException(401, "invalid matrix token")
    user_id = resp.json().get("user_id")
    if not user_id:
        raise HTTPException(401, "invalid matrix token")

    _cache[token] = (user_id, now + _TTL_SECONDS)
    return user_id
