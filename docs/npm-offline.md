---
title: npm-offline
nav_order: 3
description: 把 npm 包及其完整依赖打成 tar.gz
---

# npm-offline

把任意 npm 包及其完整依赖打成 tar.gz，离线机解压即可 `npm install`。

> 该工具暂无独立 README。完整脚本与用法见 [GitHub 仓库 / npm-offline](https://github.com/BerBai/Tools/tree/main/npm-offline)。
> README 落地后，本页会由 `make sync-docs` 自动接管。

## 快速用法

```bash
# 在仓库根
make npm-bundle PKG=lodash@4
ls dist/npm-offline-bundle.tar.gz
```

`macOS · Linux`
