"""Build and test the Halogen integration locally without loading model weights."""

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def main():
    output = subprocess.check_output([
        "nix", "build", "--no-link", "--print-out-paths", "--max-jobs", "2", "--cores", "4",
        ".#nixosConfigurations.vermilion.config.system.build.halogenIntegration",
    ], cwd=ROOT, text=True).strip()
    integration = Path(output)
    environment = dict(os.environ,
                       HALOGEN_TEST_SETTINGS=str(integration / "settings.json"),
                       HALOGEN_TEST_RECONCILE=str(integration / "reconcile/bin/halogen-reconcile-alias"),
                       HALOGEN_TEST_LEMOND=str(integration / "lemonade/bin/lemond"))
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "scripts/tests",
                    "-p", "test_halogen_*.py", "-v"], cwd=ROOT, env=environment, check=True)


if __name__ == "__main__":
    main()
