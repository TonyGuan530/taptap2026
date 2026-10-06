# Miro 导出：看板 uXjVHggi_m8=

> 拉取时间：2026/10/6 18:50:18 · 共 93 条内容（按 纵向→横向 排序）
> 请把有用的想法整理进 requirements/backlog.md（每个玩法块一节，## demo-0X 开头）

### [text] @(4546,-854)

<p><strong style="color:rgb(189,10,10)">本</strong>​<strong style="color:rgb(189,10,10)">地</strong>​<strong style="color:rgb(189,10,10)">A</strong>​<strong style="color:rgb(189,10,10)">I</strong>​<strong style="color:rgb(189,10,10)">小模型</strong>​<strong style="color:rgb(189,10,10)">限于</strong>​<strong style="color:rgb(189,10,10)">浏览器性</strong>​<strong style="color:rgb(189,10,10)">能&#xff0c;</strong>​<strong style="color:rgb(189,10,10)">不</strong>​<strong style="color:rgb(189,10,10)">可</strong>​<strong style="color:rgb(189,10,10)">行</strong></p>

### [text] @(-218,-185)

<p><strong>Feedback</strong></p>

### [text] @(-218,-131)

<p>for ​AL&#xff1a;​优先​阅读 ​如果​完成​请​自己​标注​</p>

### [sticker] @(-334,-12)

<p>发现​三​个​具体​问题&#xff1a;​<br />- demo-02-v2​ 导出​错位&#xff1a;​大厅​的​物性​谜题​卡片​指向​它&#xff0c;​但​资源​包​实际​启动​的​是​ demo-06。​上表​已​使用​正确​的​旧版​入口。​<br />-​ 物性​谜题​第二​关缺​少​入口&#xff1a;​源​码定​义​了​两​关&#xff0c;​但​“下​一​关”​函数​没有​绑定​按钮&#xff1b;​实际​第一​关​通关后​也​没有​切关​按钮。​<br />- demo-07 ​元​数​据​读取​失败&#xff1a;​bu​ild.json 带 ​BOM&#xff0c;​导致​站​点​丢失​标题、​版本​和​说明&#xff0c;​游戏​仍​能​运行。​</p>

### [frame] @(0,0)

Feedback Slide

### [text] @(-334,150)

✅ AL 修复标注&#xff08;2026-10-03&#xff09;&#xff1a;
1. demo-02-v2 导出错位 → 已切 main_scene 重导&#xff0c;资源包即物性谜题 v2
2. 物性谜题第二关缺入口 → 已加「下一关」按钮&#xff08;通关后启用&#xff0c;末关变「从头再来」&#xff09;&#xff0c;L1/L2 回归 PASS
3. demo-07 元数据 BOM → 导出脚本改无 BOM 写出&#xff0c;build.json 已修复
注&#xff1a;itch 新构建部署故障持续&#xff08;CDN 占位页&#xff09;&#xff0c;平台恢复后 demo-07 自动上线&#xff0c;届时按钮修复随下次发布带出。

### [text] @(-334,280)

&#x1f534; 督导催办&#xff08;2026-10-06 09:55·FB-104 第三轮&#xff09;&#xff1a;
demo-08 用户实测反馈「折纸要有物理模拟——真的可以折纸并射出」仍未启动。
30 关风场已充分&#xff0c;暂停加关。下一轮必须开工折纸物理 spike&#xff1a;
可折纸面&#xff08;分段刚体/布料约束&#xff09;→ 玩家真实折叠 → 射出滑翔&#xff0c;折法定气动。
这是 demo-08 的核心身份&#xff08;用户原话&#xff09;。完成后走闭环标注。

### [card] @(6300,2560)

&#x1f3ae; demo-01 灵感菇侦探 · 运行画面&#xff08;点开下方链接&#xff09;

### [sticker] @(6300,2560)

&#x1f3ae; demo-01 运行画面 &#43; 录屏 ▼

### [sticker] @(642,2762)

<p>灵​感菇​侦探</p>

### [sticker] @(2974,2762)

<p>你​是​一​个​能​听到​物品​说话​的​侦探&#xff0c;​你​可以​从​犯罪​现场​场​景之​中​物品​的​只言​片​语​中&#xff0c;​尝试​还​原​案件​的​“真相”​</p>

### [sticker] @(4717,2762)

<p>叙事涌现​&amp;线索​涌​现</p>

### [sticker] @(17352,2843)

