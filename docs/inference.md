# Use Kanto models

Connect Tailscale before opening Kanto services or using the API. If you use
another tailnet, accept the relevant shared node first.

| Service              | Address                                        | Authentication               |
| -------------------- | ---------------------------------------------- | ---------------------------- |
| Open WebUI           | `https://openwebui.narwhal-snapper.ts.net`     | Personal WebUI account       |
| Chat Completions API | `https://openwebui.narwhal-snapper.ts.net/api` | Personal WebUI API key       |
| ComfyUI              | `https://comfyui.narwhal-snapper.ts.net`       | Access to its Tailscale node |
| Open Terminal        | Select **Kanto workspace** in WebUI            | WebUI account                |

## Sign in and create an API key

Use your WebUI account for chat. Linux login credentials are separate. An
administrator creates accounts and grants model and API-key access as described
in [cluster operations](kubernetes.md#configure-accounts-and-secrets).

1. Confirm that you can select a model in WebUI. If the list is empty, ask an
   administrator to grant your account model access.
2. Create a personal API key in WebUI's account settings. If the option is
   unavailable, ask an administrator to enable API-key access for your account.

The key permits requests to `/api/models` and `/api/chat/completions`. Native
Ollama routes, model management, embeddings, and the Responses API are
unavailable.

## Connect clients

Choose an OpenAI-compatible **Chat Completions** provider and use the API base
URL in the table above.

- Keep the `/api` suffix. The client appends `/chat/completions`, so do not add
  that path or `/v1` to the base URL.
- Use your WebUI API key for authentication.
- Use an exact model ID from `/api/models`.

Hoenn configures a `kanto` provider for both OpenCode and Hermes, using its
SOPS-managed WebUI key. In OpenCode, select Kanto through `/models`. In Hermes,
select a model with `/model custom:kanto:<model-id>`.

On other machines, configure the clients below. Keep the API key in your
client's credential store or private user configuration. Do not commit it to a
project repository.

### Configure OpenCode

Run `opencode --version` to choose the matching example. Merge the settings
into `~/.config/opencode/opencode.json`. For access within one project, use
that project's `opencode.json`.

#### OpenCode v2

Add this provider configuration. Use `/api/models` to check availability and
replace these examples when your models differ:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "kanto": {
      "name": "Kanto",
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": {
        "baseURL": "https://openwebui.narwhal-snapper.ts.net/api"
      },
      "models": {
        "Qwen3.8-Flash-Next-Strata": {
          "name": "Qwen Strata",
          "limit": { "context": 262144 }
        },
        "qwen3.6:35b-a3b-mtp-q4_K_M": {
          "name": "Qwen 3.6 MTP",
          "limit": { "context": 65536 }
        }
      }
    }
  }
}
```

Then connect the provider:

1. Start OpenCode.
2. Run `/connect` and choose `kanto`.
3. Enter your WebUI API key.
4. Run `/models` and select a Kanto model.

See the upstream [v2 provider guide](https://dev.opencode.ai/v2/docs/providers/)
and [configuration locations](https://dev.opencode.ai/v2/docs/config/).

#### OpenCode v1

Version 1 uses `provider`, `npm`, and `options`. Use `/api/models` to check
availability and replace this example when your model differs:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "kanto": {
      "name": "Kanto",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "https://openwebui.narwhal-snapper.ts.net/api"
      },
      "models": {
        "Qwen3.8-Flash-Next-Strata": {
          "name": "Qwen Strata",
          "limit": { "context": 262144, "output": 16384 }
        }
      }
    }
  }
}
```

Then connect the provider:

1. Start OpenCode.
2. Run `/connect` and select **Other**.
3. Enter `kanto` as the provider ID.
4. Paste your WebUI API key.
5. Run `/models` and select **Qwen Strata**.

