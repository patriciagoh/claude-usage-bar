#!/usr/bin/env python3
"""Update appcast.xml for a new release.

Usage: update-appcast.py <version> <dmg_size_bytes> <ed_signature>
"""
import sys

if len(sys.argv) != 4:
    print(f"Usage: {sys.argv[0]} <version> <dmg_path> <signature>", file=sys.stderr)
    sys.exit(1)

version = sys.argv[1]
size    = sys.argv[2]
sig     = sys.argv[3]

url = (
    f"https://github.com/patriciagoh/claude-usage-bar/releases/download"
    f"/v{version}/ClaudeUsageBar-{version}.dmg"
)

xml = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ClaudeUsageBar</title>
    <item>
      <title>Version {version}</title>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="{url}"
        sparkle:edSignature="{sig}"
        length="{size}"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
"""

with open("appcast.xml", "w") as f:
    f.write(xml)

print(f"Updated appcast.xml for v{version}")
