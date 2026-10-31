"""Exercise the packaged container without loading weights or touching the GPU.

Run with HALOGEN_TEST_SETTINGS pointing at the built halogen-launcher.json.
"""

import argparse
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parents[2] / "nix/hosts/nixos/vermilion/halogen/_launcher.py"
spec = importlib.util.spec_from_file_location("launcher", SOURCE)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.cache = self.directory / "models"
        self.cache.mkdir()
        self.state = self.directory / "state"
        self.state.mkdir()
        self.model = self.cache / "model.gguf"
        self.model.write_text("fixture")
        self.settings = json.loads(Path(os.environ["HALOGEN_TEST_SETTINGS"]).read_text())
        self.settings.update(model_cache=str(self.cache), state_dir=str(self.state))
        self.arguments = argparse.Namespace(model=str(self.model), host="127.0.0.1", port=19876, ctx=262144)

    def command(self, code):
        command = launcher.build_command(self.settings, self.arguments)
        separator = command.index("--")
        return command[:separator + 1] + ["python3", "-c", code]

    def test_filesystem_environment_and_dependencies(self):
        code = f"""
import os
import transformers, fastapi, uvicorn
from pathlib import Path
assert os.environ['HALOGEN_KV_SLOTS'] == '2'
assert os.environ['HALOGEN_API_PORT'] == '19876'
assert os.environ['HALOGEN_BIND'] == '127.0.0.1'
assert Path(os.environ['HALOGEN_MTP_HEAD']).is_file()
assert Path(os.environ['HALOGEN_VISION_TOWER']).is_file()
from transformers import AutoTokenizer
AutoTokenizer.from_pretrained(os.environ['HALOGEN_TOKENIZER'], local_files_only=True)
assert '--host 0.0.0.0' not in Path('/usr/local/bin/entrypoint.sh').read_text()
try:
    Path('/models/model.gguf').write_text('must not write')
except OSError:
    pass
else:
    raise AssertionError('model mount is writable')
Path('/state/writable').write_text('ok')
"""
        subprocess.run(self.command(code), check=True, timeout=60)
        self.assertEqual(self.model.read_text(), "fixture")
        self.assertEqual((self.state / "writable").read_text(), "ok")

    def test_preserves_split_gguf_snapshot_filename(self):
        snapshot = self.cache / "snapshots"
        snapshot.mkdir()
        shard = snapshot / "model-00001-of-00003.gguf"
        shard.symlink_to(self.model)
        self.arguments.model = str(shard)
        command = launcher.build_command(self.settings, self.arguments)
        position = command.index("HALOGEN_CHECKPOINT")
        self.assertEqual(command[position + 1], "/models/snapshots/model-00001-of-00003.gguf")

    def test_rejects_external_model_and_public_bind(self):
        self.arguments.host = "0.0.0.0"
        with self.assertRaises(ValueError):
            launcher.build_command(self.settings, self.arguments)
        self.arguments.host = "127.0.0.1"
        outside = self.directory / "outside.gguf"
        outside.write_text("fixture")
        self.arguments.model = str(outside)
        with self.assertRaises(ValueError):
            launcher.build_command(self.settings, self.arguments)

    def test_unload_kills_uncooperative_child(self):
        lock_path = self.state / "lock"
        ready = self.state / "ready"
        code = f"""
import fcntl, signal, time
from pathlib import Path
signal.signal(signal.SIGTERM, signal.SIG_IGN)
lock = open('/state/lock', 'w')
fcntl.flock(lock, fcntl.LOCK_EX)
Path('/state/ready').touch()
time.sleep(60)
"""
        runner = f"""
import importlib.util
spec = importlib.util.spec_from_file_location('launcher', {str(SOURCE)!r})
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)
launcher.supervise({self.command(code)!r})
"""
        process = subprocess.Popen([sys.executable, "-c", runner])
        try:
            deadline = time.monotonic() + 10
            while not ready.exists() and time.monotonic() < deadline:
                if process.poll() is not None:
                    self.fail("container exited before acquiring its lock")
                time.sleep(0.05)
            self.assertTrue(ready.exists())
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=4.5)
            with lock_path.open() as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    unittest.main()
