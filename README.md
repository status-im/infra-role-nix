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
| `nix_access_tokens` | `{}` | Host/token pairs for Nix `access-tokens` setting |
| `nix_access_tokens_file` | `/etc/nix/access-tokens.conf` | Where `nix_access_tokens` are written |
| `nix_force_apply` | `false` | Force `nix-darwin switch` even when config is unchanged |
| `nix_cleanup_delete_older_than` | `30d` | Nix Store cleanup removes entries older than this |
| `nix_additional_inputs` | `{}` | Key/values pair of addtionnal inputs |

### nix_settings / nix_extra_settings

Written to `/etc/nix/nix.conf` on Linux via `lineinfile`. Ignored on Darwin where nix-darwin manages `nix.conf` itself.

```yaml
nix_extra_settings:
  sandbox: true
```

### nix_access_tokens

Written to `nix_access_tokens_file` and pulled into `nix.conf` with `!include` on both Linux and Darwin.
This keeps tokens out of the Nix store on Darwin, where nix-darwin generates `nix.conf`.
Nix uses these for `github:` flake inputs and `fetchTree` calls, avoiding unauthenticated API rate limits.

```yaml
nix_access_tokens:
  'github.com': 'ghp_...'
```

### nix_additional_inputs

Add additional inputs to the `flake,nix`:

```
nix_additional_inputs:
  unstable: 'github:NixOS/nixpkgs/commit-rev'

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

# Known Issues

- Nix install fails with: `vifs: error creating /etc/fstab`
  - Go to: `System Settings` → `General` → `Sharing`
  - Click ⓘ icon next to `Remote Login`
  - Enable `Allow full disk access for remote users.`
  - ![Full disk access screenshot](./files/full_disk_access_fix.png)
