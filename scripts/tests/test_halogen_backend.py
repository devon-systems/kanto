"""Exercise native Lemonade routing against a stub, without loading a GPU model.

HALOGEN_TEST_LEMOND names the patched lemond executable.
"""

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

STUB = r'''
import argparse, http.server, json, os
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('-m')
parser.add_argument('--host')
parser.add_argument('--port', type=int)
parser.add_argument('-c')
args = parser.parse_args()
with open(os.environ['STUB_STARTS'], 'a') as log:
    log.write(json.dumps({'pid': os.getpid(), 'model': args.m, 'ctx': args.c}) + '\n')
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"data":[],"status":"ok"}')
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        Path(os.environ['STUB_REQUEST']).write_text(json.dumps(request))
        self.send_response(200)
        if request.get('stream'):
            self.send_header('Content-Type', 'text/event-stream')
            self.end_headers()
            event = {'id':'fixture','object':'chat.completion.chunk','choices':[{'index':0,'delta':{'content':'ok'},'finish_reason':None}]}
            self.wfile.write(('data: '+json.dumps(event)+'\n\ndata: [DONE]\n\n').encode())
        else:
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'id':'fixture','object':'chat.completion','choices':[{'index':0,'message':{'role':'assistant','content':'ok'},'finish_reason':'stop'}]}).encode())
http.server.ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()
'''


class BackendTests(unittest.TestCase):
    def test_alias_reuses_process_and_preserves_request_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config/lemonade"
            cache = root / "cache"
            config.mkdir(parents=True)
            cache.mkdir()
            model = root / "fixture.gguf"
            model.write_bytes(b"GGUF" + bytes(1024))
            stub = root / "stub"
            stub.write_text(f"#!{sys.executable}\n" + STUB)
            stub.chmod(0o755)
            (config / "config.json").write_text(json.dumps({
                "halogen": {"rocm_bin": str(stub)},
                "max_loaded_models": 1, "disable_model_filtering": True,
                "global_timeout": 30, "auto_update_models": False,
                "auto_check_model_updates": False, "telemetry": {"enabled": False},
            }))
            target = "Qwen3.8-Flash-Next-Halogen"
            legacy = "Qwen3.8-Flash-Next-Strata"
            (config / "user_models.json").write_text(json.dumps({target: {
                "checkpoint": str(model), "source": "local_path", "recipe": "halogen",
                "labels": ["chat", "reasoning", "tool-calling"], "recipe_options": {"ctx_size": 262144},
            }}))
            (cache / "aliases.json").write_text(json.dumps({legacy: target}))
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            environment = dict(os.environ, HOME=str(root), XDG_CONFIG_HOME=str(root / "config"),
                               LEMONADE_CACHE_DIR=str(cache), STUB_STARTS=str(root / "starts"),
                               STUB_REQUEST=str(root / "request"))
            def request(route, body=None):
                data = None if body is None else json.dumps(body).encode()
                req = urllib.request.Request(f"http://127.0.0.1:{port}/api/v1/{route}", data=data,
                                             headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=40) as response:
                    return response.read()
            with (root / "server.log").open("w+") as log:
                process = subprocess.Popen([os.environ["HALOGEN_TEST_LEMOND"], "--host", "127.0.0.1", "--port", str(port)], env=environment, stdout=log, stderr=log)
                try:
                    deadline = time.monotonic() + 45
                    while True:
                        try:
                            models = json.loads(request("models"))
                            break
                        except (urllib.error.URLError, ConnectionError):
                            if process.poll() is not None or time.monotonic() > deadline:
                                self.fail("Lemonade failed to become ready")
                            time.sleep(0.1)
                    self.assertIn(legacy, [item['id'] for item in models['data']])
                    payload = {"model": legacy, "messages": [{"role": "user", "content": "hello"}],
                               "reasoning_effort": "xhigh", "tools": [{"type": "function", "function": {"name": "read_file", "parameters": {"type": "object"}}}]}
                    response = json.loads(request("chat/completions", payload))
                    self.assertEqual(response['choices'][0]['message']['content'], "ok")
                    forwarded = json.loads((root / "request").read_text())
                    self.assertEqual(forwarded['reasoning_effort'], "xhigh")
                    self.assertEqual(forwarded['tools'], payload['tools'])
                    payload.update(model=target, stream=True)
                    self.assertIn(b"[DONE]", request("chat/completions", payload))
                    starts = (root / "starts").read_text().splitlines()
                    self.assertEqual(len(starts), 1, "alias and canonical ID must share a process")
                    child_pid = json.loads(starts[0])['pid']
                    request("unload", {"model_name": target})
                    self.assertFalse(Path(f"/proc/{child_pid}").exists(), "unload left the backend running")
                except Exception:
                    log.flush()
                    log.seek(0)
                    print(log.read()[-12000:], file=sys.stderr)
                    raise
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


if __name__ == "__main__":
    unittest.main()
