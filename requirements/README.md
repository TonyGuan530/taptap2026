# 需求流水线：Miro → GPT → 自动开发 → 试玩验证

```
┌──────────┐   ①拉取想法    ┌──────────────┐   ②开发+导出+上传   ┌─────────────────┐
│ Miro 看板 │ ────────────▶ │ requirements/ │ ─────────────────▶ │ Review 站 + itch │
│ (成员维护) │               │  backlog.md   │   (ZCode 流水线)    │   (试玩+打分)     │
└──────────┘               └──────────────┘                     └─────────────────┘
                                 ▲                                       │
                                 │        ④GPT 按验收标准评审            │ ③玩后反馈
                                 └────────  reviews/*.md  ◀──────────────┘
                        （NEEDS_WORK → 流水线下一轮自动修，PASS → 下一块）
```

## 各文件职责

| 文件 | 作用 |
| --- | --- |
| `requirements/backlog.md` | **需求池（核心）**。每个玩法块一节，`## demo-0X` 开头；含玩法描述 + 验收标准 |
| `requirements/miro-export.md` | `tools/miro-fetch.mjs` 从 Miro 自动拉取的原始内容（人也可直接手写到这里再整理） |
| `public/demos.json` | 玩法块计划表：id/标题/状态/buildId。首页「Demo 大厅」按它渲染 |
| `reviews/` | GPT 评审报告输出目录（每次评审一个 md，PASS / NEEDS_WORK + 建议） |
| `reports/` | 流水线每轮运行报告 |

## 一次性授权（打开 Review 站 → /key 页粘贴即可）

| Key | 用途 | 去哪拿 |
| --- | --- | --- |
| Miro Token + 看板 ID | 流水线自动拉取成员想法 | miro.com → Settings → Your apps → Personal access token；看板 ID 在看板网址里 |
| OpenAI Key（可选中转地址） | GPT 按验收标准评审 demo | platform.openai.com → API keys（国内可用中转，填接口地址栏） |
| GitHub Token | 自动建仓库 + 推代码 + 开 CI | github.com → Settings → Developer settings → Fine-grained tokens（ Administration + Contents 读写） |
| itch API Key | 自动上传游戏 | 已保存 ✅ |

## 手动兜底（没有 Miro Token 也能跑）

直接编辑 `requirements/backlog.md`，把每个玩法块写清楚（一句话玩法 + 验收标准），保存即可——流水线认文件不认来源。

## 流水线每轮做什么（每 2 小时自动跑一次）

1. 同步：有 Miro Token 就拉看板内容；没有就只看 backlog 有没有变化
2. 找活：取第一个 `pending` 且有描述的玩法块
3. 开发：在 Godot 项目里实现 → `export-web.ps1` 导出 → 更新 `demos.json` → 上传 itch → git 提交
4. 评审：有 OpenAI Key 就跑 `gpt-review.mjs`；`NEEDS_WORK` 的当轮修一轮
5. 报告：写 `reports/<时间>.md`，首页大厅卡片状态自动更新

所有脚本都是零依赖 Node 18+，直接 `node tools/xxx.mjs` 可单独运行。