<p>场​景视角​和​风格​参考</p>

### [text] @(6300,2912)

<p>▶ demo-01 录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-01.mp4</p>

### [sticker] @(4400,4560)

&#x1f3ae; demo-05 运行画面 &#43; 录屏 ▼

### [card] @(4400,4700)

&#x1f3ae; demo-05 恐龙火山生存

### [sticker] @(2925,4773)

<p>玩家​以​现代人​的​意识​穿​越​到​白垩纪&#xff0c;​成为​一​只​体型​不大、​适应力​较​强​的​恐龙&#xff0c;​并​提前​意识​到​附近​即将​发生​毁灭性​的​火山​灾害。​游戏​采用​ 2D / UI ​驱动​的​短局​制生存策略​结构&#xff0c;​玩家​需要​在​火山​爆发前​有限​的​时间​里​探索​区域​地图&#xff0c;​判断​高地、​河谷、​森林、​洞穴、​湿地​等​不同​地形​的​风险&#xff0c;​寻找​食物、​水源、​避难​地点、​迁徙​路线​和​其他​恐龙&#xff0c;​并​将​资源​分散​储​存在​不同​地点。​火山​爆​发后&#xff0c;​地图​进入​动态​灾害​阶段&#xff1a;​风向​决定​火山​灰​扩散&#xff0c;​降雨​可能​引发泥流&#xff0c;​森林​可能​燃烧&#xff0c;​水源​可能​被​污染&#xff0c;​植物​和​猎物​逐渐​减少&#xff0c;​其他​恐龙​也​会​因为​饥饿​和​恐惧​发生​迁徙。​玩家​没有​固定​的​“正确​避难所”&#xff0c;​而​是​不断​根据​自己​之前​建立​的​资源​网络、​路线​和​群体​状态​调整​计划。​游戏​核心乐趣​来自​“提前​准备​一​个​生存​方案&#xff0c;​再​看​它​如何​在​灾难​压力​下​发生​连锁变化”。​玩家​最​终​经历​的​不​是​固定​事件​脚本&#xff0c;​而​是​一​段​由​地形、​天气、​资源​位置、​恐龙​行为​与​自身​决策​共同​形成​的​末日​故事。​单局​约​ 20~30 ​分钟&#xff0c;​目标​是​带领​自己​或​小型​恐龙​群体​离开​严重​受​灾​区域&#xff0c;​并​找到​能够​支持​长期​生存​的​新​生​态区。​</p>

### [sticker] @(642,4829)

<p>重生​之​我​是​恐龙​·学好​数理化</p>

### [text] @(4400,4892)

<p>截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-05.png 录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-05.mp4 试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;</p>

### [sticker] @(4400,5060)

&#x1f501; demo-05 v2 迭代&#xff08;2026-10-03&#xff0c;落实 ChatGPT ITERATE 三建议&#xff09;&#xff1a;
1. 区域收益×风险&#xff1a;河谷水×2/森林食×2/洞穴免灾但撤离税/高地哨兵预报准&#43;行军-1
2. 灾后应变一次&#xff1a;抢运/侦察/轻装&#xff08;灾害结算在行动后&#xff0c;能改写结局&#xff09;
3. 不完全天气预报&#xff1a;信息→判断→风险承担
headless 4 用例全 PASS&#xff08;含「抢运救局」新用例&#xff09;。itch CDN 占位页故障中&#xff0c;GitHub Pages 自动更新。

### [sticker] @(4400,5480)

&#x1f3ae; demo-05-hd2d 运行画面 &#43; 录屏 ▼

### [sticker] @(4400,5480)

&#x1f3ae; demo-05-hd2d 运行画面 &#43; 录屏 ▼

### [sticker] @(4400,5480)

&#x1f3ae; demo-05-hd2d 运行画面 &#43; 录屏 ▼

### [sticker] @(4400,5480)

&#x1f3ae; demo-05-hd2d 运行画面 &#43; 录屏 ▼

### [card] @(5400,5480)

&#x1f4e2; demo-05 HD-2D 招募&#xff1a;真人空间学习测试&#xff08;KEEP 最后 Gate&#xff09;

### [card] @(4400,5620)

&#x1f3ae; demo-05-hd2d 恐龙火山生存 HD-2D&#xff08;阶段B 建造/需求/昼夜&#xff09;

### [card] @(4400,5620)

