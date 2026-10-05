#!/usr/bin/env python3
"""Compose authentic simulator captures into App Store product-page artwork."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont


INK = (11, 12, 15)
DEEP = (17, 19, 23)
PANEL = (25, 27, 31)
LINE = (55, 60, 67)
STEEL = (165, 190, 210)
CREAM = (241, 240, 236)
MUTED = (174, 180, 188)

DIMENSIONS = {
    "iphone-65": (1284, 2778),
    "ipad-13": (2064, 2752),
}

HEADLINES = {
    "en": (
        "START AT 17. BECOME A LEGEND.",
        "EVERY WEEK, YOU DECIDE.",
        "A WORLD THAT NEVER STOPS.",
        "TRAIN YOUR WAY TO THE TOP.",
        "CHOOSE YOUR NEXT DESTINATION.",
        "LIVE BEYOND MATCHDAY.",
        "CHASE TROPHIES. BUILD A LEGACY.",
        "FULL CAREER. FREE. OFFLINE. NO ADS.",
    ),
    "es": (
        "EMPIEZA A LOS 17. CONVIÉRTETE EN LEYENDA.",
        "CADA SEMANA, TÚ DECIDES.",
        "UN MUNDO QUE NUNCA SE DETIENE.",
        "ENTRENA PARA LLEGAR A LA CIMA.",
        "ELIGE TU PRÓXIMO DESTINO.",
        "VIVE MÁS ALLÁ DEL PARTIDO.",
        "GANA TROFEOS. CREA TU LEGADO.",
        "CARRERA COMPLETA. GRATIS. SIN CONEXIÓN. SIN ANUNCIOS.",
    ),
    "pt-BR": (
        "COMECE AOS 17. TORNE-SE UMA LENDA.",
        "TODA SEMANA, VOCÊ DECIDE.",
        "UM MUNDO QUE NUNCA PARA.",
        "TREINE PARA CHEGAR AO TOPO.",
        "ESCOLHA SEU PRÓXIMO DESTINO.",
        "VIVA ALÉM DOS JOGOS.",
        "GANHE TROFÉUS. CONSTRUA SEU LEGADO.",
        "CARREIRA COMPLETA. GRÁTIS. OFFLINE. SEM ANÚNCIOS.",
    ),
    "fr": (
        "COMMENCEZ À 17 ANS. DEVENEZ UNE LÉGENDE.",
        "CHAQUE SEMAINE, VOUS DÉCIDEZ.",
        "UN MONDE QUI NE S’ARRÊTE JAMAIS.",
        "ENTRAÎNEZ-VOUS POUR ATTEINDRE LE SOMMET.",
        "CHOISISSEZ VOTRE PROCHAINE DESTINATION.",
        "VIVEZ AU-DELÀ DES MATCHS.",
        "GAGNEZ DES TROPHÉES. BÂTISSEZ VOTRE LÉGENDE.",
        "CARRIÈRE COMPLÈTE. GRATUITE. HORS LIGNE. SANS PUB.",
    ),
}


@dataclass(frozen=True)
class Story:
    source: str
    output: str
    accent: tuple[int, int, int]


STORIES = (
    Story("01-player-profile.png", "01-start-at-17.png", STEEL),
    Story("02-spotlight-decision.png", "02-weekly-decision.png", STEEL),
    Story("03-world-club.png", "03-living-world.png", STEEL),
    Story("04-weekly-focus.png", "04-training-focus.png", STEEL),
    Story("05-transfer-request.png", "05-next-destination.png", STEEL),
    Story("06-life-overview.png", "06-life-beyond-matchday.png", STEEL),
    Story("07-legacy.png", "07-build-a-legacy.png", STEEL),
    Story("08-career-hub.png", "08-full-career-offline.png", STEEL),
)

FONT = Path("/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf")
BODY_FONT = Path("/System/Library/Fonts/SFNS.ttf")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--locale", choices=tuple(HEADLINES), required=True)
    parser.add_argument("--device-class", choices=tuple(DIMENSIONS), required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def cover(image: Image.Image, size: tuple[int, int], x_bias: float = 0.5) -> Image.Image:
    width, height = size
    scale = max(width / image.width, height / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = round((resized.width - width) * x_bias)
    top = round((resized.height - height) * 0.34)
    return resized.crop((left, top, left + width, top + height))


def split_headline(
    text: str,
    max_width: int,
    maximum_size: int,
    minimum_size: int,
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    words = text.split()
    candidates = [[text]]
    candidates.extend([[
        " ".join(words[:index]),
        " ".join(words[index:]),
    ] for index in range(1, len(words))])
    for size in range(maximum_size, minimum_size - 1, -2):
        font = ImageFont.truetype(FONT, size)
        fitting = [
            lines
            for lines in candidates
            if max(font.getlength(line) for line in lines) <= max_width
        ]
        if not fitting:
            continue
        one_line = [lines for lines in fitting if len(lines) == 1]
        if one_line and font.getlength(one_line[0][0]) <= max_width * 0.78:
            return font, one_line[0]
        two_line = [lines for lines in fitting if len(lines) == 2]
        if two_line:
            two_line.sort(
                key=lambda lines: abs(font.getlength(lines[0]) - font.getlength(lines[1]))
            )
            return font, two_line[0]
        return font, fitting[0]
    raise ValueError(f"Headline does not fit above readability floor: {text}")


def rounded_paste(
    canvas: Image.Image,
    screenshot: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    accent: tuple[int, int, int],
) -> None:
    left, top, right, bottom = box
    size = (right - left, bottom - top)
    shot = screenshot.resize(size, Image.Resampling.LANCZOS)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)

    shadow_mask = Image.new("L", canvas.size, 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_draw.rounded_rectangle(
        (left - 4, top + 18, right + 4, bottom + 28),
        radius=radius + 8,
        fill=210,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(radius // 2))
    shadow = Image.new("RGB", canvas.size, INK)
    canvas.paste(shadow, mask=shadow_mask)
    canvas.paste(shot, (left, top), mask)

    border = ImageDraw.Draw(canvas)
    border.rounded_rectangle(
        (left - 2, top - 2, right + 1, bottom + 1),
        radius=radius + 2,
        outline=accent,
        width=max(3, canvas.width // 360),
    )


def compose(
    capture: Image.Image,
    background: Image.Image,
    mark_image: Image.Image,
    headline: str,
    sequence: int,
    accent: tuple[int, int, int],
    size: tuple[int, int],
) -> Image.Image:
    width, height = size
    canvas = cover(background, size, x_bias=0.43 + (sequence % 3) * 0.06).convert("RGB")
    canvas = canvas.filter(ImageFilter.GaussianBlur(max(2, width // 320)))

    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    shade_draw.rectangle((0, 0, width, height), fill=(*INK, 192))
    for y in range(height):
        alpha = int(60 + 105 * (y / height))
        shade_draw.line((0, y, width, y), fill=(*DEEP, alpha))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shade).convert("RGB")

    draw = ImageDraw.Draw(canvas)
    margin = round(width * 0.075)
    brand_y = round(height * 0.032)
    mark = round(width * 0.043)
    mark_mask = Image.new("L", (mark, mark))
    ImageDraw.Draw(mark_mask).rounded_rectangle(
        (0, 0, mark, mark), radius=mark // 5, fill=255
    )
    canvas.paste(
        mark_image.resize((mark, mark), Image.Resampling.LANCZOS),
        (margin, brand_y),
        mark_mask,
    )
    brand_font = ImageFont.truetype(FONT, round(width * 0.033))
    draw.text(
        (margin + mark + round(width * 0.015), brand_y + mark * 0.08),
        "ELEVENWARD",
        font=brand_font,
        fill=MUTED,
        stroke_width=0,
    )

    badge_radius = round(width * 0.033)
    badge_x = width - margin - badge_radius
    badge_y = brand_y + badge_radius
    draw.ellipse(
        (
            badge_x - badge_radius,
            badge_y - badge_radius,
            badge_x + badge_radius,
            badge_y + badge_radius,
        ),
        fill=PANEL,
        outline=accent,
        width=max(3, width // 400),
    )
    badge_font = ImageFont.truetype(BODY_FONT, round(width * 0.026))
    label = f"{sequence:02d}"
    label_box = draw.textbbox((0, 0), label, font=badge_font)
    draw.text(
        (
            badge_x - (label_box[2] - label_box[0]) / 2,
            badge_y - (label_box[3] - label_box[1]) / 2 - label_box[1],
        ),
        label,
        font=badge_font,
        fill=accent,
    )

    max_size = round(width * (0.087 if width < 1500 else 0.064))
    min_size = round(width * (0.050 if width < 1500 else 0.039))
    headline_font, lines = split_headline(
        headline,
        width - 2 * margin,
        max_size,
        min_size,
    )
    line_height = round(headline_font.size * 0.88)
    headline_y = round(height * 0.080)
    for line_index, line in enumerate(lines):
        draw.text(
            (margin, headline_y + line_index * line_height),
            line,
            font=headline_font,
            fill=CREAM,
            stroke_width=1,
            stroke_fill=CREAM,
        )
    rule_y = round(height * 0.166)
    draw.rounded_rectangle(
        (margin, rule_y, margin + round(width * 0.16), rule_y + max(5, width // 250)),
        radius=4,
        fill=accent,
    )

    frame_scale = 0.78
    frame_width = round(width * frame_scale)
    frame_height = round(height * frame_scale)
    frame_left = (width - frame_width) // 2
    frame_top = round(height * 0.188)
    rounded_paste(
        canvas,
        capture,
        (frame_left, frame_top, frame_left + frame_width, frame_top + frame_height),
        radius=round(width * 0.034),
        accent=accent,
    )
    return canvas


def contact_sheet(images: list[Image.Image], labels: list[str]) -> Image.Image:
    columns = 4
    thumb_width = 300
    thumb_height = round(thumb_width * images[0].height / images[0].width)
    cell_width = thumb_width + 28
    cell_height = thumb_height + 72
    rows = 2
    sheet = Image.new(
        "RGB",
        (columns * cell_width + 44, rows * cell_height + 64),
        INK,
    )
    draw = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(BODY_FONT, 22)
    for index, (image, label) in enumerate(zip(images, labels, strict=True)):
        row, column = divmod(index, columns)
        left = 22 + column * cell_width
        top = 22 + row * cell_height
        thumb = image.resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (left, top))
        draw.text((left, top + thumb_height + 14), label, font=label_font, fill=CREAM)
    return sheet


def main() -> int:
    args = parse_args()
    captures = args.captures.expanduser().resolve()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    expected_size = DIMENSIONS[args.device_class]
    repo_root = Path(__file__).resolve().parents[2]
    background_path = repo_root / "assets" / "visual" / "stadium-graphite.png"
    background = Image.open(background_path).convert("RGB")
    mark_image = Image.open(
        repo_root / "assets" / "branding" / "graphite" / "elevenward-11-ui.png"
    ).convert("RGB")
    srgb = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    completed: list[Image.Image] = []
    labels: list[str] = []

    for index, story in enumerate(STORIES, start=1):
        capture_path = captures / story.source
        if not capture_path.exists():
            raise FileNotFoundError(capture_path)
        with Image.open(capture_path) as source:
            if source.size != expected_size:
                raise ValueError(
                    f"{capture_path} is {source.size}; expected {expected_size}."
                )
            final = compose(
                source.convert("RGB"),
                background,
                mark_image,
                HEADLINES[args.locale][index - 1],
                index,
                story.accent,
                expected_size,
            )
        final_path = output / story.output
        final.save(final_path, "PNG", icc_profile=srgb, optimize=True)
        completed.append(final)
        labels.append(f"{index}. {story.output.removesuffix('.png')}")

    product_page_root = output.parents[1]
    sheet_dir = product_page_root / "contact-sheets"
    sheet_dir.mkdir(parents=True, exist_ok=True)
    sheet = contact_sheet(completed, labels)
    sheet.save(
        sheet_dir / f"{args.locale}-{args.device_class}.png",
        "PNG",
        icc_profile=srgb,
        optimize=True,
    )
    print(f"Composed 8 {args.locale} {args.device_class} screenshots in {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
