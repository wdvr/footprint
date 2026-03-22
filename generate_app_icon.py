#!/usr/bin/env python3
"""
Generate Footprint app icon with recognizable continent silhouettes on a globe.
Uses simplified but real geographic coordinate data projected onto a sphere.
"""

import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
CENTER = SIZE // 2
GLOBE_RADIUS = 375
BG_COLOR = (26, 39, 68)  # Dark navy #1a2744

# Globe rotation: center on the mid-Atlantic to show Americas left, Europe/Africa right
LON_CENTER = 30  # degrees west - centers Atlantic nicely
LAT_CENTER = 15  # slight tilt to show more of Northern Hemisphere


def latlon_to_globe(lat, lon, cx, cy, radius):
    """Project lat/lon to orthographic projection on a globe, centered on LAT_CENTER/LON_CENTER."""
    lat_r = math.radians(lat)
    lon_r = math.radians(lon + LON_CENTER)  # shift longitude
    lat0 = math.radians(LAT_CENTER)

    # Orthographic projection
    cos_c = math.sin(lat0) * math.sin(lat_r) + math.cos(lat0) * math.cos(
        lat_r
    ) * math.cos(lon_r)
    if cos_c < 0.02:  # Behind globe (with small margin)
        return None

    x = cx + radius * math.cos(lat_r) * math.sin(lon_r)
    y = cy - radius * (
        math.cos(lat0) * math.sin(lat_r)
        - math.sin(lat0) * math.cos(lat_r) * math.cos(lon_r)
    )
    return (x, y)


def project_polygon(coords, cx, cy, radius):
    """Project a list of (lat, lon) to screen coords, skipping invisible points."""
    points = []
    for lat, lon in coords:
        p = latlon_to_globe(lat, lon, cx, cy, radius)
        if p:
            points.append(p)
    return points


# ============================================================
# CONTINENT OUTLINES (lat, lon) - simplified but recognizable
# ============================================================

NORTH_AMERICA = [
    # Alaska
    (60, -150),
    (65, -168),
    (68, -165),
    (70, -160),
    (72, -155),
    (70, -145),
    (65, -140),
    (60, -140),
    # West coast down
    (58, -137),
    (55, -133),
    (52, -130),
    (50, -128),
    (48, -124),
    (45, -124),
    (42, -124),
    (40, -124),
    (38, -123),
    (35, -120),
    (33, -117),
    (32, -117),
    # Mexico/Central America
    (30, -115),
    (28, -112),
    (25, -110),
    (22, -106),
    (20, -105),
    (18, -103),
    (16, -95),
    (15, -90),
    (15, -87),
    # Gulf coast
    (18, -88),
    (20, -87),
    (22, -90),
    (25, -90),
    (28, -92),
    (29, -95),
    (30, -90),
    (30, -88),
    # Florida
    (30, -85),
    (28, -82),
    (25, -80),
    (25, -81),
    (27, -82),
    (30, -82),
    # East coast up
    (32, -80),
    (35, -76),
    (37, -76),
    (39, -75),
    (40, -74),
    (41, -72),
    (42, -70),
    (43, -70),
    (44, -68),
    (45, -67),
    # Maritime Canada
    (47, -60),
    (46, -57),
    (47, -53),
    (50, -56),
    (52, -56),
    (53, -60),
    (55, -60),
    (58, -62),
    # Hudson Bay / Arctic
    (60, -65),
    (63, -68),
    (65, -72),
    (68, -75),
    (70, -80),
    (72, -85),
    (73, -90),
    (72, -95),
    (70, -100),
    (72, -108),
    (70, -115),
    (72, -120),
    (70, -130),
    (70, -138),
    (65, -140),
    (60, -145),
    (60, -150),
]

SOUTH_AMERICA = [
    # North coast
    (12, -72),
    (12, -68),
    (10, -65),
    (10, -62),
    (8, -60),
    (7, -57),
    (5, -52),
    (3, -50),
    (0, -50),
    # East coast (Brazil bulge)
    (-2, -44),
    (-5, -35),
    (-8, -35),
    (-10, -37),
    (-13, -38),
    (-15, -39),
    (-18, -40),
    (-20, -40),
    (-23, -43),
    (-25, -48),
    (-28, -49),
    (-30, -51),
    (-33, -53),
    # Southern tip
    (-38, -57),
    (-42, -63),
    (-46, -66),
    (-50, -68),
    (-52, -70),
    (-55, -68),
    (-55, -66),
    (-54, -64),
    # West coast up
    (-52, -72),
    (-48, -75),
    (-44, -73),
    (-40, -73),
    (-37, -73),
    (-33, -72),
    (-30, -71),
    (-27, -70),
    (-22, -70),
    (-18, -70),
    (-15, -75),
    (-12, -77),
    (-8, -79),
    (-5, -80),
    (-2, -80),
    (0, -78),
    # Colombia/Venezuela
    (2, -77),
    (5, -77),
    (7, -72),
    (8, -72),
    (10, -72),
    (11, -74),
    (12, -72),
]