&#x1f3ae; demo-05-hd2d 恐龙火山生存 HD-2D&#xff08;阶段B/C 建造·需求·昼夜·灰潮&#xff09;

### [card] @(4400,5620)

&#x1f3ae; demo-05-hd2d 恐龙火山生存 HD-2D&#xff08;阶段B/C 建造·需求·昼夜·灰潮·泥流·预报&#xff09;

### [card] @(4400,5620)

&#x1f3ae; demo-05-hd2d 恐龙火山生存 HD-2D&#xff08;阶段B/C 建造·需求·昼夜·灰潮·泥流·预报&#xff09;

### [text] @(5400,5620)

· 试玩&#xff08;v6&#xff09;&#xff1a;https://tonyguan530.github.io/taptap2026/builds/demo-05-hd2d-v6/index.html
· 人数&#xff1a;2-3 人 × 至少 2 个夜晚 × 死亡后重开 ≥1 次&#xff08;约 10 分钟/人&#xff09;
· 只给操作说明&#xff1a;WASD 移动 · E 交互 · Q 吃 · R 喝 · B 建造&#xff08;1/2/3 选型&#xff0c;E 放置&#xff09;· Enter 重开
· 记录单&#xff1a;https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/human-test-demo05-hd2d-template.md
· 判定&#xff1a;2/3 人在无提示下根据上一夜世界反馈主动改变建窝位置/路线 → 督导给 KEEP
· 勿剧透&#xff1a;不解释预报/灰潮/泥流机制&#xff0c;让玩家自己从世界反馈形成规则

### [sticker] @(5714,5732)

<p>修改小​说​</p>

### [text] @(4400,5780)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-05-hd2d.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-05-hd2d-v2.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-05-hd2d-v2/index.html

### [text] @(4400,5780)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-05-hd2d.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-05-hd2d.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-05-hd2d-v3/index.html

### [text] @(4400,5780)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-05-hd2d.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-05-hd2d.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-05-hd2d-v5/index.html

### [text] @(4400,5780)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-05-hd2d.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-05-hd2d.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-05-hd2d-v6/index.html

### [text] @(4400,5840)

&#x1f195; demo-02 v5 更新&#xff08;2026-10-03 深夜&#xff0c;落实 ChatGPT v4 KEEP 后指令&#xff09;&#xff1a;
① 轻量 telemetry&#xff1a;记录词条切换时机/失败重置次数/借弹簧/脆墙撞击&#xff0c;通关时结算一行「路线: 石头&#64;6.7s&#xff5c;借弹簧&#xff5c;重置0」&#xff0c;供真人试玩记录实际路线。
② 物性即时反馈层&#xff08;纯 UI/FX&#xff0c;无新系统&#xff09;&#xff1a;切换瞬间闪现「羽毛·轻 / 石头·重 / 皮球·弹」&#xff1b;撞脆板反馈「撞击 720 ≥ 450」或「还差 N」——帮玩家建立 输入→物理→结果 因果。
③ L1-L4 玩法/几何零改动&#xff0c;headless 8/8 PASS&#xff08;含 telemetry 断言&#xff09;。
试玩: https://tonyguan530.github.io/taptap2026/play.html?id&#61;demo-02 &#xff08;itch CDN 故障持续&#xff0c;Pages 为准&#xff09;

### [text] @(12270,6020)

<p><strong>核心与竞争策略</strong></p><p>亲手画出形状&#xff0c;再附上捡到的词条&#xff0c;让形状的长度、覆盖范围和接触决定工具用途。</p><p>一个精致的 5 分钟完整关卡&#xff1a;落笔 → 渡河 → 找回画页。对手已具备成熟美术与调查界面&#xff0c;本次集中独特操作体验和完整呈现。</p>

### [text] @(13520,6020)

<p><strong>关卡与多解</strong></p><p>01 钥匙&#xff1a;黏附长线抓取 / 磁性吸取 / 沉重轮廓压配重。</p><p>02 同一条河&#xff1a;漂浮闭合面承载 / 弹性开放线接木桩。</p><p>03 庭院&#xff1a;锋利线切藤 / 磁吸机关 / 闭合面挡弹。</p><p>关卡认可稳定规则的结果&#xff0c;不要求画得像预设图案。</p>

### [text] @(4400,6060)

