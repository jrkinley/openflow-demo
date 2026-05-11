# Plan: Rename & Restructure → snowflake-demos

## Context
- **Current repo**: `/Users/jkinley/code/openflow-demo` (remote: `github.com/jrkinley/openflow-demo`)
- **SPCS-python repo**: `/Users/jkinley/code/spcs-python` (remote: `github.com/jrkinley/spcs-python`)
- **Current branch**: `postgres-cdc-demo` (will branch from `main`)

## Final Directory Structure

```
snowflake-demos/
├── .git/
├── .github/
│   └── workflows/
│       └── flowdiff.yml
├── .gitignore
├── .snowflake/
├── README.md                             ← NEW top-level index
│
├── terraform/                            ← Shared infra (stays at root)
│   ├── amazon-mq/
│   ├── msk/
│   ├── rds-postgres/
│   └── sftp/
│
├── openflow/                             ← CATEGORY: Openflow demos
│   ├── imf-datamapper-demo/
│   ├── nasdaq-demo/
│   ├── postgres-cdc-demo/
│   └── versioning/
│
└── snowpark/                             ← CATEGORY: Snowpark / SPCS demos
    └── spcs-python/
```

## Implementation Steps

### 1. Create new branch
Branch from `main` to isolate the restructure work.

### 2. Rename parent directory
Rename `/Users/jkinley/code/openflow-demo` to `/Users/jkinley/code/snowflake-demos`.

### 3. Reorganise into category folders
- Create `openflow/` and `snowpark/` directories
- `git mv` the demo folders into `openflow/`: imf-datamapper-demo, nasdaq-demo, postgres-cdc-demo, versioning
- `terraform/` stays at root (shared infrastructure, not Openflow-specific)

### 4. Move SPCS-python into snowpark/
Copy SPCS-python project files (excluding `.git`, `.venv`, `.env`, `rsa_key*`, `profile.json`) into `snowpark/spcs-python/`.

### 5. Update .gitignore and references
Merge SPCS-python `.gitignore` entries into root. Update GitHub Actions workflow paths and any internal cross-references.

### 6. Review and fix documentation and relative paths
Audit all READMEs and code files for relative path references that are now broken due to the restructure. Key areas:
- Openflow demo READMEs that reference `../terraform/` (now need `../../terraform/`)
- nasdaq-demo docs that link to sibling files or terraform modules
- Any scripts or configs that use relative paths to other directories
- SPCS-python README links that assume standalone repo context
- GitHub Actions workflow file paths

### 7. Add top-level README
Create a root `README.md` describing the repo structure with links to each demo.

### 8. Commit and verify
Stage all changes, commit, and verify with `git status`.

## Verification
- `git status` shows clean working tree after commit
- `tree -L 2` confirms expected structure
- No secrets committed (check with `git diff --cached` before committing)
- Grep for broken relative paths (`../terraform`, old repo name references)

## Critical Files
- `.gitignore` - Must be updated to cover SPCS-python entries
- `.github/workflows/flowdiff.yml` - Paths may need updating after moves
- `README.md` - New top-level index to create
- `openflow/nasdaq-demo/README.md` - Likely references terraform
- `openflow/postgres-cdc-demo/README.md` - May reference sibling dirs

## Notes
- Sensitive files (`.env`, `rsa_key*`, `profile.json`) will NOT be copied
- GitHub remote rename is a manual follow-up step (`gh repo rename snowflake-demos`)
