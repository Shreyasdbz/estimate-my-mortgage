"""Local submission-integrity checks using synthetic images and archives; no native or network calls."""
import copy
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zlib

SPEC = importlib.util.spec_from_file_location('app_store', Path(__file__).with_name('validate-app-store.py'))
store = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(store)


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def png(width, height, color=2, extra=b'', pixels=None):
    header = struct.pack('>IIBBBBB', width, height, 8, color, 0, 0, 0)
    if pixels is None:
        channels = 4 if color == 6 else 3
        pixels = (b'\0' + bytes(width * channels)) * height
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + extra + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')


def binary(identifier, platform=2, minimum=17):
    uuid = struct.pack('<II', 0x1b, 24) + identifier
    build = struct.pack('<6I', 0x32, 24, platform, minimum << 16, 27 << 16, 0)
    return struct.pack('<8I', 0xfeedfacf, 0x0100000c, 0, 2, 2, 48, 0, 0) + uuid + build


class AppStoreValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.images = {family: png(*size) for family, size in store.SIZES.items()}

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='emm-app-store-check-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.metadata = {'name': 'Estimate My Mortgage', 'subtitle': 'Compare home loan payments', 'description': 'Fixed-rate planning in USD.', 'whatsNew': 'Native editing.', 'keywords': 'home,loan', 'privacyPolicyURL': 'https://example.org/privacy', 'supportURL': 'https://example.org/support', 'bundleIdentifier': 'shreyassane.EstimateMyMortgage', 'version': '2.0', 'build': '2'}
        self.rows = []
        (self.root / 'docs/media').mkdir(parents=True)
        for family, data in self.images.items():
            name = f'docs/media/{family}.png'
            (self.root / name).write_bytes(data)
            self.rows.append({'file': name, 'device': family, 'dimensions': store.SIZES[family], 'sha256': hashlib.sha256(data).hexdigest(), 'order': 1})
        self.archive = self.root / 'QA.xcarchive'
        self.app = self.archive / 'Products/Applications/EstimateMyMortgage.app'
        self.app.mkdir(parents=True)
        self.info = {'CFBundleIdentifier': self.metadata['bundleIdentifier'], 'CFBundleShortVersionString': '2.0', 'CFBundleVersion': '2', 'CFBundleExecutable': 'EstimateMyMortgage', 'DTPlatformName': 'iphoneos', 'MinimumOSVersion': '17.0', 'ITSAppUsesNonExemptEncryption': False}
        self.write_info()
        (self.app / 'PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({'NSPrivacyTracking': False, 'NSPrivacyCollectedDataTypes': []}))
        self.uuid = bytes(range(16))
        (self.app / 'EstimateMyMortgage').write_bytes(binary(self.uuid))
        self.symbols = self.archive / 'dSYMs/EstimateMyMortgage.app.dSYM/Contents/Resources/DWARF/EstimateMyMortgage'
        self.symbols.parent.mkdir(parents=True)
        self.symbols.write_bytes(binary(self.uuid))

    def write_info(self):
        (self.app / 'Info.plist').write_bytes(plistlib.dumps(self.info))

    def test_valid_copy_images_and_unsigned_archive(self):
        store.check_metadata(self.metadata)
        self.assertEqual(store.check_screenshots(self.root, {'screenshots': self.rows}), 2)
        self.assertEqual(store.check_archive(self.archive, self.metadata), 'unsigned QA archive; not uploadable')

    def test_copy_limits_and_multibyte_keywords(self):
        for key, value in [('name', 'a' * 31), ('subtitle', 'a' * 31), ('description', 'a' * 4001), ('whatsNew', 'a' * 4001), ('keywords', 'é' * 51)]:
            with self.subTest(key=key):
                data = copy.deepcopy(self.metadata); data[key] = value
                with self.assertRaisesRegex(ValueError, key): store.check_metadata(data)

    def test_missing_or_non_https_policy_and_support(self):
        for key in ['privacyPolicyURL', 'supportURL']:
            for value in [None, '', 'http://example.org', 'https://user@example.org', 'https://example.org/a b']:
                with self.subTest(key=key, value=value):
                    data = copy.deepcopy(self.metadata); data[key] = value
                    with self.assertRaisesRegex(ValueError, key): store.check_metadata(data)

    def test_corrupt_crc_truncation_and_extra_bytes(self):
        data = self.images['iPhone']
        bad_crc = bytearray(data); bad_crc[29] ^= 1
        for malformed in [bytes(bad_crc), data[:-3], data + b'junk']:
            with self.assertRaises(ValueError): store.check_png(malformed)

    def test_alpha_and_transparency_rejected(self):
        for data in [png(1, 1, color=6), png(1, 1, extra=chunk(b'tRNS', bytes(6)))]:
            with self.assertRaisesRegex(ValueError, 'alpha|transparency'): store.check_png(data)

    def test_pixel_stream_and_filter_validated(self):
        for pixels in [b'\0', b'\5\0\0\0']:
            with self.assertRaisesRegex(ValueError, 'pixel|filter'): store.check_png(png(1, 1, pixels=pixels))

    def test_wrong_hash_size_duplicate_and_path(self):
        for key, value in [('sha256', '0' * 64), ('dimensions', [1, 1]), ('order', True), ('file', '../outside.png')]:
            with self.subTest(key=key):
                rows = copy.deepcopy(self.rows); rows[0][key] = value
                with self.assertRaises(ValueError): store.check_screenshots(self.root, {'screenshots': rows})
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            store.check_screenshots(self.root, {'screenshots': self.rows + [self.rows[0]]})
        with self.assertRaisesRegex(ValueError, 'both devices'):
            store.check_screenshots(self.root, {'screenshots': self.rows[:1]})

    def screenshot_rows(self, count, folder='docs/media'):
        rows = []
        for family, data in self.images.items():
            for order in range(1, count + 1):
                name = f'{folder}/{family}/screen-{order}.png'
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
                rows.append({'file': name, 'device': family, 'dimensions': store.SIZES[family], 'sha256': hashlib.sha256(data).hexdigest(), 'order': order})
        return rows

    def test_three_and_four_screenshots_per_family_accepted(self):
        for count in [3, 4]:
            with self.subTest(count=count):
                rows = self.screenshot_rows(count)
                self.assertEqual(store.check_screenshots(self.root, {'screenshots': rows}), count * 2)

    def test_order_limit_repetition_and_gap_rejected(self):
        for orders in [[1, 2, 3, 11], [1, 2, 2, 4], [1, 2, 4, 5]]:
            with self.subTest(orders=orders):
                rows = self.screenshot_rows(4)
                for row, order in zip(rows[:4], orders):
                    row['order'] = order
                with self.assertRaises(ValueError):
                    store.check_screenshots(self.root, {'screenshots': rows})

    def test_nested_store_folder_allowed_but_traversal_and_escape_rejected(self):
        rows = self.screenshot_rows(4, 'docs/app-store/screenshots')
        self.assertEqual(store.check_screenshots(self.root, {'screenshots': rows}), 8)
        for name in ['docs/app-store/screenshots/../outside.png', 'docs/app-store/screenshots-other/image.png', 'docs/app-store/image.png']:
            with self.subTest(name=name):
                invalid = copy.deepcopy(rows); invalid[0]['file'] = name
                with self.assertRaises(ValueError):
                    store.check_screenshots(self.root, {'screenshots': invalid})
        with tempfile.TemporaryDirectory(prefix='emm-screenshot-escape-') as outside:
            targets = [Path(outside) / 'image.png', self.root / 'elsewhere.png']
            for target in targets:
                target.write_bytes(self.images['iPhone'])
                link = self.root / 'docs/app-store/screenshots/escape.png'
                link.symlink_to(target)
                invalid = copy.deepcopy(rows); invalid[0]['file'] = str(link.relative_to(self.root))
                with self.assertRaisesRegex(ValueError, 'outside the permitted'):
                    store.check_screenshots(self.root, {'screenshots': invalid})
                link.unlink()

    def test_mismatched_archive_identity_and_platform(self):
        for key, value in [('CFBundleIdentifier', 'other.app'), ('CFBundleShortVersionString', '1.0'), ('CFBundleVersion', '1'), ('DTPlatformName', 'iphonesimulator'), ('MinimumOSVersion', '16.0'), ('ITSAppUsesNonExemptEncryption', 'NO')]:
            with self.subTest(key=key):
                original = self.info[key]; self.info[key] = value; self.write_info()
                with self.assertRaises(ValueError): store.check_archive(self.archive, self.metadata)
                self.info[key] = original; self.write_info()
        (self.app / 'EstimateMyMortgage').write_bytes(binary(self.uuid, platform=7))
        with self.assertRaisesRegex(ValueError, 'Simulator'): store.check_archive(self.archive, self.metadata)
        (self.app / 'EstimateMyMortgage').write_bytes(binary(self.uuid, minimum=18))
        with self.assertRaisesRegex(ValueError, 'minimum OS'): store.check_archive(self.archive, self.metadata)

    def test_missing_privacy_and_mismatched_symbols(self):
        self.symbols.write_bytes(binary(bytes(reversed(range(16)))))
        with self.assertRaisesRegex(ValueError, 'UUID'): store.check_archive(self.archive, self.metadata)
        (self.app / 'PrivacyInfo.xcprivacy').unlink()
        with self.assertRaises(OSError): store.check_archive(self.archive, self.metadata)


if __name__ == '__main__':
    unittest.main()