&#x1f195; demo-02 v4 更新&#xff08;2026-10-03 晚&#xff0c;落实 ChatGPT KEEP 后指令&#xff09;&#xff1a;
① 删除通用跳跃&#xff1a;高度一律来自环境物理&#xff08;弹簧/坠落/反弹&#xff09;——听评审的&#xff0c;别做成平台跳跃。
② 羽毛扑翼削为每次滞空一次的轻量升力修正&#xff08;不可悬停&#xff09;&#xff1b;←→横移保留&#xff0c;力度仍是词条属性。
③ 新增第四关「开放解法房」&#xff1a;代码只检查 GOAL、不检查词条序列。已验证 ≥2 条独立路线&#xff08;羽毛出生直漂入右敞口 / 弹簧→羽毛→高窗口切石头砸穿脆板&#xff09;&#xff0c;皮球弹跳路线留给玩家发现。
④ 公开试玩 build&#xff08;release 导出&#xff09;已隐藏「参考解法」提示&#xff0c;开发模式仍显示。
headless 6/6 PASS&#xff08;L1-L3 回归 &#43; L4 双路线 &#43; 错误解法不误通关&#xff09;。截图/录屏已更新为 L4 路线B 演绎。
试玩: https://tonyguan530.github.io/taptap2026/play.html?id&#61;demo-02 &#xff08;itch CDN 故障持续&#xff0c;Pages 为准&#xff09;

### [frame] @(19724,6204)

灵感菇

### [text] @(4400,6300)

&#x1f195; demo-02 v3 更新&#xff08;2026-10-03&#xff09;&#xff1a;
新增跳跃输入系统&#xff1a;空格&#61;跳&#xff08;羽毛可空中扑翼&#xff09; / ←→&#61;空中横移&#xff0c;力度随词条变化。
第三关「组合测试房」&#xff1a;弹簧起飞 → 空中切羽毛横漂 → 舱顶正上方切石头砸穿舱门入舱&#xff0c;一条链用满三个词条&#xff1b;错误词条会掉坑自动重置。
headless 回归 4/4 PASS。上方卡片截图/录屏已更新为 v3&#xff08;链接不变内容即最新&#xff09;。
试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;
&#xff08;itch CDN 故障期备用镜像: https://tonyguan530.github.io/taptap2026/builds/demo-02-v3/ &#xff09;

### [sticker] @(16706,6342)

<p>角色​参考</p>

### [text] @(12270,6480)

<p><strong>手感验收</strong></p><p>即时笔迹 &#43; 起点/端点 &#43; 词条颜色。</p><p>开放线 / 闭合面显式切换&#xff0c;松开显示长度或面积与墨耗。</p><p>保留作品以便换词条&#xff1b;旋转、回收与墨泉支持试错。</p><p>接触目标有音效、机关变化与短提示。</p><p>普通键鼠验证两种渡河办法及结算。</p>

### [text] @(13520,6480)

<p><strong>美术与角色</strong></p><p>原创独游方向&#xff1a;低多边形纸雕庭院&#xff0c;奶油纸岩、青蓝墨河、深靛轮廓、珊瑚红点缀。</p><p>角色&#xff1a;大纸帽、红围巾、背墨瓶的绘画学徒&#xff0c;白纸面孔和墨点眼睛。</p><p>概念图是视觉目标&#xff1b;实机完成度以导出后的截图与试玩为准。</p>

### [sticker] @(4400,6560)

&#x1f3ae; demo-02 运行画面 &#43; 录屏 ▼

### [sticker] @(4400,6560)

&#x1f3ae; demo-02 运行画面 &#43; 录屏 ▼

### [sticker] @(4400,6560)

&#x1f3ae; demo-02 运行画面 &#43; 录屏 ▼

### [card] @(4400,6700)

&#x1f3ae; demo-02 物性变换谜题

### [card] @(4400,6700)

&#x1f3ae; demo-02 物性变换谜题

### [card] @(4400,6700)

&#x1f3ae; demo-02 物性变换谜题

### [sticker] @(671,6749)

<p>Unit-Testing</p>

### [sticker] @(2974,6787)

<p>通过​改变​物品​的​单位​/词​条&#xff0c;​改变​物体​的​物理​属性&#xff0c;​以​此​</p>

### [text] @(4400,6860)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-02.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-02.mp4
试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;

### [text] @(4400,6860)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-02.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-02.mp4
试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;

### [text] @(4400,6892)

<p>截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-02.png 录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-02.mp4 试玩: <a href="https://sxguan.itch.io/taptap2026">https://sxguan.itch.io/taptap2026</a> &#xff08;密码 taptap&#xff09;</p>

