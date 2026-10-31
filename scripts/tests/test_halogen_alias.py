"""Test the built pre-start migration against temporary Lemonade state."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class AliasTests(unittest.TestCase):
    def test_migration_preserves_other_models_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config/lemonade"
            cache = root / "cache"
            config.mkdir(parents=True)
            cache.mkdir()
            models = config / "user_models.json"
            aliases = cache / "aliases.json"
            models.write_text(json.dumps({
                "Qwen3.8-Flash-Next-Strata": {"recipe": "strata"},
                "Qwen3.8-Flash-Next-Strata-Fallback": {"recipe": "strata"},
                "Qwen3.8-Flash-Next-Halogen": {"recipe": "halogen"},
                "roommate-model": {"recipe": "llamacpp"},
            }))
            aliases.write_text(json.dumps({"roommate": "roommate-model"}))
            models.chmod(0o600)
            aliases.chmod(0o600)
            environment = dict(os.environ, XDG_CONFIG_HOME=str(root / "config"), LEMONADE_CACHE_DIR=str(cache))
            for _ in range(2):
                subprocess.run([os.environ["HALOGEN_TEST_RECONCILE"]], env=environment, check=True)
                actual_models = json.loads(models.read_text())
                actual_aliases = json.loads(aliases.read_text())
                self.assertNotIn("Qwen3.8-Flash-Next-Strata", actual_models)
                self.assertEqual(len(actual_models), 3)
                self.assertEqual(actual_aliases["roommate"], "roommate-model")
                for name in ["Qwen3.8-Flash-Next-Strata", "user.Qwen3.8-Flash-Next-Strata"]:
                    self.assertEqual(actual_aliases[name], "Qwen3.8-Flash-Next-Halogen")
                self.assertEqual(models.stat().st_mode & 0o777, 0o600)
                self.assertEqual(aliases.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
