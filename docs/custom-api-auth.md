# Protecting custom APIs with Matrix credentials

`services/majoin` is a plain FastAPI app. It started as the sticker store and
now also serves the user directory (`/api/users`); more custom endpoints can
be added the same way. This note explains how to put those endpoints behind
the **same identity the app already has** — its Matrix login — instead of
issuing separate API keys.

## The idea

The majoin client is already logged in to Synapse and holds a Matrix
**access token**. A custom endpoint does not need its own auth system: the
client sends that token, and the API asks Synapse "who is this token?".

```
client ──Authorization: Bearer <matrix access token>──► majoin API
                                                            │
                                          GET /_matrix/client/v3/account/whoami
                                                            ▼
                                                         Synapse
                                                            │
                                              200 {"user_id": "@ball:server"}
                                                            ▼
                                        API trusts the request as that user
```

Synapse's [`/account/whoami`](https://spec.matrix.org/latest/client-server-api/#get_matrixclientv3accountwhoami)
returns `200` with the `user_id` for a valid token, `401` otherwise. That one
call is the whole verification.

## Three protection levels

| Level | Use for | Mechanism |
|-------|---------|-----------|
| Public | catalogs, health | no auth (`/api/stickers/catalog`) |
| Matrix user | anything per-user or non-public | `require_matrix_user` — verify the caller's Matrix token |
| Admin | catalog mutations, ops | shared secret header (`X-Admin-Key`) |

## Using it — `services/majoin/auth.py`

`auth.py` provides a FastAPI dependency. Add it to any endpoint:

```python
from fastapi import Depends
from auth import require_matrix_user

@app.get("/api/users")
async def list_users(user_id: str = Depends(require_matrix_user)):
    # user_id is a verified @name:server — only logged-in app users reach here
    ...
```

A request with no / a bad token gets `401` automatically. The dependency
caches verified tokens for 5 minutes so `whoami` is not hit on every call.

### Client side

The app sends its existing Matrix token — no new credential:

```dart
final token = MatrixClientService.instance.client.accessToken;
await http.get(
  Uri.parse('$api/api/users'),
  headers: {'Authorization': 'Bearer $token'},
);
```

## Notes

- **Config:** `auth.py` reads `MATRIX_HOMESERVER` (default
  `http://127.0.0.1:8008` — the API runs on the homeserver host, so it talks
  to Synapse over loopback, not the public URL).
- **Per-user data:** the returned `user_id` is trustworthy — scope queries to
  it (e.g. "this user's settings"), never take a user id from the request body.
- **Admin endpoints** stay on the `X-Admin-Key` shared secret — they act on
  behalf of no Matrix user, so token verification does not apply.
- **`/api/users` is currently public.** Protecting it is a one-line change
  (add the dependency) plus sending the token from the client.
