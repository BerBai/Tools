# npm-offline

把任意 npm 包（含完整传递依赖）打成自带 verdaccio 的 tar.gz，离线机器解压一行命令完成 `npm install`。

## Why

**问题**：内网开发机 / 客户机房 / 临时无网环境需要装一个 npm 包。`npm pack` 只下当前层、不解决依赖；离线 mirror（如把 `~/.npm` 整个拷过去）跨 npm 版本不可移植；`npmbox` / `npm-bundle` 等老工具大多停止维护。

**思路**：在联网机上**先解析完整依赖树**（`npm install --package-lock-only` 走 npm 自己的求解器，结果最权威），按 lockfile 里 `resolved` 字段把所有 tarball 拉下来，**附带一个 portable verdaccio 运行时**打成 tar.gz。离线机解压后 `./install.sh` 起本地 verdaccio（端口 4873），把 tarball 全部 `npm publish` 进去，之后就和正常用 `registry.npmjs.org` 一样。

**对比**：

| 方案 | 跨 npm 版本 | 自带 registry | 处理 transitive deps | 维护状态 |
|------|------|------|------|------|
| `npm pack` | ✅ | ❌ | ❌ | 官方 |
| 拷 `~/.npm` 缓存 | ❌（路径/格式漂移） | ❌ | ✅ | 官方 |
| `npmbox` / `npm-bundle` | ⚠️ | ❌ | ⚠️ | 不维护 |
| **本工具** | ✅ | ✅（bundle 里带） | ✅（lockfile 求解） | 自维护 |

## 快速上手

```bash
# 联网机：打包
make npm-bundle PKG="lodash@4"
# 产物：dist/npm-offline-bundle.tar.gz

# 离线机：解压 + 一行起飞
tar -xzf npm-offline-bundle.tar.gz
cd npm-offline-bundle && ./install.sh --install
```

`./install.sh --install` 会启 verdaccio、把所有 tarball publish 进去、然后在当前目录 `npm install` 顶层包。

## 安装

**联网机依赖**：

| 工具 | 用途 |
|------|------|
| `node` ≥ 14 + `npm` | 解析依赖树、调用 `npm publish` |
| `curl` | 下载 tarball（自动启用 `--retry-all-errors`，curl ≥ 7.71） |
| `tar` | 打包 tar.gz |
| `bash` ≥ 4 | 跑脚本本体 |

**离线机依赖**：
- `node` ≥ 14 + `npm`
- `verdaccio`：默认 bundle 内已自带（`verdaccio-bootstrap/node_modules/.bin/verdaccio`），离线机**无需另装**。打包时加 `--no-verdaccio` 才需要离线机自己 `npm install -g verdaccio`。
- `curl`（`install.sh` 探测 verdaccio 是否就绪）

**平台支持**：Linux、macOS。Windows 通过 WSL。

**Makefile 集成**：`make npm-bundle PKG=<spec>` 是上层入口，等价于 `./npm-offline/npm_offline_install.sh <spec>`。

## 详细用法

### 打包阶段（联网机）

```
Usage: npm_offline_install.sh [options] <pkg>[@version] [<pkg>[@version] ...]

Options:
  -o, --output DIR     Output directory (default: ./dist)
  -n, --name NAME      Bundle name (default: npm-offline-bundle)
  -r, --registry URL   Source registry (default: https://registry.npmjs.org)
      --no-verdaccio   Do not bundle a verdaccio runtime
      --target-os OS   Target host OS (linux/darwin/win32/...). Default: host
      --target-cpu CPU Target CPU (x64/arm64/ia32/...). Default: host
      --target-libc L  Target libc (glibc/musl). Default: host
  -h, --help           Show this help
```

**多包 / 指定版本 / 自定义产物路径**：

```bash
./npm-offline/npm_offline_install.sh lodash
./npm-offline/npm_offline_install.sh react@18 react-dom@18
./npm-offline/npm_offline_install.sh -n my-bundle -o /tmp/out @babel/core express
./npm-offline/npm_offline_install.sh -r https://registry.npmmirror.com vue
```

