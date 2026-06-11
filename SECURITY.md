# Security Policy

## Supported versions

Tilepad is an actively developed open-source project. Security fixes are made
against the latest release and the `main` branch.

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, report them privately via GitHub's
[private vulnerability reporting](https://github.com/lohanidamodar/tilepad/security/advisories/new)
(Security → Report a vulnerability), or email the maintainer at
**security@appwriters.dev**.

Please include:

- a description of the issue and its impact,
- steps to reproduce (a proof of concept if possible),
- affected version(s) / platform(s).

We aim to acknowledge reports within a few days and will keep you updated as we
investigate and prepare a fix. Once a fix is released we're happy to credit you,
unless you prefer to remain anonymous.

## Scope & threat model

Tilepad pairs a **desktop server** (which executes commands, sends keystrokes
and launches programs) with **mobile/web clients** over your local network. By
design, a connected client can run the actions you configure on the server.

Keep this in mind when deploying:

- **Enable PIN pairing** (server dashboard → ⋮ → Security). With it on,
  devices must enter a 6-digit PIN once before they can run actions or receive
  your page configuration and live state.
- **Run servers only on trusted networks.** The server listens on your LAN;
  without PIN pairing, anyone who can reach it and pass the handshake can
  trigger configured actions. Use the connected-clients panel to disconnect or
  **block** unknown devices.
- **Plugins are programs you choose to install** (like Stream Deck / Touch
  Portal plugins). They run as separate processes with your user's privileges.
  Only install plugins you trust. The plugin WebSocket is bound to `127.0.0.1`
  and each plugin is admitted with a one-time token.

Reports that amount to "an authorized client can run configured commands" or
"an installed plugin can run code" describe intended behavior rather than
vulnerabilities. Genuine issues — e.g. bypassing the IP block list, the plugin
token, or the loopback binding; remote code execution without authorization;
or crashes triggerable by an unauthenticated peer — are very much in scope.
