# Optional developer utilities

These scripts are intentionally **not installed as global commands**. Run them from the repository checkout, so the existing transactional installer and uninstall contract remain unchanged.

## Project status

```bash
bash scripts/project-status.sh "$HOME/Termux-Pro"
```

Shows branch, uncommitted changes and upstream ahead/behind counts without fetching, changing branches or contacting GitHub. The ahead/behind counts use locally cached refs and may be stale.

## Sensitive-file permissions

```bash
bash scripts/security-audit.sh "$HOME"
```

Checks permissions of selected SSH and credential file paths without reading or printing file contents. Warns about symbolic links and group/other permissions. No files are modified.

**Limitations:** This is a targeted permissions check, not malware scanning or comprehensive secret discovery. It does not check the complete filesystem, verify whether a credential was exposed previously, or validate Android application sandbox permissions. Symlinks are reported rather than followed. Never paste secret file contents into an issue.

## Tests

```bash
python3 -m unittest discover -s tests -v
```

The optional tools are designed to operate offline and require no paid services.
