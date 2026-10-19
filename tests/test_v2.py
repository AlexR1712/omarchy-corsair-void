"""Hardware-free regression checks for the HeadsetControl adapter."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / 'bin/corsair-void-v2'


class WirelessV2Tests(unittest.TestCase):
    def status(self, result=None, error=None, installed=True):
        with tempfile.TemporaryDirectory() as state:
            with patch.dict('os.environ', {'XDG_STATE_HOME': state}):
                module = runpy.run_path(str(HELPER))
            output = io.StringIO()
            with patch('sys.argv', [str(HELPER), 'status']), patch('shutil.which', return_value='headsetcontrol' if installed else None), patch('subprocess.run', return_value=result, side_effect=error), contextlib.redirect_stdout(output):
                self.assertEqual(module['main'](), 0)
            return dict(line.split('=', 1) for line in output.getvalue().splitlines())

    def test_battery(self):
        device = {'status': 'success', 'id_product': '0x2a08', 'capabilities': ['CAP_SIDETONE'], 'battery': {'status': 'BATTERY_AVAILABLE', 'level': 54}}
        result = subprocess.CompletedProcess([], 0, json.dumps({'devices': [device]}))
        data = self.status(result)
        self.assertEqual(data['capacity'], '54')
        self.assertEqual(data['wireless_status'], 'connected')
        self.assertEqual(data['alert_supported'], '0')

    def test_failed_queries_clear_battery(self):
        for result in [subprocess.CompletedProcess([], 1, ''), subprocess.CompletedProcess([], 0, 'invalid json')]:
            with self.subTest(result=result):
                self.assertEqual(self.status(result)['capacity'], '-1')
        self.assertEqual(self.status(error=subprocess.TimeoutExpired('headsetcontrol', 12))['capacity'], '-1')

    def test_missing_dependency(self):
        data = self.status(installed=False)
        self.assertEqual(data['sidetone_writable'], '0')
        self.assertIn('Install headsetcontrol', data['backend_error'])


if __name__ == '__main__':
    unittest.main()
