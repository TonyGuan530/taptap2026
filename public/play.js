const params = new URLSearchParams(location.search);
const buildId = params.get('id');

const $title = document.getElementById('title');
const $ver = document.getElementById('ver');
const $game = document.getElementById('game');
const $comments = document.getElementById('comments');
const $ccount = document.getElementById('ccount');
const $msg = document.getElementById('msg');

let currentRating = 5;
let isStaticMode = false;

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function timeAgo(ts) {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return '刚刚';
  if (s < 3600) return `${Math.floor(s / 60)} 分钟前`;
  if (s < 86400) return `${Math.floor(s / 3600)} 小时前`;
  if (s < 86400 * 30) return `${Math.floor(s / 86400)} 天前`;
  return new Date(ts).toLocaleDateString('zh-CN');
}

function starRow(n) {
  return '<span class="cstars">' + '★'.repeat(n) + '<span style="color:#3a4152">' + '★'.repeat(5 - n) + '</span></span>';
}

// ---------- 数据加载：优先本地服务器 API，失败则进入静态模式 ----------

async function loadBuild() {
  if (!buildId) return null;
  try {
    const r = await fetch(`api/builds/${encodeURIComponent(buildId)}`);
    if (r.ok) {
      const b = await r.json();
      return { build: b, comments: b.comments || [], static: false };
    }
  } catch (e) { /* 没有后端 → 静态模式 */ }
  try {
    const r2 = await fetch('builds.json');
    if (r2.ok) {
      const data = await r2.json();
      const b = (data.builds || []).find((x) => x.id === buildId);
      if (b) return { build: b, comments: [], static: true };
    }
  } catch (e) { /* ignore */ }
  return null;
}

function renderHeader(build) {
  document.title = `${build.title} · TapTap2026`;
  $title.textContent = build.title;
  if (build.version) {
    $ver.textContent = build.version;
    $ver.hidden = false;
  }
  $game.src = `builds/${encodeURIComponent(build.id)}/index.html`;
}

function renderComments(comments) {
  if (isStaticMode) {
    // 静态模式：评论来自 giscus（如有配置），本地列表不可用
    $ccount.textContent = '';
    $comments.innerHTML = '<div class="muted" style="padding:8px 0">静态托管模式下留言见上方评论区。</div>';
    return;
  }
  $ccount.textContent = comments.length ? `（${comments.length}）` : '';
  if (!comments.length) {
    $comments.innerHTML = '<div class="muted" style="padding:8px 0">还没有反馈，来当第一个吧！</div>';
    return;
  }
  $comments.innerHTML = comments.map((c) => `
    <div class="comment">
      <div class="head">
        <span class="who">${esc(c.name)}</span>
        ${starRow(c.rating)}
        <span class="when">${esc(timeAgo(c.ts))}</span>
      </div>
      <div class="body">${esc(c.text)}</div>
    </div>`).join('');
}

function setupStaticFeedback(build) {
  isStaticMode = true;
  document.getElementById('feedback-form').hidden = true;
  document.getElementById('static-hint').hidden = false;
  const cfg = (window.SITE_CONFIG || {}).giscus || {};
  if (cfg.repo && cfg.repoId && cfg.categoryId) {
    const s = document.createElement('script');
    s.src = 'https://giscus.app/client.js';
    s.setAttribute('data-repo', cfg.repo);
    s.setAttribute('data-repo-id', cfg.repoId);
    s.setAttribute('data-category', cfg.category || 'Announcements');
    s.setAttribute('data-category-id', cfg.categoryId);
    s.setAttribute('data-mapping', 'specific');
    s.setAttribute('data-term', `feedback-${build.id}`);
    s.setAttribute('data-strict', '0');
    s.setAttribute('data-reactions-enabled', '1');
    s.setAttribute('data-emit-metadata', '0');
    s.setAttribute('data-theme', cfg.theme || 'dark');
    s.setAttribute('data-lang', 'zh-CN');
    s.setAttribute('crossorigin', 'anonymous');
    s.async = true;
    document.getElementById('giscus-box').appendChild(s);
  } else if ((window.SITE_CONFIG || {}).feedbackUrl) {
    const a = document.createElement('a');
    a.href = window.SITE_CONFIG.feedbackUrl;
    a.target = '_blank';
    a.rel = 'noopener';
    a.className = 'btn';
    a.textContent = '✍️ 去留言反馈';
    document.getElementById('giscus-box').appendChild(a);
  }
}

