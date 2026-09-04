# Lazy Man's Reminders plugin

Connects agents to the lock-screen board MCP at `https://lmr-mcp.edmundlim.systems/mcp`.

This directory ships two manifests so both Agent Plugins and Cursor Plugins can load it:

- Agent Plugins: root `plugin.json` + `mcp.json` (`$schema`, `type: "streamable-http"`)
- Cursor Plugins: `.cursor-plugin/plugin.json` + `.cursor-plugin/mcp.json` (declares `LMR_AGENT_TOKEN`)

## Grok Bot

Add a custom connector for `https://lmr-mcp.edmundlim.systems/mcp`. Sign in with Google or Apple in the browser that opens, then tap **Allow**.

If a host cannot use OAuth, sign in on the [board](https://lmr.edmundlim.systems), open **Agent access → Advanced**, and mint a personal key. Set `LMR_AGENT_TOKEN` on the plugin or add `Authorization: Bearer <token>` to a custom connector.

Never commit the token, paste it into chat, or put it in this repo. The plugin only declares the variable name; you supply the value on the host.

Clients that omit the `Authorization` header can still use OAuth. The Worker accepts a personal agent token **or** an OAuth session.
