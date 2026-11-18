# 资产需求

分工：程序和文本 → Claude；策划和美术 → 你。
这份清单按**优先级**排。占位资产先传上来能用就行，后面替换同名文件，代码不用改。

## 通用规格

### 模型

- 格式：**`.glb`**（glTF 二进制）。Blender 导出时勾选"应用修改器"，+Y 向上，单位米。
- 写实比例，low poly：
  - 主要角色 **1500–3000 三角面**
  - NPC **800–1500**
  - 道具 **50–300**
  - 场景大面**必须细分**，每 1–2 米一段，否则 affine 贴图会拉扯过度
- 原点放在**脚底中心**，正面朝 **-Z**（Blender 里朝 -Y）。
- 光照：**烘进顶点色或贴图**，游戏里不算光。顶点色会自动乘到贴图上。
- 骨骼：人形角色带骨骼和动画。骨骼命名随意，但**右手骨骼不要叫 `hand_r_socket_FINAL`**——主角的武器故意绑在这个不存在的名字上。

### 贴图

- **64×64 或 128×128**，主角色脸部最多 **256×256**。
- `.png`，不要预先做 mipmap。
- 手绘质感，明亮饱和（偏 BG3）。
- 需要透明裁剪的（树叶、贴片阴影）用 alpha，导入后会按 0.5 裁剪。

### 音频

- 音乐 `.ogg`，44.1kHz。循环曲在文件里标好循环点，或者告诉我循环起止的秒数。
- 音效 `.wav` 或 `.ogg`，单声道。

### 立绘（结局幻灯片）

- `.png`，**1024×768** 或 **4:3**。这部分**不做 PS2 风格**——结算是游戏唯一完全不坏的部分，要精致。

### 放在哪

| 类型 | 目录 | 命名 |
|---|---|---|
| 角色模型 | `assets/models/characters/` | `protagonist.glb` / `husband.glb` / `poet.glb` / `sl_lod0.glb` / `sl_lod2.glb` |
| NPC | `assets/models/npc/` | 小写英文，下划线 |
| 场景 | `assets/models/env/<区域>/` | 区域：`camp` / `village` / `dungeon1` / `dungeon2` / `whitebox` / `boss_road` |
| 道具 | `assets/models/props/` | |
| 贴图 | 和模型放一起，或者 `assets/textures/` | |
| 音乐 | `assets/audio/music/` | |
| 音效 | `assets/audio/sfx/` | |
| 字体 | `assets/fonts/` | |
| 立绘 | `assets/portraits/` | |

---

## 第一批（demo 必需，越早越好，占位也行）

1. **字体（最先要）**
   - 旁白用：一套**宋体/明朝体**（庄严文学腔）。推荐思源宋体 Noto Serif SC，OFL 许可，可商用。
   - UI 和对话用：一套黑体。推荐思源黑体 Noto Sans SC。
   - 不想挑的话告诉我，我直接用这两套。
2. **四个角色模型**
   - 主角：人类圣骑士，重甲。**一套默认装备**。待机 / 走 / 跑 / 攻击 / 躺着 / 倒地。
   - 你老公：卓尔，重甲法师，长发，黑皮。待机 / 走 / 跑 / 施法 / 攻击。
   - 诗人：人类吟游诗人。待机 / 走 / 跑 / 弹琴（施法）。
   - SL：提夫林盗贼。**要两份**：
     - `sl_lod0.glb`：正常的蓝色提夫林（近处看到的，这是"对的"那个）
     - `sl_lod2.glb`：低模版本，脸被牙齿贴图糊满，整体看起来是**红色**的（远处看到的）
     - 也可以只给一份模型加两张贴图，我在代码里换
3. **一把剑**，一把就够。主角换什么武器都挂在同一个错误的位置。
4. **头像**：四个角色各一张，128×128，用于队伍栏和对话框。
5. **村庄主街白模也可以**：先给我主街的布局（手绘俯视草图都行，标出酒馆、商店、村长家、神殿、广场、魔王门、白模区入口）。

## 第二批（demo 内容）

6. **村庄**：主街、酒馆（带门，门洞宽度刚好一个人）、商店内部、广场。**主线区域要精致。**
7. **商店老板**、**`NPC_Villager_04`**、**被害村民**、**铁匠**（碰撞体会做得很大，模型正常就行）。
8. **一只卡在墙里的鸡**：鸡头模型 + 叫声。
9. **魔王**：模型 + 登场 / 攻击 / 阶段转换 / 死亡动画。**认真做。**
10. **音乐**
    - 店铺 BGM：**30 秒短循环，要洗脑**，魔王二阶段会循环十几遍。
    - 魔王战音乐：庄严。
    - 村庄的"正确" BGM（虽然实际放的是 boss 战音乐，但还是要一首正常的，留给以后的"修复"）。
11. **结局立绘**：四个人各一张（**诗人那张不需要**，他只有名字），外加"你找到了你的真爱"那张你老公的。**必须非常真诚。**

## 第三批（完整版）

12. Dungeon 1、Dungeon 2 的房间（3–5 个房间各一套）。
13. **白模区**：就是白模，我可以自己用几何体搭。
14. **龙**：做得极其认真。多阶段动画 + **专属音乐**（只有找到这里的人会听到）。
15. 通往魔王的斜坡 + 一路的敌人。
16. 建卡界面的立绘和图标（做得很认真，结果不生效）。
17. **技能图标**（战斗系统已经做好，现在是两个字的文字占位）：64×64 PNG，放 `assets/icons/`，**文件名就是 key**，放进去自动生效：
    - 通用：`act_attack` `act_attack_ranged` `act_offhand` `act_dash` `act_disengage` `act_dodge` `act_help`
    - 特性：`act_smite` `act_second_wind` `act_action_surge` `act_lay_on_hands` `act_bardic_inspiration` `act_cunning_dash` `act_cunning_disengage`
    - 自定义：`act_lie_down`（**认真做**）、`act_load_save`
    - 法术：`spell_fire_bolt` `spell_ray_of_frost` `spell_shocking_grasp` `spell_vicious_mockery` `spell_eldritch_blast` `spell_magic_missile` `spell_shield` `spell_burning_hands` `spell_healing_word` `spell_cure_wounds` `spell_dissonant_whispers` `spell_thunderwave` `spell_bless` `spell_shield_of_faith` `spell_hex` `spell_hellish_rebuke` `spell_shatter` `spell_fireball`
18. **敌人模型**（遭遇战用）：地精（small）、狼、骷髅、僵尸、强盗、熊地精。待机 / 走 / 攻击 / 受击 / 死亡。
19. 粉红方块图标：`Item_01` 不用做，引擎自带的缺失贴图就是粉红色。
20. "炸弹"道具：图标是**面包**。
21. 加载画面背景图（如果需要）。

## 不需要你做的

- 白模、占位几何体、粉红缺失贴图：我用代码生成。
- 所有 UI 布局：我先用程序画，你之后给风格参考再换皮。
