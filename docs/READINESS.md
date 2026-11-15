# Development readiness audit

Run the optional, **read-only** audit from the repository root:

```bash
bash scripts/readiness-audit.sh
```

The audit checks for the Termux package manager, a writable home directory, common developer commands, optional shared storage, and Git author configuration. It does not run package upgrades, request storage permissions, access network services, print credentials, or change configuration.

- `PASS`: expected condition is present.
- `WARN`: optional capability or configuration is missing; audit still succeeds.
- `FAIL`: essential Termux environment requirement is missing; exit code is 1.

This is an environment readiness check, **not** a comprehensive security assessment. In particular, it does not verify SSH authentication, GitHub permissions, package integrity, Android permission grants, backup restorability, or physical-device compatibility.

Run offline tests with:

```bash
python3 -m unittest discover -s tests -v
```
