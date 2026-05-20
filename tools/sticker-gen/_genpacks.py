"""Generate 2 extra sticker packs: animals + food (256x256 PNG)."""
from PIL import Image, ImageDraw
from pathlib import Path

# Repo layout: tools/sticker-gen/ -> client/assets/stickers/
ROOT = Path(__file__).parents[2] / "client/assets/stickers"
SIZE = 256


def canvas():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ---- Animals ----
def cat():
    img, d = canvas()
    d.ellipse([56, 80, 200, 220], fill=(255, 183, 77, 255))
    d.polygon([(70, 90), (60, 30), (110, 70)], fill=(255, 183, 77, 255))
    d.polygon([(186, 90), (196, 30), (146, 70)], fill=(255, 183, 77, 255))
    d.ellipse([90, 130, 115, 160], fill=(40, 40, 40, 255))
    d.ellipse([141, 130, 166, 160], fill=(40, 40, 40, 255))
    d.polygon([(118, 165), (138, 165), (128, 180)], fill=(230, 100, 100, 255))
    return img


def dog():
    img, d = canvas()
    d.ellipse([56, 80, 200, 220], fill=(141, 110, 99, 255))
    d.ellipse([40, 70, 90, 170], fill=(93, 64, 55, 255))
    d.ellipse([166, 70, 216, 170], fill=(93, 64, 55, 255))
    d.ellipse([95, 130, 118, 155], fill=(40, 40, 40, 255))
    d.ellipse([138, 130, 161, 155], fill=(40, 40, 40, 255))
    d.ellipse([112, 158, 144, 185], fill=(40, 40, 40, 255))
    return img


def rabbit():
    img, d = canvas()
    d.ellipse([70, 100, 186, 220], fill=(245, 245, 245, 255))
    d.ellipse([78, 10, 116, 120], fill=(245, 245, 245, 255))
    d.ellipse([140, 10, 178, 120], fill=(245, 245, 245, 255))
    d.ellipse([88, 20, 106, 110], fill=(255, 183, 197, 255))
    d.ellipse([150, 20, 168, 110], fill=(255, 183, 197, 255))
    d.ellipse([100, 140, 120, 165], fill=(40, 40, 40, 255))
    d.ellipse([136, 140, 156, 165], fill=(40, 40, 40, 255))
    d.ellipse([118, 165, 138, 182], fill=(255, 120, 140, 255))
    return img


def bear():
    img, d = canvas()
    d.ellipse([56, 80, 200, 220], fill=(121, 85, 72, 255))
    d.ellipse([50, 50, 100, 100], fill=(121, 85, 72, 255))
    d.ellipse([156, 50, 206, 100], fill=(121, 85, 72, 255))
    d.ellipse([95, 130, 115, 152], fill=(40, 40, 40, 255))
    d.ellipse([141, 130, 161, 152], fill=(40, 40, 40, 255))
    d.ellipse([108, 155, 148, 190], fill=(200, 170, 150, 255))
    d.ellipse([120, 162, 136, 176], fill=(40, 40, 40, 255))
    return img


def panda():
    img, d = canvas()
    d.ellipse([56, 80, 200, 220], fill=(250, 250, 250, 255))
    d.ellipse([50, 45, 100, 95], fill=(40, 40, 40, 255))
    d.ellipse([156, 45, 206, 95], fill=(40, 40, 40, 255))
    d.ellipse([80, 120, 120, 165], fill=(40, 40, 40, 255))
    d.ellipse([136, 120, 176, 165], fill=(40, 40, 40, 255))
    d.ellipse([95, 135, 108, 150], fill=(255, 255, 255, 255))
    d.ellipse([148, 135, 161, 150], fill=(255, 255, 255, 255))
    d.ellipse([120, 165, 136, 180], fill=(40, 40, 40, 255))
    return img


def fox():
    img, d = canvas()
    d.polygon([(60, 90), (50, 25), (110, 75)], fill=(255, 112, 67, 255))
    d.polygon([(196, 90), (206, 25), (146, 75)], fill=(255, 112, 67, 255))
    d.polygon([(70, 90), (186, 90), (128, 210)], fill=(255, 138, 101, 255))
    d.polygon([(95, 150), (161, 150), (128, 210)], fill=(250, 250, 250, 255))
    d.ellipse([92, 110, 112, 132], fill=(40, 40, 40, 255))
    d.ellipse([144, 110, 164, 132], fill=(40, 40, 40, 255))
    d.ellipse([120, 160, 136, 176], fill=(40, 40, 40, 255))
    return img


