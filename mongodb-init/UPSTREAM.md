# UPSTREAM Snapshot

- **Source**: https://github.com/BerBai/recode
- **Pinned commit**: 2f6f57f1deaf44d8a65c51eb5d9c2c392cba80a9
- **Copied at**: 2026-05-11
- **License**: 上游仓库无 LICENSE 文件，作者 `bai5775@outlook.com` 即本仓库维护者，无第三方授权问题。
- **Source paths**:
  - `script/mongodb.sh` → `mongodb.sh`
- **Exclusions**: `.git/`, `.github/`，原仓库 `README.md`（信息量低，由本目录 README 接管）。
- **Re-vendor**: 重新跑 `gh api repos/BerBai/recode/contents/<path>?ref=<commit> --jq .content | base64 -d > <dest>`，并 bump 上面的 commit。