**断点续传**：`dist/npm-offline-bundle/tarballs/` 是持久目录，重跑同一命令时已下完的 tarball 直接命中缓存（输出 `[i/N] cache xxx`）。中断后只需重跑同一行即可继续。

**关于 `--no-verdaccio`**：默认会在 bundle 里嵌一份 verdaccio（约 +30MB），离线机零依赖。如果离线机已经全局装了 verdaccio，`--no-verdaccio` 能让产物更小。

### 跨平台打包（在 mac 上为 linux 打 bundle）

很多 npm 包（如 `@anthropic-ai/claude-code`、`esbuild`、`@biomejs/biome`、`turbo`、`@swc/core`）通过 **`optionalDependencies` 分发平台 native binary**：每个平台一个独立子包（`pkg-linux-x64`、`pkg-darwin-arm64`...），主包用 postinstall 脚本根据 `process.platform` / `process.arch` 挑选。

默认情况下脚本不传 `--os/--cpu/--libc` 给 npm，lockfile 会把**所有平台**的 optional dep 都解出来，bundle 因此膨胀到几百 MB（每平台 50–80MB 不止）。要瘦身或避免跨 npm 版本的行为漂移，用 `--target-*` 显式指定目标主机：

```bash
# mac 上为 linux x86_64 打 claude-code（最常见场景）
./npm-offline/npm_offline_install.sh --target-os linux --target-cpu x64 @anthropic-ai/claude-code

# 配合 Makefile
make npm-bundle PKG=@anthropic-ai/claude-code TARGET_OS=linux TARGET_CPU=x64

# Alpine / musl 目标
make npm-bundle PKG=@anthropic-ai/claude-code TARGET_OS=linux TARGET_CPU=x64 TARGET_LIBC=musl

# linux arm64（aarch64 / Graviton / 树莓派 64）
make npm-bundle PKG=@anthropic-ai/claude-code TARGET_OS=linux TARGET_CPU=arm64
```

| 选项 | 取值 |
|------|------|
| `--target-os`   | `linux` / `darwin` / `win32` / `freebsd` / `openbsd` / `aix` / `sunos` / `android` |
| `--target-cpu`  | `x64` / `arm64` / `ia32` / `arm` / `ppc64` / `s390x` / `mips` / `mipsel` / `riscv64` / `loong64` |
| `--target-libc` | `glibc`（默认 Linux 发行版）/ `musl`（Alpine 系） |

**注意事项**：
- 一次打包**只支持一个目标平台**。要给多平台分发请多跑几次（每个平台一个 bundle）。
- 校验是 warning 级别 —— 未知值仍会透传给 npm，由 npm 决定接不接受。这样未来新平台不会被脚本卡住。
- 不传 `--target-*` 时行为不变（lockfile 自然包含全平台）。如果你只装一个没有 native binary 的纯 JS 包（比如 `lodash`），加不加 flag 都没区别。
- bundle 里的 `bundle.env` 会记录 `BUNDLE_TARGET_OS / CPU / LIBC` 三个字段，便于排错。
- **`--target-libc` 精度依赖上游 package.json 是否标注**。如 `@anthropic-ai/claude-code` 把 `linux-x64` 和 `linux-x64-musl` 拆成两个独立 optional dep 但**都没写 `libc` 字段**，因此 `--target-libc musl` 会把两个 linux-x64 变体都保留（postinstall 在目标机上自己挑）。`@swc/core` 等规范标注 `libc` 的包过滤会精确。glibc 目标基本不需要传 `--target-libc`。
- 已知的 native-binary 主流包：`@anthropic-ai/claude-code`、`esbuild`、`@biomejs/biome`、`@swc/core`、`lightningcss`、`turbo`、`@parcel/watcher`、`rollup`、`vite` 的一些 plugin、`sharp` 等。

### 安装阶段（离线机）