EUROPE = [
    # Portugal/Spain
    (36, -9),
    (37, -8),
    (37, -2),
    (38, 0),
    (40, 0),
    (42, -2),
    (43, -2),
    (43, -9),
    (44, -8),
    # France coast
    (44, -1),
    (46, -1),
    (47, -2),
    (48, -5),
    (49, -5),
    # British Isles (simplified as part of mass)
    (51, -1),
    (52, 2),
    (53, 0),
    # Netherlands/Germany/Denmark
    (54, 4),
    (54, 8),
    (55, 9),
    (56, 8),
    (57, 10),
    # Scandinavia
    (58, 12),
    (60, 10),
    (60, 5),
    (62, 5),
    (64, 12),
    (66, 14),
    (68, 16),
    (70, 22),
    (71, 26),
    (70, 30),
    # Finland/Baltic
    (68, 28),
    (65, 25),
    (62, 24),
    (60, 22),
    (58, 18),
    (56, 18),
    (55, 14),
    (54, 14),
    (53, 20),
    (52, 22),
    (51, 24),
    # South through Poland, etc
    (50, 20),
    (48, 17),
    (47, 16),
    (46, 15),
    (45, 14),
    (44, 14),
    (43, 12),
    (42, 12),
    # Italy boot
    (41, 14),
    (40, 16),
    (38, 16),
    (37, 15),
    (38, 12),
    (40, 10),
    (42, 10),
    # Back through France
    (44, 8),
    (46, 6),
    (47, 6),
    (48, 7),
    (48, 2),
    (47, 0),
    (46, -1),
    # Close through Iberia
    (44, -1),
    (43, 3),
    (42, 3),
    (40, 0),
    (38, -1),
    (37, -2),
    (36, -6),
    (36, -9),
]

AFRICA = [
    # Northwest
    (36, -6),
    (35, -1),
    (37, 10),
    (37, 15),
    (37, 20),
    (33, 32),
    (32, 33),
    (30, 32),
    # Suez/East
    (28, 33),
    (25, 35),
    (20, 38),
    (15, 42),
    (12, 44),
    (10, 42),
    (5, 42),
    (2, 42),
    (0, 40),
    (-3, 38),
    (-5, 40),
    (-8, 40),
    (-10, 40),
    # East coast down
    (-12, 38),
    (-15, 35),
    (-20, 35),
    (-25, 33),
    (-28, 32),
    (-30, 30),
    # Southern tip
    (-34, 26),
    (-35, 20),
    (-34, 18),
    # West coast up
    (-32, 17),
    (-28, 16),
    (-25, 15),
    (-20, 13),
    (-15, 12),
    (-10, 14),
    (-5, 10),
    (0, 5),
    (3, 5),
    (5, 0),
    (5, -4),
    (8, -10),
    (10, -14),
    (13, -16),
    (15, -17),
    (18, -16),
    (21, -17),
    (24, -16),
    (28, -13),
    (31, -10),
    (33, -7),
    (35, -3),
    (36, -6),
]

GREENLAND = [
    (60, -46),
    (62, -43),
    (65, -40),
    (68, -32),
    (70, -25),
    (73, -20),
    (76, -18),
    (78, -20),
    (80, -25),
    (82, -30),
    (83, -38),
    (82, -48),
    (80, -58),
    (78, -68),
    (76, -68),
    (74, -58),
    (72, -55),
    (70, -52),
    (68, -50),
    (65, -50),
    (62, -48),
    (60, -46),
]

GREAT_BRITAIN = [
    (50, -5),
    (51, 1),
    (53, 0),
    (54, -1),
    (55, -3),
    (57, -5),
    (58, -5),
    (58, -7),
    (57, -7),
    (56, -6),
    (55, -5),
    (54, -4),
    (53, -4),
    (51, -4),
    (50, -5),
]

ICELAND = [
    (64, -24),
    (65, -20),
    (66, -18),
    (66, -14),
    (65, -13),
    (64, -14),
    (63, -18),
    (63, -22),
    (64, -24),
]

# === Country highlight regions ===