### [frame] @(12900,6900)

墨迹漂流 INKBOUND · 10/06 19:30 发布冲刺

### [sticker] @(4400,6980)

&#x1f3ae; demo-02-3d 运行画面 &#43; 录屏 ▼

### [card] @(4400,7120)

&#x1f3ae; demo-02-3d 物性变换谜题 3D&#xff08;五关齐·阶段B冻结&#xff09;

### [text] @(4400,7280)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-02-3d.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-02.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v10/index.html

### [image] @(12330,7300)

场景概念图 · 非实机截图

### [image] @(13470,7300)

画家角色设计图

### [sticker] @(5714,7509)

<p>塞尔​达式​箱庭​谜题​</p>

### [text] @(12900,7880)

<p><strong>已发布&#xff1a;V8 固定版 &#43; INKBOUND V9</strong></p><p>策划、场景概念、原创角色、纸雕场景、实时笔迹与词条多解流程已交付。</p><p>两条完整普通输入路线通过&#xff1a;弹性长线 → 切藤&#xff1b;漂浮轮廓 → 磁吸机关。短线失败保留作品&#xff0c;同一画作换词条与旋转通过。展示页包含两段带游戏音频的实机录像。</p><p><a href="https://tonyguan530.github.io/taptap2026/inkbound.html">新版小画家试玩与实机录像</a></p><p><a href="https://tonyguan530.github.io/taptap2026/tonight.html">恐龙 &#43; 画家 V8 固定历史入口</a></p><p>V9 发布提交 5988b2f&#xff1b;V8 提交 622f2a9。键鼠试玩&#xff1b;手机可浏览展示页。</p>

### [sticker] @(4400,8460)

&#x1f3ae; demo-03 运行画面 &#43; 录屏 ▼

### [card] @(4400,8600)

&#x1f3ae; demo-03 岩浆降温的小人国度

### [sticker] @(671,8669)

<p>给​岩浆​降温​的​小人​国度​</p>

### [sticker] @(2974,8669)

<p>通过​强化​/​自动化​更​强​的​浇水​/​降温&#xff0c;​来​达成​维持​温度​的​目的。​中途会​随​进度​解锁​&#xff08;涌现&#xff09;​随机N​PC​小人​</p>

### [text] @(4400,8792)

<p>截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-03.png 录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-03.mp4 试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;</p>

### [sticker] @(5714,9319)

<p>随机​系统​酸雨&#xff1a;​降雨​速度​提升&#xff0c;​植物​死亡​地​下​水​爆​发&#xff1a;​获得​大量​水​建筑​系统​初始​建筑&#xff1a;​山洞​外平​台​作为​基地、​溪流​水库&#xff1a;​储水​系统气象​台&#xff1a;​人工降雨蒸​汽​工坊&#xff1a;​蒸汽转化​为​动力八、​ 小​人​系统​黄色​小人​&#xff08;工程师&#xff09;&#xff1a;​修复​建造​白色​小人​&#xff08;搬运&#xff09;&#xff1a;​运输​速度​&#43;100%​蓝色​小人​&#xff08;气象学家&#xff09;&#xff1a;​提高​降雨概率​绿色​小人​&#xff08;植物​学家&#xff09;&#xff1a;​生态恢复​速度​提高​橙色​小人​&#xff08;探险家&#xff09;&#xff1a;​发现​隐藏物品七、​ 道​具​设计1、​主动​道​具A、​人工降雨弹​&#xff08;降雨​10秒&#xff0c;​快速​获得​水源&#xff09;B、​冰霜​&#xff08;冻结​一​片​熔岩5秒&#xff09;​C、​超级​水桶​&#xff08;一​次​携带5​倍​水量&#xff0c;​持续​20秒&#xff09;​2、​战略道​具A、​蒸汽​发动​机​&#xff08;产生​动力&#xff09;​B、​云层催化器​&#xff08;增加​自然​降雨概率&#xff09;​六、​ ​希望值​&#xff08;操纵​其他​小人&#xff09;​五、​ 三​大​资源体​系水、​蒸汽、​希望​值A、​水​来源&#xff1a;​溪流、​雨水。​用途&#xff1a;​降温。​B、​转化​水源C、​ 涌​现机制A&#xff1a;​居民​AI自​主行​为​&#xff08;打水、​浇灌、​运资源、​建造&#xff09;​例如&#xff1a;​救出​工程师​&#xff08;小黄人&#xff09;​没​路→​修桥​→​其他​居民​通过​→​运远​水→​温度​下​降​效率​提高。​B&#xff1a;​环境​连锁​反应例如&#xff1a;​岩浆​降温→形​成矿石​→探索​获得​资源C&#xff1a;​生态​恢复​降水​又​产生​更​多​资源​形成​正​反馈。​&#xff08;灌木、​丛林……&#xff09;​四、​ 核心循​环​小人​打水​&#xff08;一步骤&#xff09;&#xff1a;​水桶​→溪流→浇灌岩浆→岩浆降温→​获得​奖励​奖励​触​发​&#xff08;二步骤&#xff09;&#xff1a;​水蒸气、​气泡、​被​困​小​人​小人​加入​&#xff08;三​步骤&#xff09;&#xff1a;​山洞​出现​小人&#xff0c;​自动​帮助​打水​浇​灌岩浆​建筑​升级​&#xff08;四步骤&#xff09;&#xff1a;​获得​更​大​规模​降温​能力→​温度​下降​→​解锁​新​生态三、​ ​世界​恢复​生态二、​ 河​流​扩张​35​℃ 云层形成50℃ ​出现​少量​植物​60℃ 熔岩覆盖​世界​80℃ ​世界​变化​100℃ 游戏目标玩家​通过​不断​浇水&#xff0c;​引发​小​人们、​生态、​天气​三​套​系统​互相​作用&#xff0c;​最​终​让​世界​从​100℃恢复​到​35℃。​温度​ ​《最后​的​溪流》​玩家​创造​生态→ ​生态​产生​资源​→ ​资源​解锁​新​个​体 →​新​个​体​形成​协作​→ ​协作​改变​世界​温度。​一、​</p>