The example sets a client output limit of 16,384 tokens. See the
[v1 custom-provider guide](https://opencode.ai/docs/providers/#custom-provider).

Keep the key in OpenCode's credential store. To use Strata by default, add
`"model": "kanto/Qwen3.8-Flash-Next-Strata"` at the top level of the config.

### Configure Hermes

Use the setup wizard:

1. Run `hermes model` in your terminal, outside a chat session.
2. Select the custom endpoint option.
3. Enter `https://openwebui.narwhal-snapper.ts.net/api` as the base URL.
4. Enter your personal WebUI API key.
5. Select **Chat Completions** when prompted for the API mode.
6. Enter `Qwen3.8-Flash-Next-Strata` or another model ID available to your
   account.

Alternatively, add a named provider to `~/.hermes/config.yaml`. Use `/api/models`
to check availability and replace these examples when your models differ:

```yaml
providers:
  kanto:
    api: https://openwebui.narwhal-snapper.ts.net/api
    api_key: "PASTE_YOUR_PERSONAL_WEBUI_KEY_HERE"
    transport: chat_completions
    default_model: Qwen3.8-Flash-Next-Strata
    models:
      Qwen3.8-Flash-Next-Strata:
        context_length: 262144
      qwen3.6:35b-a3b-mtp-q4_K_M:
        context_length: 65536
```

Replace the API key placeholder locally. On Linux or macOS, run
`chmod 600 ~/.hermes/config.yaml` to keep the file private. Merge `kanto` into
the existing `providers` mapping.

Start Hermes and select the named provider:

```text
/model custom:kanto:Qwen3.8-Flash-Next-Strata
```

Use `/model` to switch between configured models. Use `hermes model` to add or
change endpoints. If the setup wizard saved a different provider name, use that
name in place of `kanto`. See the
[Hermes provider guide](https://hermes-agent.nousresearch.com/docs/integrations/providers/).

### Verify the connection

Start a new chat and ask for a short reply. Then ask the agent to list the files
in a test directory to verify a complete tool call.

| Problem               | Check                                                     |
| --------------------- | --------------------------------------------------------- |
| Service unreachable   | Tailscale and the `openwebui` node share                  |
| Authentication errors | Your WebUI API key and API-key permission                 |
| Missing models        | The exact model ID and your account's model access grants |
| Endpoint errors       | The `/api` base URL and Chat Completions transport        |

For reasoning settings and their precedence, see
[Set reasoning effort](#set-reasoning-effort). A setting in a WebUI browser chat
does not configure these clients. Hermes auxiliary tasks and client tools can
have separate providers. Selecting Kanto for chat does not automatically move
those services to Kanto.

## Discover and manage models

The WebUI model picker combines Ollama and Lemonade models. Lemonade hosts
the current models. API clients can list models available to their account
through `/api/models`. The existing Qwen API IDs remain available as WebUI
aliases backed by Lemonade.

### Manage Ollama models

Ollama runs with ROCm and remains available in WebUI for additional models.
Download or inspect its models directly on Vermilion:

```sh
ollama pull <model>
ollama list
ollama ps
```

Ollama stores downloads in `/var/lib/ollama/models`. The repository does not
manage the downloaded model list.

### Manage Lemonade models

Lemonade manages Strata through the `nix-amd-ai` module. Set the model,
quantization, and cache options in `nix/hosts/nixos/vermilion/lemonade.nix`.
Lemonade stores models under `/var/lib/lemonade/models`.

### Coordinate resource use

Ollama, Lemonade, and ComfyUI share the host's memory and GPU. Their independent
model limits do not coordinate memory use across services. Unload an idle
Ollama model with `ollama stop <model>` when another workload needs room.

To compare configurations, use the same model, prompt, context, and competing
workloads. Measure cold and warm time to first token, generation speed, and
memory use. Set runtime and hardware options in the host configuration.

## Set reasoning effort

In Open WebUI, open **Chat Controls → Advanced Parameters**. Use the control
for the selected backend:

- For models hosted by Ollama, use **Think (Ollama)**.
- For Strata through Lemonade, set **Reasoning Effort** to **Custom** and enter
  a level supported by that model.
- Other Lemonade models use their own chat templates and supported reasoning
  parameters. Do not assume that they accept Strata's reasoning levels.

The **Think (Ollama)** control does not apply to Lemonade, including the Qwen
aliases. **Reasoning Tags** controls display, not the amount of thinking.
See
[Open WebUI's reasoning controls](https://docs.openwebui.com/features/chat-conversations/chat-features/reasoning-models/).

### Check model support

Supported values and defaults vary by model and backend. Check them whenever
you add or replace a model, and use the exact reported level names.

Ollama exposes supported values and defaults through
[`/api/show`](https://docs.ollama.com/capabilities/thinking). For Strata, see the
[Strata documentation](https://github.com/Niko1221/Strata/blob/master/docs/DETAILS.md)
for reasoning levels and the separate `reasoning_budget_tokens` parameter.

### Share defaults with API clients

To save a model default, use **Workspace → Models → Edit Model → Advanced
Parameters**. A setting in one WebUI chat does not change Hermes or OpenCode.

For Strata requests through WebUI, the precedence is:

1. The request's `reasoning_effort`, such as a value sent by Hermes or OpenCode.
2. The saved WebUI model's **Reasoning Effort**, when the request omits it.
3. Strata's backend default, when neither supplies a value.

A request-level setting overrides the saved model default. Client menus can
expose levels that Strata does not support. Choose a level reported for the
selected model, and check that the client sends it in the Chat Completions
request.

This precedence describes Strata's OpenAI-compatible connection, not native
Ollama's `think` parameter.

## Run code with Open Terminal

Enable Terminal in WebUI and select **Kanto workspace** for server-side code
execution. This is separate from WebUI's browser-based code interpreter.

Each WebUI user gets a persistent home directory in the shared
`open-terminal-home` volume. Users share one container and its resource limits.

The terminal can reach the public IPv4 internet for downloads and package
installation. Its network policy blocks private LAN, cluster, and tailnet
destinations, apart from cluster DNS. It has no host filesystem or Docker
socket mounted. Files in the home directory survive container replacement.
Changes elsewhere in the container may not.

## Use ComfyUI

In Open WebUI, enable **Image** in the message input's **Integrations** menu,
then describe the image. Generation uses Z-Image-Turbo at 1024 × 1024 with eight
steps.

ComfyUI runs on Vermilion with a ROCm-enabled package. Its Tailscale node is
shared separately from WebUI. Anyone with access can use the common workspace,
uploads, outputs, and job queue. ComfyUI has no separate application login.

To use Krea 2 Turbo, open the saved `krea2-turbo` workflow in ComfyUI. Nix installs
both models, their text encoders and VAEs, and the two saved workflows. Change
the model list in `nix/hosts/nixos/vermilion/comfyui.nix`. Open WebUI uses one
generation workflow at a time.

State lives in `/var/lib/comfyui`. Backups exclude downloaded models and temporary
files. Coordinate memory-heavy image jobs with Ollama and Lemonade workloads.
