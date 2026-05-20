"""Upload a local sticker pack to Synapse media + register it in the API.

A pack folder must contain `pack.json` (MSC2545-ish, the same format used by
the Flutter app's bundled packs) and the referenced PNG files.

Usage:
  export MATRIX_HS=https://chat.tokens2.io
  export MATRIX_TOKEN=<access token of a service/admin user>
  export STICKER_API=http://127.0.0.1:8410
  export STICKER_ADMIN_KEY=<same key the API runs with>

  python3 upload_pack.py <pack_id> <path/to/pack_folder> \\
      --name "Cute Animals" --category animals --featured --new

The script uploads every PNG once, collecting the resulting mxc:// URIs, then
POSTs the pack manifest to the sticker API.
"""
import argparse
import json
import os
import sys
from pathlib import Path

import httpx

HS = os.environ.get("MATRIX_HS", "").rstrip("/")
TOKEN = os.environ.get("MATRIX_TOKEN", "")
API = os.environ.get("STICKER_API", "http://127.0.0.1:8410").rstrip("/")
ADMIN_KEY = os.environ.get("STICKER_ADMIN_KEY", "")


def upload_image(path: Path) -> str:
    """Upload one file to Synapse media repo, return its mxc:// URI."""
    with open(path, "rb") as f:
        data = f.read()
    r = httpx.post(
        f"{HS}/_matrix/media/v3/upload",
        params={"filename": path.name},
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "image/png",
        },
        content=data,
        timeout=60,
    )
    r.raise_for_status()
    return r.json()["content_uri"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack_id")
    ap.add_argument("folder")
    ap.add_argument("--name", required=True)
    ap.add_argument("--category", default="general")
    ap.add_argument("--featured", action="store_true")
    ap.add_argument("--new", action="store_true", dest="is_new")
    ap.add_argument("--sort", type=int, default=0)
    args = ap.parse_args()

    if not HS or not TOKEN:
        sys.exit("Set MATRIX_HS and MATRIX_TOKEN env vars.")
    if not ADMIN_KEY:
        sys.exit("Set STICKER_ADMIN_KEY env var.")

    folder = Path(args.folder)
    manifest = json.loads((folder / "pack.json").read_text())
    images = manifest.get("images", {})

    out_stickers = []
    cover_mxc = ""
    for sid, meta in images.items():
        url = meta["url"]  # "asset:foo.png"
        fname = url.split("asset:", 1)[-1]
        path = folder / fname
        if not path.exists():
            sys.exit(f"missing image: {path}")
        mxc = upload_image(path)
        print(f"  uploaded {fname} -> {mxc}")
        if not cover_mxc:
            cover_mxc = mxc
        out_stickers.append({
            "sticker_id": sid,
            "body": meta.get("body", sid),
            "mxc": mxc,
            "width": meta.get("w", 256),
            "height": meta.get("h", 256),
        })

    payload = {
        "id": args.pack_id,
        "name": args.name,
        "category": args.category,
        "featured": args.featured,
        "is_new": args.is_new,
        "price": 0,
        "cover_mxc": cover_mxc,
        "sort_order": args.sort,
        "stickers": out_stickers,
    }
    r = httpx.post(
        f"{API}/api/stickers/admin/pack",
        json=payload,
        headers={"X-Admin-Key": ADMIN_KEY},
        timeout=30,
    )
    r.raise_for_status()
    print(f"registered: {r.json()}")


if __name__ == "__main__":
    main()
