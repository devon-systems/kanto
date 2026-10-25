# Use Kanto models

Open WebUI serves browser chat and authenticated inference at
`https://openwebui.narwhal-snapper.ts.net`. Connect Tailscale before using
either interface. Morgan must accept the ingress node share first.

## Create application accounts

Sign in with the administrator identity and bootstrap password from
`k8s/secrets/open-webui.sops.yaml`. Create Morgan's WebUI account as a regular
user in the administration interface. Linux and WebUI accounts are separate.
Keep signup disabled.

Give regular users the API-key permission if they need agent access.
Each WebUI account currently has one API key. Replacing that key invalidates
the previous key in every client using it. The initial configuration enables
API keys and allows model listing and chat completions. Native Ollama routes,
model management, embeddings, and Responses are excluded from the API-key
allowlist.

## Load and test a model

No models are preloaded. Choose a model and quantization after testing the
actual hardware. From Vermilion, download a model with `ollama pull <model>`.
The host uses `/var/lib/ollama/models` for model storage.

Test a single chat before running both users' agents. Then test two concurrent
64K sessions, tool calls, time to first token, and memory pressure. Hermes
currently requires at least 64K context. A model must also support tool calling
and the runtime must format those calls correctly.

Vulkan is the initial backend. Compare it with `pkgs.ollama-rocm` using the same
model, context, and parallelism. Record the working kernel, firmware, runtime,
model revision, and GPU memory configuration before making the host permanent.

## Connect Hermes

Run `hermes model` and choose the custom endpoint provider. Set:

| Setting  | Value                                          |
| -------- | ---------------------------------------------- |
| Base URL | `https://openwebui.narwhal-snapper.ts.net/api` |
| API key  | Your personal Open WebUI key                   |
| Model    | The exact model ID listed by Open WebUI        |

The client appends `/chat/completions` to the base URL. The WebUI route is
`/api/chat/completions`, so do not append `/v1` to this base URL.

Test streaming and a complete tool-calling task before relying on this route.
This repository has not run a real Hermes session against Vermilion yet.

## Connect other clients

Use clients that support a custom OpenAI-compatible Chat Completions base URL.
Set that URL to `https://openwebui.narwhal-snapper.ts.net/api`, select the
model ID from `/api/models`, and supply your WebUI API key as a bearer token.
The intended inference endpoint is `/api/chat/completions`.

Clients requiring the Responses API or a native Ollama endpoint are outside
the initial configuration. An OpenAI-compatible label does not guarantee every
client or tool schema works.

Read the [Open WebUI API reference](https://docs.openwebui.com/reference/api-endpoints/)
and [Hermes provider guide](https://hermes-agent.nousresearch.com/docs/integrations/providers)
when configuring clients. Keep raw Ollama access internal. API consumers use
WebUI authentication and its shared standalone ingress node.

## Use ComfyUI

ComfyUI runs on Vermilion with ROCm at
`https://comfyui.narwhal-snapper.ts.net`. Share its standalone ingress node
with Morgan separately. Tailscale access grants access to the shared workspace,
uploads, outputs, and job queue; there is no separate application login.

State lives in `/var/lib/comfyui`. Backups exclude downloaded models and
temporary files. No models or custom nodes are preconfigured. ComfyUI and
Ollama share GPU memory; unload large Ollama models before memory-heavy image
jobs. GPU inference still needs validation on the actual hardware.
