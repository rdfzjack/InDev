# 正在开发中 / InDev

> 一个做坏了的 CRPG。

设计文档：[`docs/design.md`](docs/design.md)　资产需求：[`docs/assets.md`](docs/assets.md)

引擎：**Godot 4.7**（GL Compatibility 渲染器），GDScript。

## 运行

用 Godot 4.7 打开项目，按 F5。从村庄开始（白模）。

当前能玩的 demo 流程：

1. **村庄**：广场上的小扬（点他入队）、西边路口等着的你老公（点他入队）、商店（老板 → 交易）、村长（任务，[游说] 检定，【洞悉】）、NPC_Villager_04、卡在墙里的鸡、北边一直锁着的魔王门（门后放着店铺 BGM，小地图上一直在闪）。村庄的 BGM 是 boss 战音乐。
2. **地窖（Dungeon 1）**：入口诗人入队并掉出地图 → 走廊隐藏陷阱（被动察觉）→ 机关房：上锁的门（开锁检定）+ 三根拉杆谜题 → 战斗 → 宝箱。
3. **营地**（村庄西边）：地窖打完后你老公约谈，那一晚他点不动；铺盖长休（4 份营地补给）→ 第二天措辞升级。

村庄西边"小路（西）"暂时通往测试场（以后是白模区和龙）。

测试场调试键：

| 键 | 作用 |
|---|---|
| 左键 | 移动 / 点击交互 |
| Q / E，滚轮 | 旋转、缩放镜头 |
| F1 | 诗人掉出地图 |
| F2 | 随机报一个故障 |
| F3 | 主角躺着 |
| F4 | 有人问"你武器呢" |
| F10 | 重载关卡（诗人回来） |
| Esc | 菜单（存档 / 读档 / 设置） |
| F5 / F9 | 快速存档 / 快速读档 |
| I | 背包（右边那个 NPC 是商店老板，点他对话 → 交易） |
| F6 | 开关老公约谈状态（约谈中点不动） |
| T | 和你老公对话 |
| F7 | 经验加到下一级门槛 |
| L | 打开升级界面（头像右上角出现金色 + 时也可以点它） |
| F8 | 立刻开战（往北走进入遭遇战范围也会开战） |

战斗中（BG3 式）：

| 操作 | 作用 |
|---|---|
| 左键点地面 | 移动（绿色路径 = 走得到，红色 = 超出移动力） |
| 左键点敌人 | 默认近战攻击，够不着先走过去 |
| 技能栏选行动 | 进入瞄准，悬停目标显示命中率 / 豁免失败率和优劣势原因 |
| 右键 | 取消瞄准 |
| 空格 / 结束按钮 | 结束回合 |

命令行测试：

```bash
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --path . res://tests/rules_test.tscn
godot --headless --path . res://tests/combat_test.tscn
godot --headless --path . res://tests/shop_test.tscn
godot --headless --path . res://tests/save_test.tscn
# 需要显示器（真实鼠标事件 / 镜头构图）：
godot --path . res://tests/input_test.tscn
godot --path . res://tests/dialogue_test.tscn
godot --path . res://tests/playthrough_test.tscn   # 村庄 → 地窖 → 营地完整流程
godot --path . res://tests/move_test.tscn          # 战斗外点击地面移动
godot --path . res://tests/reaction_test.tscn      # 反应弹窗（借机攻击、护盾术）
```

对话台本语法（条件、检定、镜头）见 `scripts/core/dialogue_script.gd` 顶部。

占位 BGM 用 `python3 tools/gen_placeholder_music.py` 生成（需要 numpy + ffmpeg），正式曲子直接覆盖 `assets/audio/music/<id>.ogg`。

关卡用 `scripts/levels/level_base.gd` 的白模工具搭（墙、房间、出口、NPC、遭遇战、旁白触发区）。美术到了把白模换成 .glb，交互节点保留。

改了 `.dlg` 对话之后，给新台词盖 ID 并导出翻译表：

```bash
godot --headless --path . --script res://tools/dlg_tool.gd
```

## 目录

```
data/                 ← 策划和文本都在这里，纯文本，可以直接改
  glitches.tsv        故障总表（每条故障：类型、触发、持续、恢复、旁白 key）
  text/narrator.tsv   旁白
  text/banter.tsv     队友反应表
  text/characters.tsv 角色显示名
  text/ui.tsv         界面文字
  dialogue/*.dlg      对话（语法见 scripts/core/dialogue_script.gd 顶部）
scripts/core/         全局系统（自动加载）
  text_db.gd          读表
  bug_bus.gd          故障广播 Bus.report(id, 谁, 位置)
  narrator.gd         旁白：先报告
  banter.gd           队友：后评论（冷却 / 优先级 / 说过标记 / 沉默权重）
  meta_stats.gd       结算统计，独立于存档；异常退出检测
  game_state.gd       队伍、剧情标记
  scene_router.gd     关卡切换 + 加载画面
data/rules/           5e 规则数据：职业、法术、武器护甲、怪物、种族、队伍升级路线（JSON）
scripts/rules/        骰子、角色卡（等级 / 兼职 / 法术位）
scripts/combat/       战斗管理器、AI、遭遇战、战斗输入、地面提示
scripts/actors/       Actor 基类、四个角色、敌人
scripts/world/        镜头、队伍控制、陷阱、门口打转、占位几何体
scripts/ui/           名牌、旁白、banter、对话框、加载画面
shaders/ps2.gdshader       Unlit + 顶点抖动 + affine UV + 最近邻
shaders/ps2_post.gdshader  15-bit 色深 + ordered dithering
assets/               美术 / 音频 / 字体（走 Git LFS）
tests/                冒烟测试、截图
```

## 渲染约定

- 内部渲染 512×384（窗口 1024×768 的一半），最近邻拉伸。UI 是全分辨率的。
- 所有 3D 材质用 `shaders/ps2.gdshader`。光照烘进贴图或顶点色。
- 贴图导入默认生成 mipmap（最近邻 + mipmap，远处不出摩尔纹）、不压缩。
- 大面要细分（每 2 米一段左右），否则 affine 贴图会拉扯过度。

## 文本表格约定

- `.tsv`，Tab 分隔，UTF-8。第一行表头，`#` 开头是注释。
- 同一个 key 写多行 = 多个变体，随机取一条。
- 单元格里写 `\n` 表示换行。