USA_LOWER48 = [
    (48, -124),
    (48, -110),
    (49, -100),
    (49, -95),
    (47, -90),
    (46, -85),
    (43, -82),
    (42, -80),
    (42, -72),
    (41, -72),
    (40, -74),
    (39, -75),
    (37, -76),
    (35, -76),
    (32, -80),
    (30, -82),
    (25, -80),
    (25, -82),
    (28, -83),
    (30, -85),
    (30, -90),
    (29, -95),
    (28, -97),
    (26, -97),
    (26, -100),
    (30, -104),
    (32, -106),
    (32, -115),
    (33, -117),
    (35, -120),
    (38, -123),
    (42, -124),
    (45, -124),
    (48, -124),
]

FRANCE_COUNTRY = [
    (51, 2),
    (49, 0),
    (48, -5),
    (47, -2),
    (46, -1),
    (44, -1),
    (43, 0),
    (42, 3),
    (43, 5),
    (43, 7),
    (44, 8),
    (46, 6),
    (47, 6),
    (48, 8),
    (49, 6),
    (50, 4),
    (51, 2),
]

BRAZIL_COUNTRY = [
    (5, -52),
    (3, -50),
    (0, -50),
    (-2, -44),
    (-5, -35),
    (-8, -35),
    (-10, -37),
    (-13, -38),
    (-15, -39),
    (-18, -40),
    (-20, -40),
    (-23, -43),
    (-25, -48),
    (-28, -49),
    (-30, -51),
    (-33, -53),
    (-30, -55),
    (-27, -57),
    (-22, -58),
    (-18, -57),
    (-15, -60),
    (-10, -68),
    (-8, -73),
    (-5, -73),
    (-2, -70),
    (0, -65),
    (2, -60),
    (5, -55),
    (5, -52),
]

SPAIN_COUNTRY = [
    (44, -8),
    (43, -2),
    (42, 0),
    (42, 3),
    (40, 4),
    (38, 0),
    (37, -2),
    (37, -7),
    (38, -9),
    (40, -9),
    (42, -9),
    (43, -9),
    (44, -8),
]

ITALY_COUNTRY = [
    (46, 7),
    (47, 12),
    (46, 14),
    (44, 14),
    (43, 12),
    (42, 12),
    (41, 14),
    (40, 16),
    (38, 16),
    (37, 15),
    (38, 12),
    (40, 10),
    (42, 10),
    (44, 8),
    (46, 7),
]

MEXICO_COUNTRY = [
    (32, -117),
    (30, -115),
    (28, -112),
    (25, -110),
    (22, -106),
    (20, -105),
    (18, -103),
    (16, -95),
    (15, -90),
    (15, -87),
    (18, -88),
    (20, -87),
    (22, -90),
    (25, -90),
    (26, -97),
    (28, -100),
    (30, -104),
    (32, -106),
    (32, -117),
]

MOROCCO_COUNTRY = [
    (36, -6),
    (35, -1),
    (34, -2),
    (33, -5),
    (31, -8),
    (30, -10),
    (28, -13),
    (29, -10),
    (31, -10),
    (33, -7),
    (35, -3),
    (36, -6),
]

UK_COUNTRY = [
    (50, -5),
    (51, 1),
    (53, 0),
    (54, -1),
    (55, -3),
    (57, -5),
    (58, -5),
    (58, -7),
    (57, -7),
    (56, -6),
    (55, -5),
    (54, -4),
    (53, -4),
    (51, -4),
    (50, -5),
]

GERMANY_COUNTRY = [
    (54, 8),
    (54, 14),
    (52, 14),
    (50, 14),
    (48, 13),
    (47, 12),
    (47, 7),
    (48, 8),
    (50, 7),
    (52, 7),
    (54, 8),
]

NORWAY_COUNTRY = [
    (58, 6),
    (60, 5),
    (62, 5),
    (64, 12),
    (66, 14),
    (68, 16),
    (70, 22),
    (71, 26),
    (70, 28),
    (68, 18),
    (66, 15),
    (64, 13),
    (62, 8),
    (60, 8),
    (58, 8),
    (58, 6),
]

ARGENTINA_COUNTRY = [
    (-22, -65),
    (-25, -65),
    (-28, -65),
    (-30, -65),
    (-33, -68),
    (-38, -68),
    (-42, -65),
    (-46, -66),
    (-50, -68),
    (-52, -70),
    (-55, -68),
    (-55, -66),
    (-54, -64),
    (-52, -68),
    (-48, -75),
    (-44, -73),
    (-40, -73),
    (-38, -68),
    (-38, -57),
    (-35, -55),
    (-33, -53),
    (-30, -55),
    (-27, -57),
    (-22, -63),
    (-22, -65),
]

