# Phase 1.1.0 — 基线锁定与公开仓库初始化 · 证据与说明

- 日期：2026-10-27 ～ 2026-10-28（Asia/Shanghai），执行者：执行 Agent（Lead）
- 范围：[TODO.md](../../TODO.md) Phase 1.1.0 的 1.1.1–1.1.10
- 结论：**10/10 Checkbox 达成，独立复核 PASS，等待用户 GATE-1 复核**（未进入 Phase 1.2.0）

## 1. Phase 摘要（≤ 15 行，供 GATE-1 使用）

1. 决策落库：`docs/DECISIONS.md`（D1–D14，含日期/来源/可改性；GATE-1 待确认清单）。
2. 应用骨架：`app/`（`mygo init -template native`），`main.go`/`main_test.go`/`go.mod`/`mygo.json`/icon/skill 齐全。
3. 版本锁定：Go `1.27.3` + `tool github.com/egoist/mygo/cmd/mygo` + `require github.com/egoist/mygo v0.7.1`；`go mod tidy` 无 diff。
4. 应用标识：`MyGo Explorer` / `dev.mygoexplorer.app` / `0.1.0`；本机打包 `.app` + dmg 成功，Info.plist 正确。
5. 仓库卫生：MIT `LICENSE`、第三方 `NOTICE`、`.gitignore`（reference/build/密钥/临时文件均命中）。
6. 公开仓库：<https://github.com/VrianCao/mygo-explorer>（PUBLIC，匿名 HTTP 200，topics/description 已设）。
7. CI 骨架：三平台矩阵全绿（最终重建仓库后 run 40554262094：macOS 2m06s / Linux 0m24s / Windows 2m07s）；
   artifact 内含 `ci/go-version.txt`（go1.27.3）等工具链日志。更早三次 run 属于原仓库，随 2026-10-28
   删除重建而失效（URL 404），历史记录保留在 `07-ci.log`。
8. 本地门禁：`app/scripts/check.sh` 5 项 PASS；故意改坏测试时 exit 1，还原后 exit 0。
9. 发布基线：最小 README + SSH 签名注释 tag `v0.1.0`（已推送），11/11 本地链接、3/3 外链可达。
10. 冒烟：`go tool mygo dev` 窗口标题 `MyGo Explorer`、几何 480×360（960×720 截图）；SIGINT 干净退出，无残留进程。
11. 独立 verifier 只读复核：1.1.1–1.1.10 与 AC1–AC4 全部 PASS；指出的证据/流程瑕疵已逐项修复（§4）。
12. 遗留：Windows/Linux 仅 CI 构建（无真机运行）；产物未签名；图标为占位图；个人邮箱与绝对路径已按用户决定重写历史清除（§5）。
13. 待用户：执行 GATE-1（见 §6），确认名称/identifier/module/公开仓库/MIT/en+zh。

## 2. 证据索引

| 文件 | 内容 |
|---|---|
| `01-init.log` | `mygo init` 命令与输出（含 flag 顺序说明） |
| `02-scaffold.log` | 生成文件清单、`go version`=go1.27.3、`go test` ok |
| `03-pin.log` | `go mod tidy` 无 diff、`go list -m`、`go tool mygo version`、GOROOT |
| `04-build.log` | `go tool mygo build` 5.9s、产物、Info.plist、codesign adhoc |
| `05-hygiene.log` | `git check-ignore -v` 8/8 命中；无密钥/build 被跟踪 |
| `06-repo.log` | `gh repo create`、visibility=PUBLIC、匿名 HTTP 200、匿名 API |
| `07-ci.log` | CI run 记录：历史 run（原仓库，URL 随重建失效）+ 最终重建后 run 40554262094（全绿，artifact 含工具链日志） |
| `08-check.log` | `check.sh` 三次运行（PASS → 故意失败 exit 1 → 还原 PASS） |
| `09-readme-tag.log` | README 链接检查（11 本地/3 外链 200）+ annotated/SSH 签名 tag `v0.1.0` 的本地与远端记录 |
| `10-smoke.log` | `go tool mygo dev` 冒烟：窗口标题/几何（稳定后 480×360）、截图、SIGINT、无残留进程 |
| `smoke.png` | 960×720 真实窗口截图（标题 `MyGo Explorer`，深色主题） |
| `test.txt` / `vet.txt` | `go test -count=1 -v ./...`（TestView PASS）/ `go tool mygo vet .` + `go vet ./...`（exit 0） |
| `final-verify.log` | 在最终 HEAD 上运行的 Phase AC1–AC4 命令与结果（工作树干净） |
| `commands.log` | 关键命令清单（便于复现） |

## 3. 验收对照（TODO Phase 1.1.0 AC）

