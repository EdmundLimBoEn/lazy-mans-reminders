# Lazy Man's Reminders plugin

Connects agents to the lock-screen board MCP at `https://lmr-mcp.edmundlim.systems/mcp`.

This directory ships two manifests so both Agent Plugins and Cursor Plugins can load it:

- Agent Plugins: root `plugin.json` + `mcp.json` (`$schema`, `type: "streamable-http"`)
- Cursor Plugins: `.cursor-plugin/plugin.json` + `.cursor-plugin/mcp.json` (declares `LMR_AGENT_TOKEN`)

## Grok Bot

Configure a personal agent token. OAuth connect is still flaky on Grok Bot:

1. Sign in on the board at [lmr.edmundlim.systems](https://lmr.edmundlim.systems).
2. Open **Agent access → Advanced** and mint a key. It is shown once. The format is `lmr_<uuid>_<secret>`.
3. Set `LMR_AGENT_TOKEN` on the plugin (Plugins → Configure), or on a custom connector set header `Authorization: Bearer <token>`.

Never commit the token, paste it into chat, or put it in this repo. The plugin only declares the variable name; you supply the value on the host.

Clients that omit the `Authorization` header can still use OAuth. The Worker accepts a personal agent token **or** an OAuth session.
