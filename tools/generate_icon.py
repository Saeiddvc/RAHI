"""Generate RAHI launcher and native splash source assets.

Requires:
    python -m pip install Pillow

Run:
    python tools/generate_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

PRIMARY = (31, 111, 235, 255)
WHITE = (255, 255, 255, 255)
FADED = (170, 210, 255, 255)
OUTPUT = Path("assets/icon")


def draw_compass(size: int, background, padding_ratio: float) -> Image.Image:
    image = Image.new("RGBA", (size, size), background)
    draw = ImageDraw.Draw(image)

    pad = int(size * padding_ratio)
    center = size // 2
    radius = (size - 2 * pad) // 2
    stroke = max(8, size // 48)

    draw.ellipse(
        [center - radius, center - radius, center + radius, center + radius],
        outline=WHITE,
        width=stroke,
    )

    inner = max(4, int(radius * 0.15))
    draw.ellipse(
        [center - inner, center - inner, center + inner, center + inner],
        fill=WHITE,
    )

    draw.polygon(
        [
            (center, center - int(radius * 0.70)),
            (center - int(radius * 0.20), center),
            (center + int(radius * 0.20), center),
        ],
        fill=WHITE,
    )
    draw.polygon(
        [
            (center, center + int(radius * 0.70)),
            (center - int(radius * 0.20), center),
            (center + int(radius * 0.20), center),
        ],
        fill=FADED,
    )
    return image


def launcher_icon(size: int = 1024) -> Image.Image:
    source = draw_compass(size, PRIMARY, 0.10)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(size * 0.22)
    draw.rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=radius,
        fill=255,
    )
    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result.paste(source, (0, 0), mask)
    return result


def transparent_splash(size: int, icon_ratio: float = 0.72) -> Image.Image:
    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon_size = int(size * icon_ratio)
    compass = draw_compass(icon_size, (0, 0, 0, 0), 0.06)
    offset = (size - icon_size) // 2
    result.alpha_composite(compass, (offset, offset))
    return result


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)

    outputs = {
        "rahi_icon.png": launcher_icon(1024),
        "rahi_splash.png": transparent_splash(768),
        "rahi_splash_android12.png": transparent_splash(1152),
    }

    for name, image in outputs.items():
        path = OUTPUT / name
        image.save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    main()
