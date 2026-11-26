"""Test the Halogen model and alias migration against temporary state."""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    output = subprocess.check_output(
        [
            "nix",
            "build",
            "--no-link",
            "--print-out-paths",
            "--max-jobs",
            "2",
            "--cores",
            "4",
            ".#nixosConfigurations.vermilion.config.system.build.halogenReconcile",
        ],
        cwd=ROOT,
        text=True,
    ).strip()
    integration = Path(output)
    environment = dict(
        os.environ,
        HALOGEN_TEST_RECONCILE=str(integration / "bin/halogen-reconcile-alias"),
    )
    subprocess.run(
        [
            sys.executable,
            "-m",
            "unittest",
            "discover",
            "-s",
            "scripts/tests",
            "-p",
            "test_halogen_alias.py",
            "-v",
        ],
        cwd=ROOT,
        env=environment,
        check=True,
    )


if __name__ == "__main__":
    main()
