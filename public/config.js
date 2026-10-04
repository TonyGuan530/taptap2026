/**
 * 站点配置（静态托管 / GitHub Pages 模式下生效）
 * giscus 走 GitHub Discussions（每版本一个评论串）；feedbackUrl 为 Issue 反馈表单兜底。
 * 已由督导 2026-10-04 配置完毕：Discussions 已开启，填表需 GitHub 账号登录。
 */
window.SITE_CONFIG = {
  giscus: {
    repo: 'TonyGuan530/taptap2026',
    repoId: 'R_kgDOU30GxQ',
    category: 'General',
    categoryId: 'DIC_kwDOU30Gxc4DG_gL',
    theme: 'dark',
  },
  // 备选：直接放一个"去这里留言"的链接（Jira 式反馈表单，督导流水线自动消化）
  feedbackUrl: 'https://github.com/TonyGuan530/taptap2026/issues/new?template=feedback.yml',
};