| AC | 判定 | 证据 |
|---|---|---|
| 1. `app/` 可构建、可运行、测试通过 | PASS | `final-verify.log` CHECK PASSED；`10-smoke.log`；`test.txt` |
| 2. 公开仓库可访问，初始 commit + CI 绿 | PASS | `06-repo.log`（PUBLIC/HTTP 200）；`07-ci.log`（两次 run 三 job success） |
| 3. 版本 pin 与调研一致（go1.27.3 / mygo v0.7.1） | PASS | `03-pin.log`、`final-verify.log` |
| 4. 决策、证据、README、LICENSE、.gitignore 齐备 | PASS | `final-verify.log` 文件清单；`05-hygiene.log` |

独立复核（verifier，只读，fresh context）结论：**1.1.1–1.1.10 与 AC1–AC4 均 PASS**；
其提出的 9 项证据/流程瑕疵中，可由本 Phase 修复的 6 项已修复并重新验证（§4）。

## 4. 偏差、修复与如实记录

1. **TODO 1.1.2 的命令顺序**：原文 `mygo init -template native app -name ...` 会被 Go flag 解析拒绝
   （首个位置参数后的 flags 被当作参数 → `error: missing project directory`）。实际命令把目录放最后：
   `mygo init -template native -name "MyGo Explorer" -module github.com/VrianCao/mygo-explorer/app app`。
   见 `01-init.log`。TODO 原文未改（以 TODO 为准），此偏差在此记录。
2. **`go build ./...` 产物**：直接在 `app/` 运行会在源码旁生成名为 `app` 的二进制；`check.sh` 已把
   `-o` 指向临时目录，仓库中无该产物（曾于本地生成一次并删除，未提交）。
3. **提交粒度（如实披露）**：commit `71d3dc8`（标 1.1.7 证据）在等待 CI 期间用
   `git add -A` 一并纳入了 1.1.8 的 `app/scripts/check.sh` 与 `08-check.log`；随后 `775e44d` 的
   message 写“add app/scripts/check.sh (1.1.8)”，实际只含 TODO.md 两行改动。功能与验收不受影响。
   （2026-10-28 因隐私清理重写历史，此处为**重写后**的 SHA；语义不变。）
4. **宿主 Go 版本**：本机 host Go 为 `go1.26.4`，模块内由 `GOTOOLCHAIN=auto` 选用 `go1.27.3`
   （`GOROOT=.../toolchain@v0.0.1-go1.27.3.darwin-arm64`），未安装第二套 Go。
5. **默认决策**：`VrianCao`（仓库 owner）、`github.com/VrianCao/mygo-explorer/app`（module）、
   `dev.mygoexplorer.app`（identifier）均为默认值，待 GATE-1 确认（见 `docs/DECISIONS.md` §4）。
6. **CI 平台**：macOS runner 为 arm64、Linux/Windows 为 x64；构建产物为各 runner 本机平台。
7. **独立复核后的修复（B1/B3/B4/B5/B6）**：
   - `final-verify.log` 原先在收尾 commit 之前生成、含过期的未跟踪文件列表 → 已改为在最终 HEAD 重跑
     （工作树干净），不再自相矛盾。
   - `09-readme-tag.log` 原先只有链接检查、没有 tag 记录 → 已补 tag 的本地/远端/签名证据。
   - `10-smoke.log` 原先窗口 bounds 记录为动画中间态（320×267）→ 冒烟脚本改为等待几何稳定后
     再截图（480×360 pt / 960×720 px），并先重置 dev 窗口状态以保证可复现；重跑后 PASS。
   - CI 原先只上传构建产物 → 增加 `Write toolchain and module logs` 步骤，把
     `go version` / `go env` / `go list -m all` / `mygo version` 写入 `build/ci/` 并随 artifact 上传
     （最终重建后 run 40554262094 已核验：`ci/go-version.txt` 在 macOS/linux/windows 三份 artifact 中均存在）。
   - `test.txt` / `vet.txt` 过薄 → 改为 `go test -count=1 -v`（含 TestView PASS）与
     `go tool mygo vet .` + `go vet ./...` 的实际输出。
8. **tag 时点（B7，决定保留）**：`v0.1.0` 指向 1.1.9 的 README commit `8f8ad51`（重写后 SHA），
   不含后续收尾证据（notes/GATES/smoke）。理由：TODO 1.1.9 的顺序即“初始提交与 tag”先于 1.1.10
   冒烟；tag 在历史重写时按同一语义重签，不另行移动。证据见 `09-readme-tag.log` 末尾。
9. **B8**：`.gitignore` 的过期注释（“app/ is created in M1”）已改为“Target app build outputs”。

## 5. 遗留问题 / 风险

