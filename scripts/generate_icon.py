#!/usr/bin/env python3
"""Generate app icon for Skratch travel tracker app."""

from pathlib import Path

from PIL import Image, ImageDraw


def create_app_icon(size: int = 1024) -> Image.Image:
    """Create the Skratch app icon.

    Design: A stylized globe with scratch marks representing visited places.
    Colors: Deep teal/ocean blue for water, green for land hints, gold accents.
    """
    # Create image with gradient background
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colors
    bg_color = (20, 60, 90)  # Deep ocean blue
    globe_color = (40, 120, 160)  # Teal blue
    land_color = (60, 160, 120)  # Green
    scratch_color = (255, 200, 80)  # Gold

    # Background with rounded corners
    corner_radius = size // 5
    draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)], radius=corner_radius, fill=bg_color
    )

    # Globe parameters
    center = size // 2
    globe_radius = int(size * 0.38)

    # Draw globe base (ocean)
    draw.ellipse(
        [
            (center - globe_radius, center - globe_radius),
            (center + globe_radius, center + globe_radius),
        ],
        fill=globe_color,
    )

    # Draw simplified continents as curved shapes
    # Americas (left side)
    americas_points = [
        (center - globe_radius * 0.3, center - globe_radius * 0.6),
        (center - globe_radius * 0.5, center - globe_radius * 0.2),
        (center - globe_radius * 0.4, center + globe_radius * 0.1),
        (center - globe_radius * 0.5, center + globe_radius * 0.5),
        (center - globe_radius * 0.3, center + globe_radius * 0.7),
        (center - globe_radius * 0.1, center + globe_radius * 0.4),
        (center - globe_radius * 0.2, center + globe_radius * 0.1),
        (center - globe_radius * 0.1, center - globe_radius * 0.3),
    ]
    draw.polygon(americas_points, fill=land_color)

    # Europe/Africa (right side)
    eurasia_points = [
        (center + globe_radius * 0.1, center - globe_radius * 0.5),
        (center + globe_radius * 0.4, center - globe_radius * 0.3),
        (center + globe_radius * 0.3, center),
        (center + globe_radius * 0.4, center + globe_radius * 0.4),
        (center + globe_radius * 0.2, center + globe_radius * 0.6),
        (center, center + globe_radius * 0.3),
        (center + globe_radius * 0.1, center),
    ]
    draw.polygon(eurasia_points, fill=land_color)

    # Draw "scratch" marks - diagonal lines representing visited places
    line_width = size // 40
    scratch_positions = [
        # Scratch over Americas
        (
            (center - globe_radius * 0.5, center - globe_radius * 0.1),
            (center - globe_radius * 0.2, center + globe_radius * 0.2),
        ),
        # Scratch over Europe
        (
            (center + globe_radius * 0.15, center - globe_radius * 0.35),
            (center + globe_radius * 0.35, center - globe_radius * 0.15),
        ),
        # Another scratch
        (
            (center + globe_radius * 0.1, center + globe_radius * 0.2),
            (center + globe_radius * 0.3, center + globe_radius * 0.45),
        ),
    ]

    for start, end in scratch_positions:
        # Draw scratch with tapered ends
        draw.line([start, end], fill=scratch_color, width=line_width)
        # Add small circles at ends for scratch effect
        circle_r = line_width // 2
        draw.ellipse(
            [
                (start[0] - circle_r, start[1] - circle_r),
                (start[0] + circle_r, start[1] + circle_r),
            ],
            fill=scratch_color,
        )
        draw.ellipse(
            [
                (end[0] - circle_r, end[1] - circle_r),
                (end[0] + circle_r, end[1] + circle_r),
            ],
            fill=scratch_color,
        )

    # Add subtle highlight to globe (top-left)
    highlight_radius = int(globe_radius * 0.15)
    highlight_center = (center - globe_radius * 0.5, center - globe_radius * 0.5)
    for i in range(highlight_radius, 0, -1):
        alpha = int(80 * (1 - i / highlight_radius))
        overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        overlay_draw.ellipse(
            [
                (highlight_center[0] - i, highlight_center[1] - i),
                (highlight_center[0] + i, highlight_center[1] + i),
            ],
            fill=(255, 255, 255, alpha),
        )
        img = Image.alpha_composite(img, overlay)

    # Add subtle shadow at bottom of globe
    draw = ImageDraw.Draw(img)

    return img


def main():
    """Generate and save the app icon."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    icon_dir = (
        project_root / "ios" / "Skratch" / "Assets.xcassets" / "AppIcon.appiconset"
    )

    # Create 1024x1024 icon
    icon = create_app_icon(1024)

    # Save as PNG
    icon_path = icon_dir / "AppIcon.png"
    icon.save(icon_path, "PNG")
    print(f"Saved app icon to: {icon_path}")

    # Update Contents.json to reference the icon
    contents_json = icon_dir / "Contents.json"
    contents = """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
    contents_json.write_text(contents)
    print("Updated Contents.json")

    print("\nApp icon generated successfully!")
    print("The icon features a globe with 'scratch' marks representing visited places.")


if __name__ == "__main__":
    main()
