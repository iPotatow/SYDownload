#!/usr/bin/env python3
"""Generate a signed ZIP appcast without writing the private key to disk."""
from pathlib import Path
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)


def generate(release_dir: Path, version: str, repository: str) -> None:
    import re
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a semantic release version")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid GitHub repository")
    tools = list(Path(".build/artifacts").glob("*/*/bin/sign_update"))
    if len(tools) != 1:
        raise RuntimeError("Expected one resolved Sparkle sign_update tool")
    archive = release_dir / "SYDownload.zip"
    result = subprocess.run(
        [str(tools[0].resolve()), "--ed-key-file", "-", str(archive.resolve())],
        input=os.environ["SPARKLE_PRIVATE_ED_KEY"].strip() + "\n",
        text=True, capture_output=True, check=True,
    )
    # sign_update prints XML attributes (sparkle:edSignature and length).
    attributes = ET.fromstring(f'<enclosure xmlns:sparkle="{SPARKLE}" {result.stdout.strip()}/>').attrib
    if not attributes.get(f"{{{SPARKLE}}}edSignature"):
        raise RuntimeError("Sparkle did not produce an EdDSA signature")
    if int(attributes["length"]) != archive.stat().st_size:
        raise RuntimeError("Signature length does not match archive")
    rss = ET.Element("rss", version="2.0")
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "SYDownload updates"
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"SYDownload {version}"
    ET.SubElement(item, f"{{{SPARKLE}}}version").text = version
    ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = version
    ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = "15.0"
    ET.SubElement(item, "description").text = f"https://github.com/{repository}/releases/tag/v{version}"
    attributes.update(url=f"https://github.com/{repository}/releases/download/v{version}/SYDownload.zip", type="application/octet-stream")
    ET.SubElement(item, "enclosure", attributes)
    ET.indent(rss)
    ET.ElementTree(rss).write(release_dir / "appcast.xml", encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    generate(Path(sys.argv[1]), sys.argv[2], sys.argv[3])
