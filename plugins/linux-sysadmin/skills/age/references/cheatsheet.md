# age Encryption Command Reference

Each block below is copy-paste-ready. Substitute key paths, recipient public
keys, and filenames for your actual values.

Public keys start with `age1...`. Key files (from `age-keygen`) contain both
public and private keys — keep them private; share only the `age1...` line.

---

## 1. Key Generation

```bash
# Generate a keypair and save to a file
age-keygen -o ~/.age/key.txt

# The file contains:
# # created: 2025-01-01T00:00:00Z
# # public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac97
# AGE-SECRET-KEY-1...

# Print the public key from an existing key file
age-keygen -y ~/.age/key.txt

# Create key directory with restrictive permissions
mkdir -p ~/.age && chmod 700 ~/.age
age-keygen -o ~/.age/key.txt && chmod 600 ~/.age/key.txt
```

---

## 2. Encrypt to a Public Key

```bash
# Encrypt a file to a recipient's public key
age -r age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac97 \
    -o encrypted.age plaintext.txt

# Encrypt to your own key (using the public key extracted from your key file)
PUBKEY=$(age-keygen -y ~/.age/key.txt)
age -r "$PUBKEY" -o encrypted.age plaintext.txt

# Encrypt to a file of public keys (one per line, -R is capital R)
age -R ~/.age/recipients.txt -o encrypted.age plaintext.txt
```

---

## 3. Encrypt to Multiple Recipients

```bash
# Multiple -r flags — any recipient can decrypt
age \
  -r age1key1ql3z7hjy54pw3hyww5ayyfg7zq... \
  -r age1key2abc123def456... \
  -o encrypted.age plaintext.txt

# Combine public key and SSH key recipients
age \
  -r age1key1ql3z7hjy54pw3hyww5ayyfg7zq... \
  -R ~/.ssh/id_ed25519.pub \
  -o encrypted.age plaintext.txt

# From a file containing multiple public keys (one per line)
# ~/.age/team-keys.txt:
#   age1alice...
#   age1bob...
age -R ~/.age/team-keys.txt -o encrypted.age plaintext.txt
```

---

## 4. Encrypt with a Passphrase

```bash
# Interactive passphrase encryption (prompted twice)
age -p -o encrypted.age plaintext.txt

# Decrypt a passphrase-encrypted file (prompts for passphrase)
age -d -o plaintext.txt encrypted.age

# Note: passphrase mode uses scrypt — intentionally slow.
# For automated scripts, use key-based encryption instead.
```

---

## 5. Decrypt

```bash
# Decrypt using your key file
age -d -i ~/.age/key.txt -o plaintext.txt encrypted.age

# Decrypt using your SSH private key (if encrypted to your SSH public key)
age -d -i ~/.ssh/id_ed25519 -o plaintext.txt encrypted.age

# Decrypt to stdout (useful in pipelines)
age -d -i ~/.age/key.txt encrypted.age

# Decrypt stdin from a pipe
cat encrypted.age | age -d -i ~/.age/key.txt > plaintext.txt
```

---

## 6. SSH Key Recipients

```bash
# Encrypt to an SSH Ed25519 public key
age -R ~/.ssh/id_ed25519.pub -o encrypted.age plaintext.txt

# Encrypt to an SSH RSA public key
age -R ~/.ssh/id_rsa.pub -o encrypted.age plaintext.txt

# Encrypt to a remote user's SSH key (fetched from GitHub)
curl -s https://github.com/username.keys | age -R - -o encrypted.age plaintext.txt

# Decrypt using the corresponding SSH private key
age -d -i ~/.ssh/id_ed25519 -o plaintext.txt encrypted.age
```

---

## 7. ASCII Armor Output

```bash
# Armor output: base64-encoded text (safe to paste in email, chat, etc.)
age -a -r age1key... -o encrypted.txt plaintext.txt

# The output looks like:
# -----BEGIN AGE ENCRYPTED FILE-----
# ...base64 data...
# -----END AGE ENCRYPTED FILE-----

# Decrypt an armored file (age detects armor automatically)
age -d -i ~/.age/key.txt -o plaintext.txt encrypted.txt

# Pipe armored output (stdout)
echo "secret" | age -a -r age1key... > message.txt
```

---

## 8. Stdin and Stdout Pipelines

```bash
# Encrypt stdin to stdout
echo "secret data" | age -r age1key... > encrypted.age

# Encrypt a command's output
kubectl get secret mysecret -o yaml | age -r age1key... > secret-backup.age

# Decrypt to stdout and pipe onward
age -d -i ~/.age/key.txt encrypted.age | jq '.data'

# Chain with tar for directory encryption
tar czf - /path/to/dir | age -r age1key... > backup.tar.gz.age

# Restore
age -d -i ~/.age/key.txt backup.tar.gz.age | tar xzf - -C /restore/path/
```

---

## 9. Batch File Encryption

```bash
# Encrypt all .yaml files in a directory
for f in secrets/*.yaml; do
  age -r age1key... -o "${f}.age" "$f"
done

# Encrypt and remove originals (use with care)
for f in secrets/*.yaml; do
  age -r age1key... -o "${f}.age" "$f" && rm "$f"
done

# Decrypt all .age files in a directory
for f in secrets/*.yaml.age; do
  age -d -i ~/.age/key.txt -o "${f%.age}" "$f"
done

# Encrypt a database backup
pg_dump mydb | gzip | age -r age1key... > mydb-$(date +%F).sql.gz.age
```

---

## 10. Practical Homelab Patterns

```bash
# Store a secret for a service, encrypted to your key
echo "db_password=hunter2" | age -r "$(age-keygen -y ~/.age/key.txt)" > db-secret.age

# Read the secret back in a script
DB_PASSWORD=$(age -d -i ~/.age/key.txt db-secret.age | grep db_password | cut -d= -f2)

# Encrypt a .env file before committing
age -R ~/.age/recipients.txt -o .env.age .env
echo ".env" >> .gitignore  # never commit the plaintext

# Bootstrap a new server: send your private key encrypted to their SSH key
age -R /path/to/new-server-ssh-public-key -o key.txt.age ~/.age/key.txt
# Transfer key.txt.age; they decrypt with: age -d -i ~/.ssh/id_ed25519 key.txt.age

# Verify a file is decryptable before deleting the original
age -d -i ~/.age/key.txt encrypted.age > /dev/null && echo "decryption OK"
```