COLOMBIA_COUNTRY = [
    (12, -72),
    (11, -74),
    (8, -77),
    (5, -77),
    (2, -77),
    (0, -70),
    (-2, -70),
    (-4, -70),
    (-2, -68),
    (0, -67),
    (2, -67),
    (5, -67),
    (7, -68),
    (8, -72),
    (10, -72),
    (12, -72),
]


def draw_pin(draw, x, y, color, pin_size=14):
    """Draw a small map pin marker."""
    r = pin_size
    # Pin body (circle)
    draw.ellipse([x - r, y - r, x + r, y + r], fill=color, outline="white", width=3)
    # Inner dot
    ri = pin_size // 3
    draw.ellipse([x - ri, y - ri, x + ri, y + ri], fill="white")
    # Pin point (triangle below)
    draw.polygon(
        [(x - r * 0.45, y + r * 0.7), (x + r * 0.45, y + r * 0.7), (x, y + r * 2.0)],
        fill=color,
    )


def generate_icon(output_path, highlighted_countries, version_label="v1"):
    """Generate an app icon."""
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)

    # --- Globe shadow ---
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        [
            CENTER - GLOBE_RADIUS + 18,
            CENTER - GLOBE_RADIUS + 18,
            CENTER + GLOBE_RADIUS + 18,
            CENTER + GLOBE_RADIUS + 18,
        ],
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # --- Globe ocean with radial gradient ---
    globe = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    globe_draw = ImageDraw.Draw(globe)

    for i in range(GLOBE_RADIUS, 0, -1):
        t = i / GLOBE_RADIUS
        # Deeper blue at edges, lighter toward center
        r = int(20 + 35 * (1 - t))
        g = int(55 + 55 * (1 - t))
        b = int(110 + 70 * (1 - t))
        globe_draw.ellipse(
            [CENTER - i, CENTER - i, CENTER + i, CENTER + i], fill=(r, g, b, 255)
        )

    img = Image.alpha_composite(img, globe)
    draw = ImageDraw.Draw(img)

    # --- Subtle grid lines ---
    grid_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid_img)

    for lat in range(-60, 80, 30):
        points = []
        for lon in range(-180, 181, 2):
            p = latlon_to_globe(lat, lon, CENTER, CENTER, GLOBE_RADIUS)
            if p:
                # Check if within globe bounds
                dx, dy = p[0] - CENTER, p[1] - CENTER
                if dx * dx + dy * dy <= (GLOBE_RADIUS - 2) ** 2:
                    points.append(p)
        if len(points) > 1:
            grid_draw.line(points, fill=(255, 255, 255, 18), width=1)

    for lon in range(-180, 180, 30):
        points = []
        for lat in range(-90, 91, 2):
            p = latlon_to_globe(lat, lon, CENTER, CENTER, GLOBE_RADIUS)
            if p:
                dx, dy = p[0] - CENTER, p[1] - CENTER
                if dx * dx + dy * dy <= (GLOBE_RADIUS - 2) ** 2:
                    points.append(p)
        if len(points) > 1:
            grid_draw.line(points, fill=(255, 255, 255, 18), width=1)

    img = Image.alpha_composite(img, grid_img)
    draw = ImageDraw.Draw(img)

    # --- Draw continents as base land ---
    land_color = (55, 90, 55, 190)
    land_outline = (70, 110, 70, 210)

    continent_data = [
        NORTH_AMERICA,
        SOUTH_AMERICA,
        EUROPE,
        AFRICA,
        GREENLAND,
        GREAT_BRITAIN,
        ICELAND,
    ]

    for continent in continent_data:
        points = project_polygon(continent, CENTER, CENTER, GLOBE_RADIUS)
        if len(points) >= 3:
            # Clip to globe circle
            clipped = []
            for px, py in points:
                dx, dy = px - CENTER, py - CENTER
                dist = math.sqrt(dx * dx + dy * dy)
                if dist <= GLOBE_RADIUS - 1:
                    clipped.append((px, py))
                else:
                    # Push to edge
                    scale = (GLOBE_RADIUS - 1) / dist
                    clipped.append((CENTER + dx * scale, CENTER + dy * scale))
            if len(clipped) >= 3:
                draw.polygon(clipped, fill=land_color, outline=land_outline, width=1)

    # --- Highlight countries ---
    for country_coords, color, pin_latlon, pin_color in highlighted_countries:
        points = project_polygon(country_coords, CENTER, CENTER, GLOBE_RADIUS)
        if len(points) >= 3:
            clipped = []
            for px, py in points:
                dx, dy = px - CENTER, py - CENTER
                dist = math.sqrt(dx * dx + dy * dy)
                if dist <= GLOBE_RADIUS - 1:
                    clipped.append((px, py))
                else:
                    scale = (GLOBE_RADIUS - 1) / dist
                    clipped.append((CENTER + dx * scale, CENTER + dy * scale))
            if len(clipped) >= 3:
                draw.polygon(
                    clipped, fill=color + (210,), outline=(255, 255, 255, 160), width=2
                )

    # --- Draw pins ---
    for country_coords, color, pin_latlon, pin_color in highlighted_countries:
        if pin_latlon:
            lat, lon = pin_latlon
            p = latlon_to_globe(lat, lon, CENTER, CENTER, GLOBE_RADIUS)
            if p:
                dx, dy = p[0] - CENTER, p[1] - CENTER
                if dx * dx + dy * dy < (GLOBE_RADIUS - 20) ** 2:
                    draw_pin(draw, p[0], p[1], pin_color)

    # --- Atmosphere glow ---
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for i in range(10):
        r = GLOBE_RADIUS + i - 2
        alpha = int(50 - i * 5)
        if alpha > 0:
            glow_draw.ellipse(
                [CENTER - r, CENTER - r, CENTER + r, CENTER + r],
                outline=(80, 150, 255, alpha),
                width=2,
            )
    img = Image.alpha_composite(img, glow)

    # --- Specular highlight (top-left) ---
    spec = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    spec_draw = ImageDraw.Draw(spec)
    spec_cx = CENTER - GLOBE_RADIUS * 0.28
    spec_cy = CENTER - GLOBE_RADIUS * 0.28
    spec_r = GLOBE_RADIUS * 0.32
    for i in range(int(spec_r), 0, -1):
        t = i / spec_r
        alpha = int(22 * (1 - t))
        spec_draw.ellipse(
            [spec_cx - i, spec_cy - i, spec_cx + i, spec_cy + i],
            fill=(255, 255, 255, alpha),
        )
    img = Image.alpha_composite(img, spec)

    # Convert to RGB
    final = Image.new("RGB", (SIZE, SIZE), BG_COLOR)
    final.paste(img, mask=img.split()[3])
    final.save(output_path, "PNG")
    print(f"Saved {version_label} icon to: {output_path}")


