"""Run Halogen's pinned OCI filesystem as a Lemonade-owned subprocess."""

import argparse
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys


def build_command(settings, arguments):
    # Keep the snapshot filename: split GGUF loading discovers sibling shards by
    # name. Resolving an HF symlink would replace that name with a blob hash.
    model = Path(arguments.model).absolute()
    cache = Path(settings["model_cache"]).resolve(strict=True)
    if not model.is_relative_to(cache) or not model.resolve(strict=True).is_relative_to(cache):
        raise ValueError(f"model must be inside {cache}")
    if arguments.host != "127.0.0.1":
        raise ValueError("Halogen must bind to loopback")
    if not 1 <= arguments.port <= 65535 or not 1 <= arguments.ctx <= 262144:
        raise ValueError("invalid port or context size")

    image = json.loads(Path(settings["rootfs"], "image-config.json").read_text())
    environment = dict(entry.split("=", 1) for entry in image.get("Env", []))
    environment.update(settings["environment"])
    # The engine and HTTP frontend need separate loopback ports.
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        engine_port = listener.getsockname()[1]
    environment.update({
        "HALOGEN_CHECKPOINT": "/models/" + str(model.relative_to(cache)),
        "HALOGEN_BIND": arguments.host,
        "HALOGEN_API_PORT": str(arguments.port),
        "HALOGEN_PORT": str(engine_port),
        "HALOGEN_CTX": str(arguments.ctx),
        "HOME": "/state",
    })
    command = [settings["bubblewrap"], "--die-with-parent", "--unshare-pid"]
    # Bind each image directory beneath bubblewrap's temporary root so it can
    # create mount points absent from the OCI image, such as /nix/store.
    for entry in sorted(Path(settings["rootfs"], "rootfs").iterdir()):
        target = "/" + entry.name
        if entry.is_symlink():
            command.extend(["--symlink", os.readlink(entry), target])
        else:
            command.extend(["--ro-bind", str(entry), target])
    command.extend([
        "--ro-bind", "/nix/store", "/nix/store",
        "--ro-bind", settings["entrypoint"], "/usr/local/bin/entrypoint.sh",
        "--ro-bind", str(cache), "/models",
        "--bind", settings["state_dir"], "/state",
        "--dev-bind", "/dev", "/dev",
        "--ro-bind", "/sys", "/sys", "--proc", "/proc",
        "--tmpfs", "/tmp", "--tmpfs", "/run", "--tmpfs", "/var/tmp",
        "--clearenv",
    ])
    for name, value in sorted(environment.items()):
        command.extend(["--setenv", name, value])
    command.extend(["--chdir", image.get("WorkingDir") or "/", "--"])
    command.extend(image.get("Entrypoint") or [])
    command.extend(image.get("Cmd") or [])
    return command


def supervise(command):
    # Lemonade allows five seconds before killing its wrapper. Stop the whole
    # process group within that window; the PID namespace also prevents orphans.
    child = subprocess.Popen(command, start_new_session=True)
    stopping = False

    def stop(_signal, _frame):
        nonlocal stopping
        if stopping:
            return
        stopping = True
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    return child.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--settings", required=True)
    parser.add_argument("-m", "--model", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("-c", "--ctx", type=int, default=262144)
    arguments = parser.parse_args()
    settings = json.loads(Path(arguments.settings).read_text())
    return supervise(build_command(settings, arguments))


if __name__ == "__main__":
    sys.exit(main())
