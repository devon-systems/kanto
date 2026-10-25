# Use Kanto models

Connect Tailscale before opening Kanto services or using the API. Users on
another tailnet must accept the relevant service-node share first.

| Service              | Address                                        | Authentication               |
| -------------------- | ---------------------------------------------- | ---------------------------- |
| Open WebUI           | `https://openwebui.narwhal-snapper.ts.net`     | Personal WebUI account       |
| Chat Completions API | `https://openwebui.narwhal-snapper.ts.net/api` | Personal WebUI API key       |
| ComfyUI              | `https://comfyui.narwhal-snapper.ts.net`       | Access to its Tailscale node |
| Open Terminal        | Select **Kanto workspace** in WebUI            | WebUI account                |

## Sign in and create an API key

Use your WebUI account for chat. Linux login credentials are separate. An
administrator provisions accounts and grants API-key access as described in
[cluster operations](kubernetes.md#configure-accounts-and-secrets).

Create an API key in WebUI's account settings. Keep the key in your client's
secret store. The API-key allowlist permits `/api/models` and
`/api/chat/completions`; it does not expose native Ollama routes, model
management, embeddings, or the Responses API.

## Connect clients

Choose an OpenAI-compatible **Chat Completions** provider and use the API base
URL in the table above. The client appends `/chat/completions`; do not append
`/v1` to the base URL. Supply the WebUI key as the bearer credential and select
an exact model ID from `/api/models`.

Hoenn configures a `kanto` provider for both OpenCode and Hermes, using its
SOPS-managed WebUI key. In OpenCode, select Kanto through `/models`. In Hermes,
select a model with `/model custom:kanto:<model-id>`.

On other machines, use `hermes model` and choose a custom endpoint, or add an
OpenAI-compatible provider to OpenCode. Use the same base URL, personal key,
and model ID. Configure the client's context limit to match the backend's
configured capacity. A model must support tool calling for agent tasks; test
streaming and a complete tool call when adding a new model or client.

## Discover and manage models

The WebUI model picker combines Ollama and Lemonade models. API clients can
list the models available to their account through `/api/models`.

Ollama runs with Vulkan. Download or inspect its models on Vermilion:

```sh
ollama pull <model>
ollama list
ollama ps
```

Ollama stores downloads in `/var/lib/ollama/models`. These downloads are runtime
state, not a declarative model inventory in this repository.

Lemonade manages Strata through the `nix-amd-ai` module. Its preparation service
provisions the configured model assets. Model selection, quantization, and
cache settings live in `nix/hosts/nixos/vermilion/lemonade.nix`; Lemonade's model
cache is under `/var/lib/lemonade/models`.

Ollama, Lemonade, and ComfyUI share the host's memory and GPU. Their independent
model limits do not coordinate memory use across services. Unload an idle
Ollama model with `ollama stop <model>` when another workload needs room.

When comparing configurations, keep the model, prompt, context, and competing
workloads consistent. Compare cold and warm time to first token as well as
generation speed and memory use. Runtime and hardware settings belong in the
host configuration rather than client-specific workarounds.

## Run code with Open Terminal

Enable Terminal in WebUI and select **Kanto workspace** for server-side code
execution. This is separate from WebUI's browser-based code interpreter.

Each WebUI user gets a persistent home directory in the shared
`open-terminal-home` volume. Users share one container and its resource limits;
these are separate workspaces, not separate containers.

The terminal can reach the public IPv4 internet for downloads and package
installation. Its network policy blocks private LAN, cluster, and tailnet
destinations, apart from cluster DNS. It has no host filesystem or Docker
socket mounted. Files in the home directory survive container replacement;
other container-local changes may not.

## Use ComfyUI

ComfyUI runs on Vermilion with a ROCm-enabled package. Its Tailscale node is
shared separately from WebUI. Access grants use of the common workspace,
uploads, outputs, and job queue; there is no separate application login.

State lives in `/var/lib/comfyui`. Add model files and custom nodes there as
needed; the Nix configuration does not install a collection of them. Backups
exclude downloaded models and temporary files. Coordinate memory-heavy image
jobs with Ollama and Lemonade workloads.
