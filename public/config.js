/**
 * 站点配置（静态托管 / GitHub Pages 模式下生效）
 *
 * 想在 Pages 上开启留言（giscus，走 GitHub Discussions）：
 *   1. 仓库 Settings → General → Features 勾选 Discussions
 *   2. 安装 giscus App: https://github.com/apps/giscus
 *   3. 打开 https://giscus.app/zh-CN ，填入仓库和分类，把下面 4 个值抄进来
 * 未配置时页面只显示提示，不影响游戏试玩。
 */
window.SITE_CONFIG = {
  giscus: {
    repo: '',            // 例如 "sxguan/taptap2026"
    repoId: '',          // giscus.app 给出的 data-repo-id
    category: 'Announcements',
    categoryId: '',      // giscus.app 给出的 data-category-id
    theme: 'dark',
  },
  // 备选：直接放一个"去这里留言"的链接（如 GitHub Discussions / 问卷 / 微信群）
  feedbackUrl: '',
};