```
Usage: install.sh [option]
  -i, --install         install requested packages locally (in CWD) after publish
  -G, --install-global  install requested packages globally after publish
      --no-install      publish only, do not install
  -h, --help            show this help
With no flag: prompt on a tty, skip on non-tty.
```

**典型流程**：

```bash
tar -xzf npm-offline-bundle.tar.gz
cd npm-offline-bundle

./install.sh                 # 交互：tty 下问 [l]ocal/[g]lobal/[s]kip
./install.sh --install       # 直接在当前目录装顶层包（无 package.json 时自动 npm init -y）
./install.sh -G              # 全局装
./install.sh --no-install    # 仅起 verdaccio + publish，不装
```

**手动安装更多包**：`install.sh` 跑完后 verdaccio 仍在后台运行，可以继续：

```bash
npm install --registry=http://localhost:4873 <any-package-already-published>
```

**关闭 verdaccio**：
```bash
[[ -f .verdaccio/verdaccio.pid ]] && kill "$(cat .verdaccio/verdaccio.pid)" && rm .verdaccio/verdaccio.pid
```

### 产物布局

```
npm-offline-bundle/
├── tarballs/                    # 全量 tarball（含 scope 子目录）
│   ├── lodash-4.17.21.tgz
│   └── @babel/core-7.x.tgz
├── verdaccio-bootstrap/         # portable verdaccio（--no-verdaccio 时不存在）
│   └── node_modules/.bin/verdaccio
├── install.sh                   # 离线安装脚本
├── bundle.env                   # 顶层包列表（resolved 后的精确 name@version）
└── README.md                    # 由打包脚本自动生成（不要手改）
```

`bundle.env` 例子：

```bash
# Original user input: react@18
BUNDLE_TARGET_OS=
BUNDLE_TARGET_CPU=
BUNDLE_TARGET_LIBC=
BUNDLE_PKGS=(react@18.3.1)
```

加 `--target-*` 后：

```bash
# Original user input: @anthropic-ai/claude-code
BUNDLE_TARGET_OS=linux
BUNDLE_TARGET_CPU=x64
BUNDLE_TARGET_LIBC=
BUNDLE_PKGS=(@anthropic-ai/claude-code@2.1.138)
```

## 环境变量

打包脚本本身**不读环境变量**，所有配置通过 CLI flag。

`install.sh` 读 3 个：

| 变量 | 默认 | 说明 |
|------|------|------|
| `REGISTRY_URL` | `http://localhost:4873` | verdaccio 监听地址。改了须保证 verdaccio 实际能在该地址起来 |
| `VERDACCIO_HOME` | `<bundle>/.verdaccio` | verdaccio 运行时数据目录（log / pid / storage） |
| `VERDACCIO_MAX_BODY_SIZE` | 动态算 | verdaccio 上传 body 上限。不设时 `install.sh` 自动按 `max(200mb, ceil(最大 tarball × 2 / MB) mb)` 估算（× 2 覆盖 npm publish 的 base64 + JSON 信封膨胀）。设了就直接用，例如 `2gb` |

例：

```bash
REGISTRY_URL=http://localhost:5873 ./install.sh --install
VERDACCIO_MAX_BODY_SIZE=2gb ./install.sh        # 直接拉满，调试或大包兜底
```

## 示例输出

**打包脚本 `--help`**：

```
$ bash npm-offline/npm_offline_install.sh --help
Usage: npm_offline_install.sh [options] <pkg>[@version] [<pkg>[@version] ...]

Resolves the full dependency tree of the requested packages, downloads every
tarball, and produces a tar.gz bundle plus an offline install.sh that publishes
the tarballs into a local verdaccio registry on the target machine.

Options:
  -o, --output DIR     Output directory (default: ./dist)
  -n, --name NAME      Bundle name (default: npm-offline-bundle)
  -r, --registry URL   Source registry (default: https://registry.npmjs.org)
      --no-verdaccio   Do not bundle a verdaccio runtime (default: bundle it,
                       so install.sh works on hosts without verdaccio installed)
  -h, --help           Show this help

Examples:
  ./npm_offline_install.sh lodash
  ./npm_offline_install.sh react@18 react-dom@18
  ./npm_offline_install.sh -n my-bundle -o /tmp/out @babel/core express
```