# ---- Food ----
def pizza():
    img, d = canvas()
    d.polygon([(128, 30), (40, 210), (216, 210)], fill=(255, 213, 79, 255))
    d.polygon([(128, 55), (60, 195), (196, 195)], fill=(255, 152, 0, 255))
    for (x, y) in [(110, 120), (150, 140), (120, 170), (95, 150)]:
        d.ellipse([x-12, y-12, x+12, y+12], fill=(211, 47, 47, 255))
    return img


def burger():
    img, d = canvas()
    d.ellipse([40, 50, 216, 110], fill=(255, 183, 77, 255))
    d.rectangle([45, 95, 211, 120], fill=(102, 187, 106, 255))
    d.rectangle([45, 115, 211, 145], fill=(121, 85, 72, 255))
    d.rectangle([45, 140, 211, 160], fill=(255, 235, 59, 255))
    d.ellipse([40, 150, 216, 210], fill=(255, 167, 38, 255))
    return img


def icecream():
    img, d = canvas()
    d.polygon([(90, 120), (166, 120), (128, 230)], fill=(255, 204, 128, 255))
    d.ellipse([78, 60, 148, 130], fill=(244, 143, 177, 255))
    d.ellipse([108, 50, 178, 120], fill=(255, 245, 157, 255))
    d.ellipse([95, 30, 155, 90], fill=(165, 214, 167, 255))
    d.ellipse([118, 22, 138, 42], fill=(211, 47, 47, 255))
    return img


def coffee():
    img, d = canvas()
    d.rectangle([70, 90, 170, 200], fill=(255, 255, 255, 255))
    d.rectangle([70, 90, 170, 110], fill=(141, 110, 99, 255))
    d.arc([160, 110, 210, 170], -90, 90, fill=(255, 255, 255, 255), width=12)
    for x in (95, 120, 145):
        d.line([x, 50, x, 80], fill=(189, 189, 189, 255), width=5)
    return img


def donut():
    img, d = canvas()
    d.ellipse([50, 50, 206, 206], fill=(244, 143, 177, 255))
    d.ellipse([108, 108, 148, 148], fill=(0, 0, 0, 0))
    d.ellipse([50, 50, 206, 206], outline=(216, 67, 21, 255), width=0)
    for (x, y, c) in [(90, 80, (102,187,106)), (170, 100, (255,235,59)),
                      (80, 160, (66,165,245)), (160, 170, (171,71,188)),
                      (130, 60, (255,112,67))]:
        d.line([x, y, x+14, y+10], fill=c+(255,), width=6)
    return img


def cake():
    img, d = canvas()
    d.rectangle([60, 130, 196, 210], fill=(255, 204, 188, 255))
    d.rectangle([60, 110, 196, 135], fill=(244, 143, 177, 255))
    d.line([110, 50, 110, 110], fill=(255, 235, 59, 255), width=6)
    d.line([146, 50, 146, 110], fill=(255, 235, 59, 255), width=6)
    d.ellipse([104, 35, 116, 55], fill=(255, 112, 67, 255))
    d.ellipse([140, 35, 152, 55], fill=(255, 112, 67, 255))
    for x in (80, 110, 140, 170):
        d.ellipse([x-6, 120, x+6, 132], fill=(211, 47, 47, 255))
    return img


PACKS = {
    "majoin_animals": {
        "cat": cat, "dog": dog, "rabbit": rabbit,
        "bear": bear, "panda": panda, "fox": fox,
    },
    "majoin_food": {
        "pizza": pizza, "burger": burger, "icecream": icecream,
        "coffee": coffee, "donut": donut, "cake": cake,
    },
}

PACK_META = {
    "majoin_animals": "Cute Animals",
    "majoin_food": "Yummy Food",
}

import json

if __name__ == "__main__":
    for pack_id, items in PACKS.items():
        pdir = ROOT / pack_id
        pdir.mkdir(exist_ok=True)
        images = {}
        for name, fn in items.items():
            fn().save(pdir / f"{name}.png", "PNG", optimize=True)
            images[name] = {
                "url": f"asset:{name}.png", "body": name,
                "usage": ["sticker"], "w": 256, "h": 256,
            }
            print("wrote", pack_id, name)
        manifest = {
            "pack": {"display_name": PACK_META[pack_id], "usage": ["sticker"]},
            "images": images,
        }
        (pdir / "pack.json").write_text(json.dumps(manifest, indent=2))
