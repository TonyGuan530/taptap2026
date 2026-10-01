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

async function load() {
  const list = document.getElementById('builds');
  const empty = document.getElementById('empty');
  const { builds, static: staticMode } = await fetchBuilds();
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
