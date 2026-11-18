# 正在开发中 / InDev

> 一个做坏了的 CRPG。

设计文档：[`docs/design.md`](docs/design.md)　资产需求：[`docs/assets.md`](docs/assets.md)

引擎：**Godot 4.7**（GL Compatibility 渲染器），GDScript。

## 运行

用 Godot 4.7 打开项目，按 F5。目前主场景会进入测试场 `sandbox`。

测试场调试键：

| 键 | 作用 |
|---|---|
| 左键 | 移动 / 点击交互 |
| Q / E，滚轮 | 旋转、缩放镜头 |
| F1 | 诗人掉出地图 |
| F2 | 随机报一个故障 |
| F3 | 主角躺着 |
| F4 | 有人问"你武器呢" |
| F5 | 重载关卡（诗人回来） |
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
```

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
- 贴图导入默认关 mipmap、不压缩。
- 大面要细分（每 2 米一段左右），否则 affine 贴图会拉扯过度。

## 文本表格约定

- `.tsv`，Tab 分隔，UTF-8。第一行表头，`#` 开头是注释。
- 同一个 key 写多行 = 多个变体，随机取一条。
- 单元格里写 `\n` 表示换行。
