import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path


def load_script(name):
    path = Path(__file__).resolve().parents[1] / name
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release = load_script('validate-ios-release.py')
simulator = load_script('select-ios-simulator.py')


class SimulatorSelectionTests(unittest.TestCase):
    def test_numeric_order_and_sdk_ceiling(self):
        devices = {
            'com.apple.CoreSimulator.SimRuntime.iOS-9-3': [self.device('old')],
            'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [self.device('supported')],
            'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [self.device('future')],
            'com.apple.CoreSimulator.SimRuntime.tvOS-26-2': [self.device('tv')],
        }
        self.assertEqual(simulator.select(devices, '26.2'), 'supported')

    @staticmethod
    def device(udid, available=True, name='iPhone 17'):
        return {'udid': udid, 'name': name, 'isAvailable': available}

    def test_unavailable_iphones_and_ipads_are_excluded(self):
        devices = {'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
            self.device('unavailable', False), self.device('ipad', name='iPad Pro'),
        ]}
        with self.assertRaisesRegex(ValueError, 'No available iPhone'):
            simulator.select(devices, '26.2')

    def test_patch_runtime_supported_by_matching_sdk(self):
        devices = {'com.apple.CoreSimulator.SimRuntime.iOS-26-4-1': [self.device('patch')]}
        self.assertEqual(simulator.select(devices, '26.4'), 'patch')


class ReleaseArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'LazyMansReminders.app'
        self.widget = self.app / 'PlugIns' / 'ReminderWidgetExtension.appex'
        for bundle in (self.app, self.widget):
            bundle.mkdir(parents=True, exist_ok=True)
            self.write_plist(bundle / 'Info.plist', {
                'CFBundleIdentifier': 'test.app' if bundle == self.app else 'test.app.widget',
                'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '7',
                'DTXcode': '2660', 'DTSDKName': 'iphoneos26.5',
                'DTXcodeBuild': '17F113', 'DTSDKBuild': 'test-sdk-build',
                'CFBundleIcons': {'CFBundlePrimaryIcon': {'CFBundleIconName': 'AppIcon'}},
            })
            self.write_plist(bundle / 'PrivacyInfo.xcprivacy', {'NSPrivacyTracking': False})
        (self.app / 'Assets.car').write_bytes(b'fixture')

    @staticmethod
    def write_plist(path, value):
        path.write_bytes(plistlib.dumps(value, fmt=plistlib.FMT_BINARY))

    def update_info(self, bundle, **values):
        path = bundle / 'Info.plist'
        info = plistlib.loads(path.read_bytes())
        info.update(values)
        self.write_plist(path, info)

    def test_records_app_and_widget_build_metadata(self):
        metadata = release.validate(self.app)
        self.assertEqual(metadata['app']['DTSDKName'], 'iphoneos26.5')
        self.assertEqual(metadata['widget']['DTXcodeBuild'], '17F113')

    def test_rejects_old_sdk_and_simulator_artifacts(self):
        for sdk in ('iphoneos18.5', 'iphonesimulator26.5', ''):
            with self.subTest(sdk=sdk):
                self.update_info(self.app, DTSDKName=sdk)
                with self.assertRaisesRegex(ValueError, 'device iOS SDK'):
                    release.validate(self.app)

    def test_rejects_old_xcode(self):
        self.update_info(self.widget, DTXcode='1640')
        with self.assertRaisesRegex(ValueError, 'Xcode >=26'):
            release.validate(self.app)

    def test_rejects_widget_version_mismatch(self):
        self.update_info(self.widget, CFBundleVersion='6')
        with self.assertRaisesRegex(ValueError, 'CFBundleVersion'):
            release.validate(self.app)

    def test_requires_embedded_widget_and_each_privacy_manifest(self):
        (self.widget / 'PrivacyInfo.xcprivacy').unlink()
        with self.assertRaises(FileNotFoundError):
            release.validate(self.app)
        self.write_plist(self.widget / 'PrivacyInfo.xcprivacy', {})
        (self.widget / 'Info.plist').unlink()
        with self.assertRaises(FileNotFoundError):
            release.validate(self.app)

    def test_requires_asset_catalog_and_primary_icon(self):
        (self.app / 'Assets.car').unlink()
        with self.assertRaisesRegex(ValueError, 'asset catalog'):
            release.validate(self.app)
        (self.app / 'Assets.car').write_bytes(b'fixture')
        self.update_info(self.app, CFBundleIcons={})
        with self.assertRaisesRegex(ValueError, 'primary icon'):
            release.validate(self.app)


if __name__ == '__main__':
    unittest.main()
