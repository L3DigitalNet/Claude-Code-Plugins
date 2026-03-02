# ssh-keygen Documentation

## Man Pages

- `man ssh-keygen` — all flags, key types, certificate options, allowed signers format
- `man ssh` — SSH client options, config file, agent forwarding
- `man sshd_config` — server-side configuration: `AuthorizedKeysFile`, `TrustedUserCAKeys`, `PubkeyAuthentication`
- `man ssh_config` — client-side configuration: `IdentityFile`, `IdentitiesOnly`, `AddKeysToAgent`
- `man ssh-copy-id` — safe authorized_keys management

## Official

- OpenSSH project site: https://www.openssh.com/
- OpenSSH portable source (GitHub): https://github.com/openssh/openssh-portable
- OpenSSH release notes: https://www.openssh.com/releasenotes.html

## Key Type References

- Ed25519 key design: https://ed25519.cr.yp.to/
- OpenSSH certificate format spec: https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.certkeys
- Comparing SSH key algorithms: https://goteleport.com/blog/comparing-ssh-keys/

## Certificate Authority Usage

- OpenSSH CA tutorial: https://www.lorier.net/docs/ssh-ca
- DigitalOcean — How To Create an SSH CA: https://www.digitalocean.com/community/tutorials/how-to-create-an-ssh-ca-to-validate-hosts-and-clients-with-ubuntu
- SSH certificates vs authorized_keys: https://smallstep.com/blog/use-ssh-certificates/

## Supplementary References

- `ssh-copy-id` man page: `man ssh-copy-id`
- ssh-agent and key forwarding: `man ssh-agent`
- Mozilla OpenSSH guidelines (recommended key types and config): https://infosec.mozilla.org/guidelines/openssh
