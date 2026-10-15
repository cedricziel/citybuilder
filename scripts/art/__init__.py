"""Claude-authored sprite pipeline (capability `iso-art-kit`).

IsoKit (`Tools/IsoKit`) renders buildings and units; this package generates the SVG sprites
(terrain, transitions, icons), quantizes every raw render into the atlases, and checks fresh
renders against the committed atlases within a tolerance.
"""
