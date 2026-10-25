# Connect OpenCode and Hermes to Kanto

Use Kanto's authenticated Open WebUI API from an existing OpenCode or Hermes
installation. These steps use the clients' own configuration and setup commands.
Hoenn already configures the `kanto` provider through Nix.

## Prepare your account

1. Connect to Tailscale. If you use another tailnet, accept the shared
   `openwebui` node first.
2. Sign in to [Open WebUI](https://openwebui.narwhal-snapper.ts.net).
3. Confirm that you can select a model. If the list is empty, ask an
   administrator to grant your account access to the models.
4. Create a personal API key in your account settings. If that option is
   unavailable, ask an administrator to enable API-key access for your account.

Use these values in both clients:

| Setting          | Value                                          |
| ---------------- | ---------------------------------------------- |
| Provider name    | `kanto`                                        |
| API base URL     | `https://openwebui.narwhal-snapper.ts.net/api` |
| API format       | OpenAI-compatible Chat Completions             |
| API key          | Your personal Open WebUI API key               |
| Example model ID | `Qwen3.8-Flash-Next-Strata`                    |

Keep the `/api` suffix. Do not add `/v1` or `/chat/completions` to the base URL.
Kanto exposes Chat Completions, not the Responses API. Use exact model IDs
from your account's `/api/models` response or the [model list](inference.md#set-reasoning-effort).

## Configure OpenCode

Run `opencode --version` and use the matching example below. Merge the settings
into `~/.config/opencode/opencode.json`, preserving your existing configuration.
A project-level `opencode.json` also works if you want Kanto only in that project.

### OpenCode v2

Add this provider configuration:

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
          "limit": { "context": 131072 }
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

Start OpenCode, run `/connect`, and connect the `kanto` provider with your
WebUI API key. Run `/models` and select a Kanto model.

See the upstream [v2 provider guide](https://dev.opencode.ai/v2/docs/providers/)
and [configuration locations](https://dev.opencode.ai/v2/docs/config/).

### OpenCode v1

Use this configuration instead. Version 1 uses `provider`, `npm`, and `options`:

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
          "limit": { "context": 131072, "output": 16384 }
        }
      }
    }
  }
}
```

Start OpenCode and run `/connect`. Select **Other**, enter `kanto` as the
provider ID, and paste your WebUI API key. Run `/models` and select **Qwen Strata**.
The example reserves up to 16,384 tokens for output; this is a client setting,
not a separate server limit. See the [v1 custom-provider guide](https://opencode.ai/docs/providers/#custom-provider).

For either version, keep the key in OpenCode's credential store rather than
adding it to a project file. To select Strata as your default, add
`"model": "kanto/Qwen3.8-Flash-Next-Strata"` at the top level of the config.

## Configure Hermes

Run `hermes model` in your terminal, outside a chat session. Select the custom
endpoint option and enter the base URL, personal API key, and model ID above.
Choose **Chat Completions** when prompted for the API mode.

Alternatively, add a named provider to `~/.hermes/config.yaml`:

```yaml
providers:
  kanto:
    api: https://openwebui.narwhal-snapper.ts.net/api
    api_key: "PASTE_YOUR_PERSONAL_WEBUI_KEY_HERE"
    transport: chat_completions
    default_model: Qwen3.8-Flash-Next-Strata
    models:
      Qwen3.8-Flash-Next-Strata:
        context_length: 131072
      qwen3.6:35b-a3b-mtp-q4_K_M:
        context_length: 65536
```

Replace the placeholder locally and keep this file private. On Linux or macOS,
run `chmod 600 ~/.hermes/config.yaml`. Merge the `kanto` entry into an existing
`providers` mapping rather than creating a duplicate mapping.

Start Hermes and select the named provider:

```text
/model custom:kanto:Qwen3.8-Flash-Next-Strata
```

Use `/model` to switch between configured models. Use `hermes model` to add or
change endpoints. If the setup wizard saved a different provider name, use that
name in place of `kanto`. See the [Hermes provider guide](https://hermes-agent.nousresearch.com/docs/integrations/providers/).

## Verify the connection

Start a new chat and ask for a short reply. Then ask the agent to list the files
in a test directory to verify a complete tool call.

- If the service is unreachable, check Tailscale and the `openwebui` node share.
- For authentication errors, check your WebUI API key and API-key permission.
- For missing models, check the exact ID and your account's model access grants.
- For endpoint errors, check the `/api` base URL and Chat Completions transport.

For reasoning settings and their precedence, see
[Set reasoning effort](inference.md#set-reasoning-effort). A setting in a WebUI
browser chat does not configure these clients. Hermes auxiliary tasks and
client tools can have separate providers; selecting Kanto for chat does not
automatically move those services to Kanto.