### [sticker] @(9298,9472)

<p>角色</p>

### [sticker] @(4400,10560)

&#x1f3ae; demo-04 运行画面 &#43; 录屏 ▼

### [sticker] @(6300,10560)

&#x1f3ae; demo-04-3d 运行画面 &#43; 录屏 ▼

### [card] @(4400,10700)

&#x1f3ae; demo-04 SOUP 2.0 DNA 融合逃生

### [card] @(6300,10700)

&#x1f3ae; demo-04-3d SOUP 2.0 DNA 融合逃生 3D&#xff08;v8/v9&#xff09;

### [sticker] @(671,10751)

<p>SOUP 2.0</p>

### [sticker] @(2974,10751)

<p>和​外星​生物​的​DN​A融合​改造​自身​以​逃离​危险​的​异星​</p>

### [text] @(4400,10860)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-04.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-04.mp4
试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;

### [text] @(6300,10860)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-04-3d-cdp-a.png
暗区实拍: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-04-3d-darkzone-108.png
五关通关演示片: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-04-3d.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-04-3d-v13/index.html

操作&#xff1a;WASD/方向键 · Space 跳 · E 融合 · R 重开 · Shift&#43;R 完整再跑 · K 实验房(1~5选关)/B 返回 · G 被试编号 · T 遥测导出

### [sticker] @(4400,11760)

&#x1f3ae; demo-07 运行画面 &#43; 录屏 ▼

### [card] @(4400,11900)

&#x1f3ae; demo-07 简单美食小摊&#xff08;绿幕版&#xff09;

### [text] @(4400,12092)

<p>截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-07.png 录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-07.mp4 试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;</p>

### [sticker] @(4400,12180)

&#x1f3ae; demo-07-v2 运行画面 &#43; 录屏 ▼

### [card] @(4400,12320)

&#x1f3ae; demo-07-v2 简单美食小摊 v2&#xff08;四关卡&#xff09;

### [text] @(4400,12480)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-07-v2.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-07-v2.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-07-v2/index.html

### [sticker] @(1081,13586)

