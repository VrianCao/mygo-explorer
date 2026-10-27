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
7. CI 骨架：三平台矩阵全绿（run 40538853325：macOS 2m03s / Linux 1m03s / Windows 2m09s）；
   复核后修订版 run 40542634813 亦全绿，artifact 内含 `ci/go-version.txt` 等工具链日志。
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
| `07-ci.log` | 两次 CI run（40538853325 首次全绿；40542634813 复核后全绿）步骤、artifact 内容与工具链日志 |
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
     （run 40542634813 已核验：`ci/go-version.txt` 在 macOS/linux/windows 三份 artifact 中均存在）。
   - `test.txt` / `vet.txt` 过薄 → 改为 `go test -count=1 -v`（含 TestView PASS）与
     `go tool mygo vet .` + `go vet ./...` 的实际输出。
8. **tag 时点（B7，决定保留）**：`v0.1.0` 指向 1.1.9 的 README commit `8f8ad51`（重写后 SHA），
   不含后续收尾证据（notes/GATES/smoke）。理由：TODO 1.1.9 的顺序即“初始提交与 tag”先于 1.1.10
   冒烟；tag 在历史重写时按同一语义重签，不另行移动。证据见 `09-readme-tag.log` 末尾。
9. **B8**：`.gitignore` 的过期注释（“app/ is created in M1”）已改为“Target app build outputs”。

## 5. 遗留问题 / 风险

- **公开仓库隐私（已处理）**：阶段 0 研究产物曾把本机 Xcode 身份邮箱
  （`research/prep/ENVIRONMENT.md` 的 `Apple Development: …`）与大量 `/Users/<user>/...` 绝对路径
  带入公开仓库（自初始 commit 起公开）。经用户选择方案 A，2026-10-28 用 `git filter-branch` 重写
  全部历史：邮箱替换为 `[redacted]`、家目录路径归一化为 `~/`，force-push `main`，并重建/重签
  `v0.1.0` tag。已核验新历史每个 commit 都不再含该邮箱或 `/Users/<user>`；逐行比对确认改动仅涉及
  17 个文件的 64 行，全部属于上述两类字符串。残留风险：GitHub 可能短期缓存不可达对象（必要时
  可联系 GitHub Support 清理），搜索引擎缓存可能滞后；重写前的 SHA 在**当前分支历史中不可达**，
  旧 CI run 仅作历史记录。**补充实测（2026-10-28）**：force-push 后 GitHub 仍会按旧 SHA 提供
  旧 commit/blob 的匿名读取（不可达对象有保留期，具体旧 SHA 不在此记录以免提供指向）；因此
  “公开历史已干净”成立，但“GitHub 侧彻底不可读”需 Support 清理或删除并重建仓库才能做到——
  该步待用户决定（见 GATES.md）。
- Windows/Linux 无本地真机运行（仅 CI 构建 + 交叉编译）；真实平台截图在 Phase 1.8.0。
- 产物未签名/未公证（无 Developer ID），dmg 仅供本地与测试；分发策略见 DECISIONS D13。
- `main.go` 仍是 `mygo init` 模板骨架（窗口 480×360），Phase 1.2.0 起替换为真实外壳。
- 占位图标 Phase 1.10.1 替换。
- CI `paths-ignore` 跳过纯文档提交（`docs/**`、`**/*.md`、`LICENSE`）：有意设计，但会让 badge 落后于 HEAD。
- 在 `/tmp` 的干净 clone 中偶发一次 `hdiutil` dmg 创建失败、重试即过（macOS 27 beta 环境偶发，
  非仓库缺陷）；`check.sh` 的 dmg 步骤对该环境敏感。

10. **历史重写（2026-10-28，用户选择方案 A）**：为移除公开历史中的个人邮箱与家目录绝对路径，
    `git filter-branch` 重写了全部 15 个 commit：邮箱 → `[redacted]`、`/Users/<user>` → `~/`；
    随后 force-push `main`，重建并重签名 `v0.1.0` tag。旧 SHA 与本文件此前的 SHA 引用已失效，
    上面已更新为重写后的 SHA；`07-ci.log` / `final-verify.log` 中记录的旧 CI run headSha 属于
    重写前历史，仅作历史记录（run URL 仍可访问）。改动范围经逐行比对确认：17 个文件 / 64 行，
    全部只涉及上述两类字符串。完成后的核验：force-push `main`（`e671c3f`）、重签 tag（对象
    `d2fd15d` → commit `8f8ad51`）；匿名完整 clone 校验 `git log -S` 对邮箱与 `/Users/<user>` 均为 0；
    重写后 CI run <https://github.com/VrianCao/mygo-explorer/actions/runs/40546689059> 三平台全绿。

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