// ---------- 反馈表单（仅本地服务器模式） ----------

function setupForm(buildIdSafe) {
  const nameInput = document.getElementById('name');
  nameInput.value = localStorage.getItem('review-name') || '';

  const starEls = [...document.querySelectorAll('#stars .star')];
  function paint() {
    starEls.forEach((el) => el.classList.toggle('on', Number(el.dataset.v) <= currentRating));
  }
  starEls.forEach((el) =>
    el.addEventListener('click', () => {
      currentRating = Number(el.dataset.v);
      paint();
    })
  );
  paint();

  document.getElementById('submit').addEventListener('click', async () => {
    const name = nameInput.value.trim();
    const text = document.getElementById('text').value.trim();
    $msg.className = 'msg';
    $msg.textContent = '提交中…';
    if (name) localStorage.setItem('review-name', name);
    try {
      const r = await fetch(`api/builds/${encodeURIComponent(buildIdSafe)}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, rating: currentRating, text }),
      });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || '提交失败');
      $msg.className = 'msg ok';
      $msg.textContent = '✅ 感谢反馈！';
      document.getElementById('text').value = '';
      const list = await (await fetch(`api/builds/${encodeURIComponent(buildIdSafe)}`)).json();
      renderComments(list.comments || []);
    } catch (e) {
      $msg.className = 'msg err';
      $msg.textContent = '❌ ' + e.message;
    }
  });
}

// ---------- 分享 ----------

function setupShare() {
  document.getElementById('share').addEventListener('click', async () => {
    const url = location.href;
    try {
      await navigator.clipboard.writeText(url);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = url;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    const btn = document.getElementById('share');
    const old = btn.textContent;
    btn.textContent = '✅ 已复制，快发给朋友吧';
    setTimeout(() => (btn.textContent = old), 2000);
  });
}

// ---------- 启动 ----------

(async function main() {
  setupShare();
  const data = await loadBuild();
  if (!data) {
    $title.textContent = buildId ? '未找到该构建' : '缺少构建参数';
    $comments.innerHTML = `<div class="error-page"><p style="font-size:40px">🤷</p>
      <p>没有找到${buildId ? `构建 <code>${esc(buildId)}</code>` : '构建参数（链接应为 play.html?id=xxx）'}。</p>
      <p><a class="btn" href="index.html" style="margin-top:12px">← 返回列表</a></p></div>`;
    document.getElementById('game').remove();
    document.getElementById('feedback-form').hidden = true;
    return;
  }
  renderHeader(data.build);
  isStaticMode = !!data.static;
  renderComments(data.comments);
  if (isStaticMode) {
    setupStaticFeedback(data.build);
  } else {
    setupForm(data.build.id);
  }
})();

// —— 无账号快速反馈（督导 2026-10-04：复制文本模式，粘给开发组） ——
(function(){
  function buildId(){ try{ return new URLSearchParams(location.search).get('id')||'unknown'; }catch(e){ return 'unknown'; } }
  document.addEventListener('click', async (e)=>{
    if(e.target && e.target.id==='qf-copy'){
      const star=document.getElementById('qf-star')?.value||'';
      const done=document.getElementById('qf-done')?.value||'';
      const text=document.getElementById('qf-text')?.value||'';
      const txt='【试玩反馈】'+buildId()+' | '+star+' | '+done+'
'+text;
      try{ await navigator.clipboard.writeText(txt); }
      catch(err){ const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');ta.remove(); }
      const m=document.getElementById('qf-msg'); if(m) m.textContent='✅ 已复制，粘贴发给开发组即可';
    }
  });
})();