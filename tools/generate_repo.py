#!/usr/bin/env python3
"""
Generates a minimal Cydia/APT repo around a single .deb:
  <out_dir>/Packages
  <out_dir>/Packages.bz2
  <out_dir>/Release
  <out_dir>/debs/<deb file>

Usage: generate_repo.py <control file> <deb file> <output dir>
"""
import sys
import os
import hashlib
import bz2
import shutil


def parse_control(path):
    """Parses a Debian-style control file into a dict, preserving continuation lines."""
    fields = {}
    last_key = None
    with open(path, "r") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            if line[0] in " \t" and last_key:
                fields[last_key] += "\n" + line
            else:
                key, _, value = line.partition(":")
                key = key.strip()
                value = value.strip()
                fields[key] = value
                last_key = key
    return fields


def hash_file(path, algo):
    h = hashlib.new(algo)
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    if len(sys.argv) != 4:
        print("usage: generate_repo.py <control file> <deb file> <output dir>")
        sys.exit(1)

    control_path, deb_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    fields = parse_control(control_path)

    debs_dir = os.path.join(out_dir, "debs")
    os.makedirs(debs_dir, exist_ok=True)

    deb_name = os.path.basename(deb_path)
    shutil.copy(deb_path, os.path.join(debs_dir, deb_name))

    size = os.path.getsize(deb_path)
    md5 = hash_file(deb_path, "md5")
    sha1 = hash_file(deb_path, "sha1")
    sha256 = hash_file(deb_path, "sha256")

    # Field order Cydia/APT expect; only emit ones that are actually present.
    field_order = ["Package", "Name", "Version", "Architecture", "Maintainer",
                   "Author", "Section", "Description", "Depends"]

    lines = [f"{key}: {fields[key]}" for key in field_order if key in fields]
    lines.append(f"Filename: debs/{deb_name}")
    lines.append(f"Size: {size}")
    lines.append(f"MD5sum: {md5}")
    lines.append(f"SHA1: {sha1}")
    lines.append(f"SHA256: {sha256}")
    lines.append("")  # blank line terminator (matters if more packages are added later)

    packages_text = "\n".join(lines) + "\n"

    with open(os.path.join(out_dir, "Packages"), "w") as f:
        f.write(packages_text)

    with open(os.path.join(out_dir, "Packages.bz2"), "wb") as f:
        f.write(bz2.compress(packages_text.encode("utf-8")))

    version = fields.get("Version", "1.0")
    release_text = (
        "Origin: LocalTunes Repo\n"
        "Label: LocalTunes\n"
        "Suite: stable\n"
        f"Version: {version}\n"
        "Codename: ios\n"
        "Architectures: iphoneos-arm\n"
        "Components: main\n"
        "Description: Personal Cydia repo for LocalTunes\n"
    )
    with open(os.path.join(out_dir, "Release"), "w") as f:
        f.write(release_text)

    print(f"Repo generated at {out_dir} ({deb_name}, {size} bytes)")


if __name__ == "__main__":
    main()
