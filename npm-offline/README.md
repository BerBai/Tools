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
BUNDLE_PKGS=(react@18.3.1)
```

## 环境变量

打包脚本本身**不读环境变量**，所有配置通过 CLI flag。

`install.sh` 读 2 个：

| 变量 | 默认 | 说明 |
|------|------|------|
| `REGISTRY_URL` | `http://localhost:4873` | verdaccio 监听地址。改了须保证 verdaccio 实际能在该地址起来 |
| `VERDACCIO_HOME` | `<bundle>/.verdaccio` | verdaccio 运行时数据目录（log / pid / storage） |

例：

```bash
REGISTRY_URL=http://localhost:5873 ./install.sh --install
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

**`verdaccio is not installed and this bundle does not contain a bundled runtime.`**
打包时用了 `--no-verdaccio`，且离线机也没装 verdaccio。两条路：
1. 重新打包，去掉 `--no-verdaccio`。
2. 在能联网的机器上 `npm pack verdaccio`，把 tarball 拷到离线机 `npm install -g ./verdaccio-*.tgz`。

**`verdaccio did not become ready; see ...verdaccio.log`**
- 4873 端口被占（可能是上次 install.sh 没退干净）：`lsof -i :4873` 或 `pkill -f verdaccio`，再重跑。
- node 版本太低：verdaccio 5 要求 node ≥ 12，建议 ≥ 14。

**`./install.sh` 执行后报 "Syntax error: ... unexpected"**
被 `sh install.sh` 而不是 `bash install.sh` 调用。脚本头部已有自愈分支会 `exec bash`，如果还是报错说明系统 bash 版本太老（< 4），换台机器或 `apt install bash`。

**npm 求解很慢 / 偶尔 hang**
正常现象。`npm install --package-lock-only --legacy-peer-deps` 在大依赖图（如 `@babel/preset-env`）上会跑几十秒到几分钟，期间无输出。耐心等。

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
