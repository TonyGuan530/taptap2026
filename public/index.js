function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function fmtDate(iso) {
  const d = new Date(iso);
  if (isNaN(d)) return '';
  return d.toLocaleString('zh-CN', {
    year: 'numeric', month: 'numeric', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function stars(avg) {
  const n = Math.round(avg || 0);
  return '<span class="on">' + '★'.repeat(n) + '</span><span class="off">' + '★'.repeat(5 - n) + '</span>';
}

async function fetchBuilds() {
  // 优先本地 Review 服务器；没有后端（GitHub Pages 静态托管）时读 CI 生成的 builds.json
  try {
    const r = await fetch('api/builds');
    if (r.ok) {
      const builds = await r.json();
      if (Array.isArray(builds)) return { builds, static: false };
    }
  } catch (e) { /* ignore */ }
  try {
    const r2 = await fetch('builds.json');
    if (r2.ok) {
      const data = await r2.json();
      return { builds: data.builds || [], static: true };
    }
  } catch (e) { /* ignore */ }
  return { builds: [], static: false };
}

async function renderSlots(builds) {
  const box = document.getElementById('slots');
  const sec = document.getElementById('demo-sec') ? document.querySelector('.hub') : null;
  let slots = [];
  try {
    const r = await fetch('demos.json?v=' + Date.now());
    const d = await r.json();
    slots = d.slots || [];
  } catch (e) { /* 没有 demos.json 就隐藏大厅 */ }
  if (sec) sec.hidden = slots.length === 0;
  if (!slots.length) return;

  const byId = Object.fromEntries(builds.map((b) => [b.id, b]));
  box.innerHTML = '';
  const done = slots.filter((s) => s.buildId && byId[s.buildId]).length;
  const head = document.createElement('p');
  head.className = 'muted';
  head.style.cssText = 'grid-column:1/-1;margin:0 0 2px;font-size:13px';
  head.textContent = `已可玩 ${done} / ${slots.length} 块 · 计划来源：Miro 看板（需求同步到 requirements/backlog.md）`;
  box.appendChild(head);

  for (const s of slots) {
    const built = s.buildId && byId[s.buildId];
    const el = document.createElement(built ? 'a' : 'div');
    el.className = 'card slot';
    if (built) el.href = 'play.html?id=' + encodeURIComponent(s.buildId);
    const badge = built
      ? '<span class="chip ok">✅ 可玩</span>'
      : s.status === 'doing'
        ? '<span class="chip warn">🔄 开发中</span>'
        : '<span class="chip dim">🚧 待开发</span>';
    el.innerHTML = `
      <div class="card-top">
        <div class="title">${esc(s.title)}</div>
        ${badge}
      </div>
      <div class="meta">${esc(s.id)}${built ? ' · 构建 ' + esc(byId[s.buildId].version || s.buildId) : ''}</div>
      <p class="notes">${esc(s.goal || '')}</p>
      <div class="card-foot">
        ${built
          ? `<span class="stars">${stars(byId[s.buildId].avgRating)}</span>
             <span class="muted">${byId[s.buildId].avgRating ? byId[s.buildId].avgRating + ' 分 · ' : ''}${byId[s.buildId].commentCount || 0} 条反馈</span>
             <span class="btn">▶ 试玩</span>`
          : '<span class="muted">需求确认后由流水线自动开发</span>'}
      </div>`;
    box.appendChild(el);
  }
}

async function load() {
  const list = document.getElementById('builds');
  const empty = document.getElementById('empty');
  const { builds, static: staticMode } = await fetchBuilds();
  renderSlots(builds);
  list.innerHTML = '';
  empty.hidden = builds.length > 0;

  if (staticMode && builds.length) {
    const tip = document.createElement('p');
    tip.className = 'muted';
    tip.style.cssText = 'grid-column:1/-1;margin:0 0 4px;font-size:13px';
    tip.textContent = '静态托管模式：反馈请进入对应构建页面留言。';
    list.appendChild(tip);
  }

  for (const b of builds) {
    const el = document.createElement('a');
    el.className = 'card';
    el.href = 'play.html?id=' + encodeURIComponent(b.id);
    el.innerHTML = `
      <div class="card-top">
        <div class="title">${esc(b.title)}</div>
        ${b.version ? `<span class="chip">${esc(b.version)}</span>` : ''}
      </div>
      <div class="meta">${esc(fmtDate(b.date))}${b.author ? ' · ' + esc(b.author) : ''}</div>
      ${b.notes ? `<p class="notes">${esc(b.notes)}</p>` : ''}
      <div class="card-foot">
        <span class="stars">${stars(b.avgRating)}</span>
        <span class="muted">${b.avgRating ? b.avgRating + ' 分 · ' : ''}${b.commentCount || 0} 条反馈</span>
        <span class="btn">▶ 开始试玩</span>
      </div>`;
    list.appendChild(el);
  }
}

load();
