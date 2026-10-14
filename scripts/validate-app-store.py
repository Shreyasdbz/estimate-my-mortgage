#!/usr/bin/env python3
"""Check local submission inputs; this does not validate signing, an account or Apple acceptance."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import sys
from urllib.parse import urlparse
import zlib

ROOT = Path(__file__).resolve().parent.parent
SIZES = {'iPhone': [1206, 2622], 'iPad': [2064, 2752]}


def require(condition, message):
    """Reject an invalid local input with an actionable error."""
    if not condition:
        raise ValueError(message)


def check_metadata(data):
    """Validate copy lengths and required HTTPS URLs without a network request."""
    require(isinstance(data, dict), 'Metadata must be a JSON object')
    for key, limit in [('name', 30), ('subtitle', 30), ('description', 4000), ('whatsNew', 4000), ('keywords', 100)]:
        value = data.get(key)
        require(isinstance(value, str) and value.strip(), f'{key}: enter nonempty text')
        length = len(value.encode('utf-8')) if key == 'keywords' else len(value)
        require(length <= limit, f'{key}: exceeds {limit} ' + ('UTF-8 bytes' if key == 'keywords' else 'characters'))
    for key in ['privacyPolicyURL', 'supportURL']:
        value = data.get(key)
        require(isinstance(value, str), f'{key}: enter a public HTTPS URL')
        url = urlparse(value)
        require(url.scheme == 'https' and url.hostname and not url.username and not any(c.isspace() for c in value), f'{key}: enter a public HTTPS URL')
    for key in ['bundleIdentifier', 'version', 'build']:
        require(isinstance(data.get(key), str) and data[key].strip(), f'{key}: enter the archive identity')


def check_png(data):
    """Validate bounded, noninterlaced opaque PNG pixels, chunks and CRCs; return dimensions."""
    require(data[:8] == b'\x89PNG\r\n\x1a\n', 'Screenshot is not a PNG')
    offset, kinds, compressed, dimensions, depth, color = 8, [], bytearray(), None, 0, 0
    while offset < len(data):
        require(offset + 12 <= len(data), 'Truncated PNG chunk')
        length, kind = struct.unpack('>I4s', data[offset:offset + 8])
        end = offset + 12 + length
        require(end <= len(data), 'PNG chunk exceeds file bounds')
        payload = data[offset + 8:end - 4]
        require(all(65 <= c <= 90 or 97 <= c <= 122 for c in kind) and 65 <= kind[2] <= 90, 'Invalid PNG chunk type')
        require(zlib.crc32(kind + payload) & 0xffffffff == struct.unpack('>I', data[end - 4:end])[0], 'PNG CRC mismatch')
        require(kind != b'tRNS', 'Screenshot has PNG transparency')
        require(kind in [b'IHDR', b'PLTE', b'IDAT', b'IEND'] or kind[0] >= 97, 'Unknown critical PNG chunk')
        if not kinds:
            require(kind == b'IHDR' and length == 13, 'PNG must begin with one IHDR')
            w, h, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            require(w > 0 and h > 0 and w <= 2752 and h <= 2752, 'PNG dimensions exceed screenshot bounds')
            require(color not in [4, 6], 'Screenshot has an alpha channel')
            require(color in [0, 2, 3] and depth in ({0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8]}[color]), 'Unsupported PNG color/depth')
            require(compression == filtering == interlace == 0, 'Use a standard noninterlaced PNG screenshot')
            dimensions = [w, h]
        elif kind == b'IHDR':
            raise ValueError('Duplicate PNG IHDR')
        if kind == b'PLTE':
            require(b'PLTE' not in kinds and b'IDAT' not in kinds and color != 0 and length % 3 == 0 and 0 < length <= 768, 'Invalid PNG palette')
            require(color != 3 or length // 3 <= 2 ** depth, 'PNG palette exceeds bit depth')
        if kind == b'IDAT':
            require(b'IDAT' not in kinds or kinds[-1] == b'IDAT', 'PNG IDAT chunks must be consecutive')
            compressed.extend(payload)
        if kind == b'IEND':
            require(length == 0 and end == len(data) and b'IDAT' in kinds, 'Invalid PNG end or missing pixels')
        kinds.append(kind)
        offset = end
    require(kinds and kinds[-1] == b'IEND' and (color != 3 or b'PLTE' in kinds), 'Incomplete PNG')
    channels = 3 if color == 2 else 1
    stride = (dimensions[0] * channels * depth + 7) // 8
    expected = dimensions[1] * (stride + 1)
    decoder = zlib.decompressobj()
    pixels = decoder.decompress(bytes(compressed), expected + 1)
    require(len(pixels) == expected and decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail, 'Invalid PNG pixel stream or size')
    require(all(pixels[row * (stride + 1)] <= 4 for row in range(dimensions[1])), 'Invalid PNG row filter')
    return dimensions


def check_screenshots(root, manifest):
    """Require both portrait device families, unique ordered images, native sizes and matching hashes."""
    require(isinstance(manifest, dict), 'Screenshot manifest must be a JSON object')
    rows = manifest.get('screenshots')
    require(isinstance(rows, list) and rows, 'screenshots: select images for both device families')
    orders, files = {family: set() for family in SIZES}, set()
    for row in rows:
        require(isinstance(row, dict), 'Screenshot entry must be a JSON object')
        family, order, name = row.get('device'), row.get('order'), row.get('file')
        require(family in SIZES and type(order) is int and 1 <= order <= 10, 'Screenshot device/order must be iPhone/iPad and 1..10')
        require(order not in orders[family] and isinstance(name, str) and name not in files, 'Duplicate screenshot order or file')
        relative = Path(name)
        prefixes = [('docs', 'media'), ('docs', 'app-store', 'screenshots')]
        require(not relative.is_absolute() and '..' not in relative.parts and any(relative.parts[:len(prefix)] == prefix for prefix in prefixes) and relative.suffix == '.png', 'Screenshot must be a docs/media or docs/app-store/screenshots PNG')
        path = (root / relative).resolve()
        require(any(path.is_relative_to(root.resolve().joinpath(*prefix)) for prefix in prefixes), 'Screenshot resolves outside the permitted folders')
        data = path.read_bytes()
        require(hashlib.sha256(data).hexdigest() == row.get('sha256'), f'{name}: SHA-256 mismatch')
        require(check_png(data) == row.get('dimensions') == SIZES[family], f'{name}: incorrect native dimensions')
        orders[family].add(order); files.add(name)
    require(all(values and values == set(range(1, len(values) + 1)) for values in orders.values()), 'Select screenshots starting at order 1 for both devices')
    return len(rows)


def macho(data):
    """Read an arm64 Mach-O UUID and build platform without native tools or executing the binary."""
    require(len(data) >= 32 and data[:4] == b'\xcf\xfa\xed\xfe', 'Expected a thin arm64 Mach-O binary')
    _, cpu, _, _, commands, size, _, _ = struct.unpack('<8I', data[:32])
    require(cpu == 0x0100000c and 32 + size <= len(data), 'Invalid arm64 Mach-O header')
    offset, identifier, platform, minimum = 32, None, None, None
    for _ in range(commands):
        require(offset + 8 <= 32 + size, 'Truncated Mach-O load command')
        cmd, length = struct.unpack('<II', data[offset:offset + 8])
        require(length >= 8 and offset + length <= 32 + size, 'Mach-O load command out of bounds')
        if cmd == 0x1b:
            require(length == 24 and identifier is None, 'Invalid Mach-O UUID command')
            identifier = data[offset + 8:offset + 24].hex()
        if cmd == 0x32:
            require(length >= 24, 'Invalid Mach-O build version')
            platform, minimum = struct.unpack('<II', data[offset + 8:offset + 16])
        offset += length
    require(offset == 32 + size and identifier, 'Missing Mach-O UUID or malformed commands')
    return identifier, platform, minimum


def check_archive(archive, metadata):
    """Inspect app identity, packaged privacy and matching symbols; signing remains unverified."""
    app = archive / 'Products/Applications/EstimateMyMortgage.app'
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    require(isinstance(info, dict), 'Archive Info.plist must be a dictionary')
    for key, field in [('CFBundleIdentifier', 'bundleIdentifier'), ('CFBundleShortVersionString', 'version'), ('CFBundleVersion', 'build')]:
        require(info.get(key) == metadata[field], f'Archive {key} does not match metadata {field}')
    require(info.get('DTPlatformName') == 'iphoneos' and info.get('MinimumOSVersion') == '17.0', 'Archive must target iPhoneOS with iOS 17.0 minimum')
    require(info.get('ITSAppUsesNonExemptEncryption') is False, 'Archive encryption declaration must be literal Boolean false')
    privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
    require(isinstance(privacy, dict), 'Packaged privacy manifest must be a dictionary')
    require(privacy.get('NSPrivacyTracking') is False and privacy.get('NSPrivacyCollectedDataTypes') == [], 'Packaged privacy does not match no-data-collected recommendation')
    executable = info.get('CFBundleExecutable')
    require(isinstance(executable, str) and Path(executable).name == executable and executable not in ['', '.', '..'], 'Invalid archive executable name')
    app_uuid, platform, minimum = macho((app / executable).read_bytes())
    require(platform == 2, 'Archive binary must target iOS devices, not Simulator')
    require(minimum == 17 << 16, 'Archive binary minimum OS must match iOS 17.0')
    symbols = archive / 'dSYMs/EstimateMyMortgage.app.dSYM/Contents/Resources/DWARF' / executable
    require(macho(symbols.read_bytes())[0] == app_uuid, 'Archive dSYM UUID does not match app')
    return 'signing files present; signature/uploadability unverified' if (app / '_CodeSignature').exists() else 'unsigned QA archive; not uploadable'


def main():
    """Return a failed local check as exit 1; never submit or contact external services."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    try:
        metadata = json.loads((args.root / 'docs/app-store/metadata.json').read_text())
        check_metadata(metadata)
        count = check_screenshots(args.root, json.loads((args.root / 'docs/app-store/screenshots.json').read_text()))
        archive = check_archive(args.archive, metadata) if args.archive else 'not inspected'
    except (ValueError, OSError, KeyError, TypeError, struct.error, zlib.error, plistlib.InvalidFileException) as error:
        print(f'App Store local check failed: {error}', file=sys.stderr)
        return 1
    print(f'Local copy and {count} screenshots passed; archive: {archive}. No Apple server, account or signing validation performed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
