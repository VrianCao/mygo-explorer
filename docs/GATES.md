# GATES — 人工复核记录

> 规则见 [TODO.md](TODO.md) §0.2：GATE 是**人工复核点**，必须由用户实际观察/操作/试用后给出结论；
> 执行者不得自行判 PASS。未通过前禁止开始下一 Phase 的实现工作。
> 结论取值：`PASS` / `FAIL` / `SKIPPED`（SKIPPED 仅当用户明确说“跳过 GATE-x”）。

---

## GATE-1 — 仓库与基线确认

- 所属 Phase：1.1.0（基线锁定与公开仓库初始化）
- 状态：**PENDING（等待用户复核）**
- 准备完成时间：2026-10-28（Asia/Shanghai）
- 证据目录：[`docs/evidence/phase-1.1.0/`](evidence/phase-1.1.0/)
- Phase 摘要：见 [`docs/evidence/phase-1.1.0/notes.md` §1](evidence/phase-1.1.0/notes.md)（13 行）
- 公开仓库：<https://github.com/VrianCao/mygo-explorer>
- 首次 CI run：<https://github.com/VrianCao/mygo-explorer/actions/runs/40538853325>（三平台全绿）
- 复核后 CI run：<https://github.com/VrianCao/mygo-explorer/actions/runs/40542634813>（全绿，artifact 含工具链日志）
- 发布基线 tag：`v0.1.0`（annotated + SSH 签名，指向 1.1.9 的 README commit；收尾证据在其后的提交中）
- 独立复核：verifier（只读、fresh context）判定 1.1.1–1.1.10 与 AC1–AC4 **全部 PASS**；
  其指出的证据/流程瑕疵已修复 6 项、记录 2 项决策（详见 notes.md §4）
- 证据刷新时间：2026-10-28（Asia/Shanghai）

### 用户需执行（约 5 分钟）

1. 打开公开仓库 URL（未登录 / 无痕窗口），确认能访问、README 可读、CI badge 绿。
2. 本地执行：
   ```sh
   cd app
   go tool mygo dev
   ```
   确认窗口标题为 `MyGo Explorer`；关闭后无残留进程
   （`pgrep -fl "MyGo Explorer|mygo dev"` 无结果）。
3. 查看 [`docs/DECISIONS.md`](DECISIONS.md)，确认：名称、identifier `dev.mygoexplorer.app`、
   module 路径 `github.com/VrianCao/mygo-explorer/app`、公开仓库、MIT、en+zh 均无异议。
4. 回答方向对齐问题（TODO §0.2.6）：**当前成果是否仍对齐项目目标（展示全部 UI/控件 + 各系统表现）？**

### 记录（用户填写）

- 日期：
- 结论：PASS / FAIL / SKIPPED
- 用户原话：
- 遗留问题：
- 下一次提交：PASS → Phase 1.2.0；FAIL → 修复本 Phase 后重新提交同一 GATE

### 自动化复核（可随时重跑）

```sh
cd app && ./scripts/check.sh                                        # CHECK PASSED
cd app && go test ./... && go tool mygo vet .                       # exit 0
gh repo view VrianCao/mygo-explorer --json visibility -q .visibility # PUBLIC
git tag -n1                                                          # v0.1.0
```
