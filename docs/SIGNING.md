# Signing and distribution

An ad-hoc signature is suitable for local development. It does not identify a
trusted developer to Gatekeeper. Public distribution requires a **Developer ID
Application** certificate, hardened runtime, Apple notarization and a stapled
notarization ticket. A normal first-launch confirmation or organization policy
can still apply; do not promise that every Mac will show no prompts.

## Maintainer prerequisites

1. An Apple Developer Program membership and permission to use its Developer ID
   Application certificate. Install the certificate and its private key in the
   local login Keychain. Never commit or share the private key.
2. Create a named notarization credential profile using the interactive command
   `xcrun notarytool store-credentials MailSwitch-notary`. Follow Apple's prompts
   locally; do not put passwords or API keys in scripts or Git.
3. Select the intended publisher. The certificate's legal person or organization
   name is embedded in signed builds and is visible to recipients. Public source
   licensing does not require publishing a signing key.

## Produce a notarized ZIP

First run `bash scripts/test.sh` and `bash scripts/build.sh`. Then, with the actual
installed certificate name, run:

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR PUBLISHER (TEAMID)' \
NOTARY_PROFILE='MailSwitch-notary' bash scripts/notarize.sh
```

The script signs a staging copy, submits it to Apple, requires an Accepted result,
staples and validates the ticket, checks Gatekeeper acceptance, and only then
produces `dist/MailSwitch-notarized.app.zip` and its checksum. It never turns a
failed submission into a successful release. This path requires real credentials
and Apple service access; shell validation alone is not an end-to-end signing test.

Distribute that ZIP after testing a browser-downloaded copy on another Mac.
Keep the development ZIP clearly labeled. The GitHub workflow currently builds
ad-hoc packages and does not contain signing credentials.

For managed company Macs, IT may instead deploy an approved package through its
device-management system. Local administrator status on GitLab does not provide
Apple signing credentials or override macOS policy.

[Apple: Developer ID](https://developer.apple.com/developer-id/)
· [Apple: notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