- **公开仓库隐私（已处理，多轮）**：阶段 0 研究产物曾把本机 Xcode 身份邮箱
  （`research/prep/ENVIRONMENT.md` 的 `Apple Development: …`）、`/Users/<user>/...` 绝对路径、
  证据日志 `ls -la` 的账号列以及三张 >6 MB 全屏截图带入公开仓库。经用户决策，2026-10-28 完成：
  ① 多轮 `git filter-branch` 重写历史（邮箱 → `[redacted]`；家目录 → `~/`；账号列 → `user`；
  三张大截图从历史移除）；② 重签 `v0.1.0`；③ 因 GitHub 保留不可达对象，**删除并同名重建**公开仓库，
  仅推入已清洗历史。验证：新历史 `git log -S` 对邮箱/家目录/账号名均为 0；无 >1 MB 图片入库；
  匿名 raw 与 clone 均干净；旧 commit API 422、旧 raw 404、旧 run URL 404。残留：搜索引擎/第三方
  缓存可能滞后；GitHub 内部备份不受本仓库控制。
- **本地隐私门禁**：根目录 `AGENTS.md`（已 gitignore，不入库）记录隐私红线与 push 前检查；
  `.git/hooks/pre-push` 在每次 push 时自动扫描已跟踪文件，命中 PII/凭据即阻断。
- Windows/Linux 无本地真机运行（仅 CI 构建 + 交叉编译）；真实平台截图在 Phase 1.8.0。
- 产物未签名/未公证（无 Developer ID），dmg 仅供本地与测试；分发策略见 DECISIONS D13。
- `main.go` 仍是 `mygo init` 模板骨架（窗口 480×360），Phase 1.2.0 起替换为真实外壳。
- 占位图标 Phase 1.10.1 替换。
- CI `paths-ignore` 跳过纯文档提交（`docs/**`、`**/*.md`、`LICENSE`）：有意设计，但会让 badge 落后于 HEAD。
- 在 `/tmp` 的干净 clone 中偶发一次 `hdiutil` dmg 创建失败、重试即过（macOS 27 beta 环境偶发，
  非仓库缺陷）；`check.sh` 的 dmg 步骤对该环境敏感。

10. **隐私清理（2026-10-28，用户决策 A → B；多轮）**：为移除公开内容中的个人标识，处理如下：
    - 第 1 轮（邮箱 + 家目录路径）：`git filter-branch --tree-filter` 重写全部历史，邮箱 → `[redacted]`、
      `/Users/<user>` → `~/`（17 文件 / 64 行，经逐行比对确认只有这两类字符串变化）；重签 `v0.1.0`。
    - 第 2 轮（本机账号名，用户追加要求）：tree-filter 把证据日志 `ls -la` 的账号列 → `user`。
    - 第 3 轮（无必要内容不 track）：`--index-filter` 把三张 >6 MB 的全屏截图从历史与跟踪中移除
      （含桌面内容且有体积负担），只保留窗口裁剪图与 `docs/evidence/.../smoke.png`（56 KB）。
    - 因 GitHub 对 force-push 后的不可达对象有保留期（实测旧 SHA 的 raw 仍可匿名读取），最终按用户
      选择 **删除并同名重建公开仓库**（最终一次 2026-10-28），仅推入已清洗历史（20 余 commits、
      `.git` 约 1 MB 级）与重签 tag；新仓库重跑 CI 全绿（run 40554262094，见 `07-ci.log`）。重建后匿名验证：旧 commit API 422、旧 SHA raw 404、
      旧 Actions run URL 404。旧 SHA/旧 run 引用已更新或标注为历史记录；具体旧 SHA 不写入仓库。

## 6. GATE-1 用户复核步骤（约 5 分钟）

1. 打开 <https://github.com/VrianCao/mygo-explorer>（未登录/无痕窗口），确认可访问、README 可读、
   三平台 CI badge 为绿。
2. 本地执行：
   ```sh
   cd app
   go tool mygo dev
   ```
   确认窗口标题为 `MyGo Explorer`；关闭窗口或 Ctrl+C 后 `pgrep -fl "MyGo Explorer|mygo dev"` 无结果。
3. 查看 `docs/DECISIONS.md`，确认名称、identifier `dev.mygoexplorer.app`、module
   `github.com/VrianCao/mygo-explorer/app`、公开仓库、MIT、en+zh 均无异议。
4. 回复「GATE-1 PASS」（或指出需修改项）。**未通过前不进入 Phase 1.2.0。**

可复核的自动化部分：
```sh
cd app && ./scripts/check.sh                       # 期望 CHECK PASSED
cd app && go test ./... && go tool mygo vet .      # 期望 exit 0
gh repo view VrianCao/mygo-explorer --json visibility -q .visibility   # 期望 PUBLIC
git tag -n1                                        # 期望 v0.1.0
```
