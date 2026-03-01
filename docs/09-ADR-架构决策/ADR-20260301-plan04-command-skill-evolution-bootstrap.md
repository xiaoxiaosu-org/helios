# ADR-20260301-plan04-command-skill-evolution-bootstrap: PLAN-20260301-04 Command/Skills 能力演进基线决策

## 状态
- 已采纳

---

## 背景

`PLAN-20260301-04` 引入项目级 command/skills 资产、workflow autopilot 推进能力与对应门禁联动。该变更涉及 `docs/02` 架构与治理文档，需显式记录边界与落地策略。

---

## 决策

1. 以 `.github/prompts/` 与 `.github/skills/` 作为项目级能力事实源。  
2. 以 `scripts/workflow/run.sh autopilot` + `multi-plan-autopilot.sh` 作为多计划推进统一入口。  
3. command/skills 的门禁联动要求通过 backlog 的 triggerPaths/requiredDocs 与 `workflow-sync-check` 强制执行。  
4. `gate-selftest` 正向样例必须覆盖当前 backlog rules 的 requiredDocs，防止规则升级后自测误报。

---

## 影响

### 正面影响
- 能力资产从分散复用提升为可追踪、可验证、可演进。
- 多计划推进有统一自动化入口，降低人工切换成本。

### 负面影响
- 规则数量上升，需要持续维护样例与门禁对齐。

---

## 替代方案

- 仅沉淀文档不接入脚本与门禁：无法形成可执行闭环，未采用。  
- 仅接入脚本不沉淀能力资产目录：复用与治理成本高，未采用。

---

## 版本影响

- 是否影响 API：否
- 是否影响事件模型：否
- 是否影响数据结构：是（backlog 新增计划与规则字段实例）
