"""Generate 6 placeholder stickers (256x256 PNG) for majoin_v1."""
from PIL import Image, ImageDraw
from pathlib import Path

# Repo layout: tools/sticker-gen/ -> client/assets/stickers/majoin_v1/
OUT = Path(__file__).parents[2] / "client/assets/stickers/majoin_v1"
SIZE = 256
C = SIZE // 2

def disk(color):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([16, 16, SIZE-16, SIZE-16], fill=color)
    return img, d

def smile():
    img, d = disk((255, 213, 79, 255))
    # eyes
    d.ellipse([78, 90, 110, 130], fill=(40, 40, 40, 255))
    d.ellipse([146, 90, 178, 130], fill=(40, 40, 40, 255))
    # smile arc
    d.arc([72, 110, 184, 200], start=10, end=170, fill=(40, 40, 40, 255), width=10)
    return img

def love():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    red = (231, 76, 60, 255)
    d.pieslice([40, 50, 140, 150], 180, 360, fill=red)
    d.pieslice([116, 50, 216, 150], 180, 360, fill=red)
    d.polygon([(40, 100), (216, 100), (128, 220)], fill=red)
    return img

def cry():
    img, d = disk((116, 185, 255, 255))
    d.arc([78, 100, 110, 132], start=200, end=340, fill=(40,40,40,255), width=8)
    d.arc([146, 100, 178, 132], start=200, end=340, fill=(40,40,40,255), width=8)
    d.arc([90, 160, 166, 220], start=200, end=340, fill=(40,40,40,255), width=10)
    # tears
    d.polygon([(80, 130), (70, 180), (95, 180)], fill=(64, 164, 223, 255))
    d.polygon([(176, 130), (166, 180), (191, 180)], fill=(64, 164, 223, 255))
    return img

def thumbsup():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = (255, 206, 158, 255)
    # fist
    d.rounded_rectangle([60, 120, 200, 230], radius=24, fill=skin)
    # thumb
    d.rounded_rectangle([110, 30, 160, 140], radius=22, fill=skin)
    d.line([60, 145, 200, 145], fill=(180, 130, 90, 255), width=3)
    return img

def shock():
    img, d = disk((255, 235, 59, 255))
    d.ellipse([78, 90, 118, 140], fill=(40,40,40,255))
    d.ellipse([138, 90, 178, 140], fill=(40,40,40,255))
    d.ellipse([108, 160, 148, 220], fill=(40,40,40,255))
    return img

def party():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # cone
    d.polygon([(80, 220), (200, 220), (140, 40)], fill=(155, 89, 182, 255))
    d.polygon([(80, 220), (200, 220), (140, 40)], outline=(108, 52, 131, 255), width=4)
    # confetti
    for (x, y, c) in [(40,60,(231,76,60)),(220,80,(46,204,113)),(50,170,(52,152,219)),(210,180,(241,196,15)),(120,30,(230,126,34))]:
        d.ellipse([x-8,y-8,x+8,y+8], fill=c+(255,))
    return img

GEN = {
    "smile.png": smile,
    "love.png": love,
    "cry.png": cry,
    "thumbsup.png": thumbsup,
    "shock.png": shock,
    "party.png": party,
}

if __name__ == "__main__":
    for name, fn in GEN.items():
        fn().save(OUT / name, "PNG", optimize=True)
        print("wrote", name)
