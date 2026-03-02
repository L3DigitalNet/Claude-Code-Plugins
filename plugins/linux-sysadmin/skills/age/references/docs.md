# age Documentation

## Man Pages

- `man age` — encryption flags, recipient types, identity file format
- `man age-keygen` — keypair generation options

## Official

- age project site: https://age-encryption.org/
- age source (GitHub): https://github.com/FiloSottile/age
- age specification (cryptographic design): https://age-encryption.org/v1
- age releases: https://github.com/FiloSottile/age/releases

## Design and Security

- age specification (full cryptographic design document): https://github.com/FiloSottile/age/blob/main/age.md
- rage (Rust implementation of age): https://github.com/str4d/rage
- age plugin system (for hardware keys, etc.): https://github.com/FiloSottile/age?tab=readme-ov-file#plugins

## Complementary Tools

- age does not sign — for signing, see:
  - minisign: https://jedisct1.github.io/minisign/
  - `ssh-keygen -Y sign` (OpenSSH signing): `man ssh-keygen` → "ALLOWED SIGNERS"
- SOPS (secrets manager that uses age for encryption): https://github.com/getsops/sops
- passage (age-based password manager, pass replacement): https://github.com/FiloSottile/passage

## Usage References

- age README (quickstart and examples): https://github.com/FiloSottile/age#readme
- age with SSH keys (recipient and identity formats): https://github.com/FiloSottile/age#ssh-keys