**`install.sh --help`**：

```
$ bash install.sh --help
Usage: install.sh [option]
  -i, --install         install requested packages locally (in CWD) after publish
  -G, --install-global  install requested packages globally after publish
      --no-install      publish only, do not install
  -h, --help            show this help
With no flag: prompt on a tty, skip on non-tty.
```

**典型打包过程（节选）**：

```
$ make npm-bundle PKG="lodash@4"
>> Resolving dependency tree for: lodash@4
>> Extracting tarball URLs
>> Downloading 1 tarballs
  [1/1] lodash-4.17.21.tgz
>> Bundling verdaccio runtime

Done.
Bundle:    /path/Tools/dist/npm-offline-bundle.tar.gz
Size:      32145678 bytes
Tarballs:  1
Packages:  lodash@4
Verdaccio: bundled
```

## 故障排查

**`Error: no tarball URLs resolved (only git/file/link deps?).`**
顶层包指向的是 git/local/link 依赖（非 npm registry tarball）。本工具只处理 http(s) tarball，git / local 依赖请改成发布过的 npm 版本号。

**`missing or empty tarball: ...`** / 中途卡死
通常是网络抖动 / `registry` 访问不稳。重跑同一命令即可（`tarballs/` 是持久缓存，已下完的不会重下）。国内可加 `-r https://registry.npmmirror.com`。

**`npm publish` 全部失败 / 大量 `EPUBLISHCONFLICT`**
- `EPUBLISHCONFLICT` / `cannot publish over` / `already exists` 是**正常的**，脚本会归类到 `skipped`，表示该版本之前已发布到本地 verdaccio。
- 如果是其他错误，看 bundle 目录下的 `.publish.log`。

**`npm publish` 报 `413 Payload Too Large` / `request entity too large`**
verdaccio 默认 `max_body_size: 10mb`，超过 10MB 的 tarball（典型场景：带 native binary 的包，如 `@anthropic-ai/claude-code-linux-x64-*.tgz` ~60MB、`esbuild-*-*.tgz`、`@swc/core-*-*.tgz`、`sharp` 等）会被拒收。注意 `npm publish` 会把 tarball **base64 编码后塞进 JSON body**（膨胀 ≈ 33% + metadata 信封），所以即便 tarball 文件 < `max_body_size`，HTTP body 仍可能越界。

本工具生成的 `install.sh` 启动时会扫描 `tarballs/` 取最大文件，按 `max(200mb, ceil(最大 tarball × 2 / MB) mb)` 动态设置 verdaccio `max_body_size`,通常无需手工干预。若仍触发 413（极端体积或自定义场景），用环境变量强抬：

```bash
VERDACCIO_MAX_BODY_SIZE=2gb ./install.sh
```

**如果你用的是系统 verdaccio（自己的 config 而不是 bundle 自带的）**，需要自己在 `~/.config/verdaccio/config.yaml`（或对应路径）顶层加一行 `max_body_size: 2gb`，否则同样会 413。

**`verdaccio is not installed and this bundle does not contain a bundled runtime.`**
打包时用了 `--no-verdaccio`，且离线机也没装 verdaccio。两条路：
1. 重新打包，去掉 `--no-verdaccio`。
2. 在能联网的机器上 `npm pack verdaccio`，把 tarball 拷到离线机 `npm install -g ./verdaccio-*.tgz`。

**`verdaccio did not become ready; see ...verdaccio.log`**
- 4873 端口被占（可能是上次 install.sh 没退干净）：`lsof -i :4873` 或 `pkill -f verdaccio`，再重跑。
- node 版本太低：verdaccio 5 要求 node ≥ 12，建议 ≥ 14。

**`./install.sh` 执行后报 "Syntax error: ... unexpected"**
被 `sh install.sh` 而不是 `bash install.sh` 调用。脚本头部已有自愈分支会 `exec bash`，如果还是报错说明系统 bash 版本太老（< 4），换台机器或 `apt install bash`。

