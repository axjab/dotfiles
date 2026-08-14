# Session Notes

Things discovered during the current/previous conversation.

- `require keys` previously produced `keys=` after `gpg --list-secret-keys`.
- The old implementation appeared to fall through instead of completing the
  enrollment workflow.
- We want enrollment confirmation persisted by fingerprint.
- `gum` should be preferred for interaction.
- Do not repeatedly display enrollment instructions after confirmation.

These notes are context, not authoritative specification.
