# Planify brand assets

The supplied brand board is the visual reference. The path/time-block P is
recreated as scalable vector geometry in planify-symbol.svg and in the matching
Flutter PlanifyMark painter. This is a vector recreation, not an original
production logo file extracted from the reference.

Palette: navy #051B47, blue #3B82F6, teal #00D1B2, violet #8B5CF6,
off-white #FAF9F6. The blue/teal/violet gradient is reserved for brand graphics.
Interactive text and primary buttons use contrast-safe navy/light-blue variants.

Typography: bundled Manrope for display and headings; bundled Inter for body and
controls. Font files and OFL licenses come from the official Google Fonts repo.
Tagline: “Plan your day. Make room for life.”

Platform icons are generated from the SVG, with a navy background and a padded
symbol. To regenerate, install sharp in your tooling environment and run
`node tools/render-brand.cjs`; optionally pass an absolute sharp package path.

Official font sources:
- https://github.com/google/fonts/tree/main/ofl/manrope
- https://github.com/google/fonts/tree/main/ofl/inter
