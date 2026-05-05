# Ansible Role: Nix

Deploys [Nix](https://nixos.org/nix/) for a specified user on **Debian/Ubuntu** and **macOS (Darwin)** hosts.

## Platform support

| Platform | Method |
|---|---|
| Debian / Ubuntu | Multi-user Nix install, nixbld group, channel bootstrap |
| macOS (Darwin) | [nix-darwin](https://github.com/LnL7/nix-darwin) flake-based setup |

## Variables

| Variable | Default | Description |
|---|---|---|
| `nix_user` | `admin` | User for whom Nix is installed |
| `nix_version` | `2.33.1` | Nix version to install |
| `nix_tarball_sha` | see `defaults/main.yml` | SHA256 of the installer tarball |
| `nix_multi_user` | `true` | Enable multi-user (daemon) install |
| `nix_settings` | `{}` | Key/value pairs written to `/etc/nix/nix.conf` (Linux only) |
| `nix_extra_settings` | `{}` | Merged on top of `nix_settings` for per-host overrides |
| `nix_force_apply` | `false` | Force `nix-darwin switch` even when config is unchanged |

### nix_settings / nix_extra_settings

Written to `/etc/nix/nix.conf` on Linux via `lineinfile`. Ignored on Darwin where nix-darwin manages `nix.conf` itself.

```yaml
nix_settings:
  max-jobs: auto
  # trusted-users grants the user elevated Nix daemon privileges
  # (add substituters, override sandbox paths, etc.) - Linux only
  # On Darwin, admin group members are trusted by default via @admin
  trusted-users: '{{ nix_user }}'

nix_extra_settings:
  sandbox: true
```

## Darwin prerequisites

- macOS 12 or higher (Apple Silicon or Intel)
- Nix installed (single- or multi-user) before running this role
- Templates `nix/flake.nix.j2` and `nix/configuration.nix.j2` present in the calling playbook

## Darwin behaviour

The role backs up any `/etc` files that conflict with nix-darwin
(`nix.conf`, `bashrc`, `zshrc`, `zprofile`) before running `nix-darwin switch`.
Backups are written to `<file>.before-nix-darwin` and only created once -
subsequent runs are idempotent.

## Handlers

| Handler | Trigger |
|---|---|
| `restart nix-daemon` | Any change to `/etc/nix/nix.conf` (Linux only) |