# TapTap2026

用 **Godot 4** 开发游戏，**浏览器里即点即玩**，配套「内部 Review + 好友试玩」的一体化工作流。

```
改代码 (game/) ──► 导出 Web 构建 (builds/<版本>/)
                      │
                      ├─► 本地 Review 站 (node server/server.js)  —— 试玩 + 评分 + 留言
                      ├─► itch.io (tools/package-itch / butler)   —— 发给朋友，无需审核
                      └─► GitHub Pages (push 后 CI 自动发布)       —— 团队远程访问备份线路
```

## 目录结构

```
├── game/                     # Godot 4 项目（含示例「点点大作战」，直接替换成你的游戏）
│   ├── project.godot
│   ├── main.gd / main.tscn
│   └── export_presets.cfg    # Web 导出预设（已配好）
├── builds/                   # 每个版本一个目录：index.html + build.json
│   └── v0.0.1-demo/          # 占位示例构建（纯网页版，用于跑通流程）
├── server/server.js          # 本地 Review 站（零依赖，Node 18+）
├── public/                   # 站点前端（列表页 + 试玩页 + 反馈表单，双模式）
├── tools/
│   ├── export-web.ps1/.sh    # 本机导出构建并注册到站点
│   ├── package-itch.ps1/.sh  # 打包 itch.io 上传用的 zip
│   ├── push-itch.ps1/.sh     # 用 butler 直接推送更新到 itch.io
│   ├── build-static.mjs      # 生成静态站点到 dist/（给 GitHub Pages）
│   └── butler/               # butler CLI（已下载，不入库）
├── data/db.json              # 玩家反馈数据（本地站，gitignore）
└── .github/workflows/deploy.yml  # CI：自动导出 → Pages → itch.io
```

---

## 一、本地 Review 站（自测最快）

双击 **`启动Review站点.bat`**（或 `node server/server.js`），打开 <http://localhost:8787>：

- 首页 = 构建列表（版本、更新说明、平均分、反馈数）
- 点「开始试玩」= 内嵌游戏 + 右侧打分留言（昵称会记住）
- 反馈存在 `data/db.json`，团队评审批次查看
- 想让同一 WiFi 的设备访问：`set HOST=0.0.0.0 && node server/server.js`
- 管理员删评论：`set ADMIN_KEY=xxx` 启动后 `DELETE /api/builds/<id>/comments/<cid>` + 头 `x-admin-key`

## 二、发布到 itch.io（推荐给朋友，无需审核）

你的页面：**https://sxguan.itch.io/taptap2026**（已建好，当前是 Restricted 密码模式，密码 `taptap`）

### 方式 A：手动上传（首次最快）

1. 运行 `tools\package-itch.ps1`（自动打包最新构建）→ 得到 `dist-itch/<版本>.zip`
2. 打开 itch 项目页 → **Edit project → Uploads** → 上传 zip
3. 勾选 **This file will be played in the browser**，Viewport 填 `960 x 540`
4. Save → 立即生效。想完全公开：Visibility 改为 Public

> 当前页面上传后如果显示 "There doesn't appear to be anything here…"，就是还没传文件，按上面步骤传 zip 即可。

### 方式 B：butler 半自动（更新只需一条命令）

1. 生成 API Key：itch.io 右上角头像 → **Settings → API Keys** → Generate new key
2. 推送（任选其一）：
   ```powershell
   $env:BUTLER_API_KEY="你的key"; .\tools\push-itch.ps1 -Version v0.0.1-demo
   # 或交互式登录一次：tools\butler\butler.exe login
   ```
3. 之后每次更新：`tools\export-web.ps1` 导出 → `tools\push-itch.ps1` 推送

> 注意：本机直连 `api.itch.io` 可能不稳定（连接被重置就重试一次）；最稳的是方式 C。

### 方式 C：CI 全自动（push 代码 → 自动导出 → 自动更新 itch + Pages）

一次性配置（GitHub 仓库网页 → Settings → Secrets and variables → Actions）：

- **Variables** 标签页：新建 `ITCH_TARGET` = `sxguan/taptap2026`
- **Secrets** 标签页：新建 `ITCH_API_KEY` = 你的 API Key

之后每次 `git push` 到 main，CI 自动：导出 Web 构建 → 发 GitHub Pages → butler 推送 itch.io。

## 三、GitHub Pages（团队远程访问的备份线路）

1. GitHub 建**公开**仓库（免费版 Pages 仅公开仓库可用）
2. 推送并启用：
   ```bash
   git config user.email "你的GitHub邮箱"   # 本仓库当前是占位邮箱 sxguan@local
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   # 仓库 Settings → Pages → Build and deployment → Source 选 "GitHub Actions"
   ```
3. 地址：`https://<用户名>.github.io/<仓库名>/`，每次 push 自动更新
4. Pages 是纯静态（没有评论后端），页面会自动切换为静态模式；想要留言：
   - 编辑 `public/config.js`，按注释配置 giscus（GitHub Discussions，需 GitHub 登录）
   - 或直接把 itch.io 链接发给朋友留言（零门槛）

> 国内访问 `github.io` 时好时坏， itch.io 一般更稳，两条线路互为备份。

---

## Godot 开发流程

1. 安装 [Godot 4.3+](https://godotengine.org/download)（标准版即可）
2. 用 Godot 打开 `game/project.godot`，把示例游戏换成你的（纯代码/场景随意）
3. 首次导出前：编辑器菜单 **Editor → Manage Export Templates** 下载模板
4. 发布新版本：
   ```powershell
   .\tools\export-web.ps1 -Version v0.0.2 -Notes "加了音效和难度曲线"
   # 刷新 Review 站点即可看到；要发 itch 再跑 tools\package-itch.ps1 或 push-itch.ps1
   ```
5. 也可只 `git push`，让 CI 帮你导出并发布到 itch + Pages

## 常见问题

- **导出失败**：多半是没装 Export Templates（见上）；或 Godot 版本与 `game/config/features` 不一致（编辑器打开项目会提示升级，点确认即可）
- **改了 Godot 版本**：同步改 `.github/workflows/deploy.yml` 里两个下载 URL（4.3-stable → 你的版本）
- **评论数据在哪**：本地站在 `data/db.json`；itch 评论在 itch 后台；Pages 静态模式在 GitHub Discussions
- **游戏加载不了**：本地站已带 COOP/COEP 头支持线程版导出；GitHub Pages 只支持单线程导出（当前预设 `variant/thread_support=false`，别开）
- **git 提交人不对**：`git config user.name "名字"`、`git config user.email "邮箱"`（当前仓库用占位邮箱提交过一次，介意的话 `git commit --amend --reset-author` 重写首提交）
