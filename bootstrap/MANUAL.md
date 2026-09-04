# Manual actions after bootstrap

Credentials and personal data are intentionally excluded. Complete only the
items you use:

- Sign into 1Password, then enable its SSH agent and CLI integration.
- Authenticate GitHub (`gh auth login`) and verify SSH access.
- Sign into Chromium, Discord, Signal, Spotify, Steam, Typora, and Zed.
- Authenticate Claude/Codex profiles with the launchers documented in the
  `melonamin.multi-agents` plugin.
- Configure Home Assistant and any other plugin credentials locally.
- Download Handy/Voxtype speech models; model files are data and are not copied.
- Launch agterm once and install/verify its agent-status integration if a newer
  release changes the integration files.
- Restore project repositories separately. Lumarchy and SecondScribe currently
  have no Git remotes, so their experimental shortcuts cannot be recreated by
  this repository alone.

The bootstrap deliberately does not enable Docker/libvirt, SSHD, Syncthing,
Tailscale/NetBird, Beszel, agentcy, t3code, cliproxy, or skein services.