**离线机装完报 `Error: <pkg> native binary not installed. reinstall without --ignore-scripts / --omit=optional`**
说明该包的平台 native binary 子包没装上。常见原因：
1. 在 mac 上打 bundle 给 linux 用，但跨 npm 版本 lockfile 行为漂移导致 linux 那个 optional dep 没进 bundle → **改用 `--target-os linux --target-cpu x64`（或对应平台）重新打包**，详见上面"跨平台打包"章节。
2. 离线机 `install.sh --install` 之后用户**自己又跑了一次** `npm install --ignore-scripts` 或 `--omit=optional` → 直接重新装一次：`npm install --registry=http://localhost:4873 <pkg>`（不加这两个 flag）。
3. 目标是 Alpine（musl libc）但打包时没加 `--target-libc musl` → 加上重打。

**`npm 求解很慢 / 偶尔 hang`**
正常现象。`npm install --package-lock-only --legacy-peer-deps` 在大依赖图（如 `@babel/preset-env`）上会跑几十秒到几分钟，期间无输出。耐心等。

**macOS 打的 bundle 在 Linux 解开时出现 `._*` 文件 / `install.sh` 报 `._*.tgz` FAIL**
打包脚本已对 macOS AppleDouble 元数据做了三层抑制（`COPYFILE_DISABLE=1` + `tar --exclude='._*'` + 离线侧 `find ! -name '._*'`）。如果还看到,说明用的是未 patched 的旧脚本 — 重新 `git pull` 后再打。

**macOS 打的 bundle 在 Linux 解开时大量出现 `tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'` 警告**
macOS bsdtar (libarchive) 默认会把 xattr（尤其是 Ventura+ 系统自动打的 `com.apple.provenance`）序列化进 PAX 扩展头,GNU tar 不识别就发警告(不致命,但很扰人,数量等于文件数)。打包脚本已加 `--no-xattrs` flag 抑制这一行为。如果还看到警告,说明用的是未 patched 的旧脚本——`git pull` 后重打。这是和 AppleDouble (`._*`) 独立的另一种 xattr 序列化机制,需要单独的 flag 处理。

## FAQ

**Q：为什么不直接拷 `~/.npm/_cacache`？**
跨 npm 大版本格式不兼容（npm 7 → 9 改过 cacache 布局）；且 npm install 时仍会走联网检查 metadata，离线机直接报错。本工具用 verdaccio 起一个 fake registry，npm 完全感知不到自己在离线状态。

**Q：能否打包 `devDependencies`？**
脚本传给 npm 的命令是 `npm install <pkg>...`，等价于 `--save`，只装 prod deps。需要 dev deps 把它们显式列在命令行就行（`./npm_offline_install.sh typescript ts-node @types/node`）。

**Q：bundle 的 `tarballs/` 能直接喂给 `npm install --offline` 吗？**
不行。`npm install --offline` 只查 npm 自己的 cache 目录格式，本工具的 tarball 没在那个布局里。必须走 verdaccio。

**Q：能否把多个包合并打到同一个 bundle？**
能。直接 `./npm_offline_install.sh pkg-a pkg-b @scope/pkg-c`，依赖树会合并求解，去重后打包。

**Q：`install.sh` 跑完 verdaccio 还在后台跑，能停掉吗？**
能。看上面"详细用法 → 关闭 verdaccio"或：
```bash
pkill -f verdaccio
```

## 相关链接

- 打包脚本源码：[`npm_offline_install.sh`](https://github.com/BerBai/Tools/blob/main/npm-offline/npm_offline_install.sh)
- Makefile target：[`Makefile` → `npm-bundle`](https://github.com/BerBai/Tools/blob/main/Makefile)
- 顶层 README：[`../README.md`](https://github.com/BerBai/Tools/blob/main/README.md)
- 上游依赖：
  - [verdaccio](https://verdaccio.org/) — 本地 npm registry
  - [npm CLI](https://docs.npmjs.com/cli)