# ============================================================
# Version 1: 4 highlighted countries
# ============================================================
v1_countries = [
    (USA_LOWER48, (255, 107, 107), (39, -98), (255, 107, 107)),  # USA - coral
    (FRANCE_COUNTRY, (255, 179, 71), (47, 2), (255, 179, 71)),  # France - amber
    (BRAZIL_COUNTRY, (78, 205, 196), (-12, -50), (78, 205, 196)),  # Brazil - teal
    (SPAIN_COUNTRY, (255, 140, 105), (40, -3), (255, 140, 105)),  # Spain - salmon
]

generate_icon(
    "/Users/wouter/dev/footprint/ios/Footprint/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    v1_countries,
    "v1",
)

# ============================================================
# Version 2: 8-10 highlighted countries
# ============================================================
v2_countries = [
    (USA_LOWER48, (255, 107, 107), (39, -98), (255, 107, 107)),  # USA - coral
    (FRANCE_COUNTRY, (255, 179, 71), (47, 2), (255, 179, 71)),  # France - amber
    (BRAZIL_COUNTRY, (78, 205, 196), (-12, -50), (78, 205, 196)),  # Brazil - teal
    (SPAIN_COUNTRY, (255, 140, 105), (40, -3), (255, 140, 105)),  # Spain - salmon
    (MEXICO_COUNTRY, (255, 200, 87), (23, -102), (255, 200, 87)),  # Mexico - golden
    (MOROCCO_COUNTRY, (200, 130, 255), (32, -6), (200, 130, 255)),  # Morocco - purple
    (UK_COUNTRY, (120, 200, 255), (54, -2), (120, 200, 255)),  # UK - light blue
    (GERMANY_COUNTRY, (255, 160, 160), (51, 10), (255, 160, 160)),  # Germany - pink
    (NORWAY_COUNTRY, (100, 220, 180), (65, 12), (100, 220, 180)),  # Norway - mint
    (COLOMBIA_COUNTRY, (255, 220, 100), (5, -73), (255, 220, 100)),  # Colombia - yellow
]

generate_icon("/Users/wouter/dev/footprint/app_icon_v2.png", v2_countries, "v2")