<p>玩家​在​一​个​未知​世界​中​探索&#xff0c;​并​不断​发现​能够​描述​世界​性质​的​“词条”&#xff0c;​例如​ Fire、​Water、​Heavy、​Sharp、​Float、​Stic​ky、​Bo​unce、​Grow ​等。​玩家同时​拥有​有限​的​墨水&#xff0c;​可以​直接​画​出​简单图形​或​物体&#xff0c;​并​将​自己​已经​获得​的​词条​赋予​这些​涂鸦。​系统​不​会​要求​玩家​按照​固定​配方制​作道具&#xff0c;​而​是​根据​“玩家​画出​的​形状​ &#43; 词​条属性​ &#43; ​当前​环境”​生成​对​应​效果。​例如​ Fire &#43; ​圆形​可以​形成​一​颗​火球&#xff1b;​Sharp &#43;​ 长线​可能​成为​能够​切割​和​攻击​的​长刃&#xff1b;​Float ​&#43; ​大面积​平面​可以​成为​临时​漂浮​平台&#xff1b;​Heavy &#43; ​圆形​会​得到​能够​滚动、​压机关​或​撞击​敌人​的​重物&#xff1b;​Sticky &#43;​ 长线​则​可能​形成​能够​连接​两​个​物体​的​黏性​绳索。​玩家​通过​探索​获得​更​多​词条&#xff0c;​从​而​逐渐​扩大​自己​能够​创造​的​“规则​词汇”。​关卡​只​提供​目标​和​环境&#xff0c;​而​尽量​不​规定​具体​答案&#xff0c;​例如​“到达​对面”​“打开门”​“取回​高处​物品”​或​“击败​某​个​敌人”&#xff0c;​玩家​需要​利用​手里​的​词条​和​有限​墨​水​自己​构​造解决​方法。​核心循​环​是​“探索​ → ​获得​词​条 →​ 理​解词​条性​质 → ​消耗​墨水​创造​ → ​实验​组合​ → ​发现​新​的​用途”。​游戏​的​涌现​感来​自​统​一​规则​之间​的​组合&#xff0c;​而​不​是​大量​手​写​配方&#xff1a;​设计师​提供​基本性质&#xff0c;​玩家​自己​创造​工具​和​解决​方案。​</p>

### [sticker] @(4400,13660)

&#x1f3ae; demo-06 运行画面 &#43; 录屏 ▼

### [card] @(4400,13800)

&#x1f3ae; demo-06 词条涂鸦创造

### [text] @(4400,13960)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-06.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-06.mp4
试玩: https://sxguan.itch.io/taptap2026 &#xff08;密码 taptap&#xff09;

### [sticker] @(4400,14400)

&#x1f3ae; demo-06-3d 运行画面 &#43; 录屏 ▼

### [card] @(4400,14540)

&#x1f3ae; demo-06-3d 词条涂鸦创造 3D&#xff08;阶段A&#xff09;

### [text] @(4400,14700)

截图: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/shots/demo-06-3d.png
录屏: https://raw.githubusercontent.com/TonyGuan530/taptap2026/main/reviews/videos/demo-06-3d.mp4
试玩: https://tonyguan530.github.io/taptap2026/builds/demo-06-v15/index.html

### [sticker] @(1340,16707)

<p><strong><u>纸</u></strong>​<strong><u>飞机</u></strong>​<strong><u>模拟器</u></strong>​<strong><u>&#43;</u></strong>​<strong><u>肉鸽</u></strong>&#xff1a;​让​玩家折出​一​架​纸​飞机&#xff0c;​能​超过​到​终点​线算​过关。​<br />玩家​可以​自由​折​叠纸。​但是​在​不同​关卡​获得​的​纸​的​形状​不同&#xff0c;​可折​叠​次​数​不同。​<br />关​卡​间​商​店​可以​强化&#xff1a;​纸张、​玩​家力气、​以及​一些​可以​贴​在​纸飞​机​上​的​强化​物品​&#xff08;比如​螺旋桨​等&#xff09;。​<br />涌现&#xff1a;​定义​了​折纸​规则&#xff0c;​玩家​自行​发挥​折出​的​纸飞机。​</p>

### [sticker] @(1340,19600)

<p><strong><u>赛车</u></strong>​<strong><u>模</u></strong>​<strong><u>拟器</u></strong>&#xff1a;​让​玩家​自己​画​轮胎​和​车身&#xff0c;​轮胎​位​置​数量​可​自由​摆放&#xff0c;​并​让​玩家驾驶​自己​画​的​赛车​开到​终点。​<br />游戏​基于​简化​版​真实物​理​引擎&#xff0c;​因为​玩​家画​的​轮胎、​车身​不​规整&#xff0c;​所以​可能​会​开​不​了​直线​或者​颠簸&#xff0c;​可能​会​撞​上​其他​车辆。​<br />关卡​可以​做​一些​限制&#xff1a;​比如​必须​至少​装备​两​个​后轮&#xff0c;​一​个​轮胎面​积​至​多​为​X。​</p>
