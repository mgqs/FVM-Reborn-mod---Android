# MISTAKES.md — 犯错日志（动手前先扫这里）

> **用途**：把「已经踩过的坑」变成「下次一步到位的路径」。命中症状就照「正确路径」执行，不要重新推理一遍——重推理 90% 会再踩一次。
> **维护**：每次被用户纠正、或自己发现走了错路（含浪费了一次工具调用、改错文件、验证漏做），**当场追加一条**。只写事实与证据，不写感想。
> **分级**：A = 工具与环境（活儿怎么干的错）；B = 判断与定位（找到错地方）；C = 机制与数值（改了不生效）。D = 契约与流程（自身的规矩没守）。

---

## 速查表（30 秒扫完）

| 你正要做的动作 / 看到的症状 | 立刻改成这样 | 条目 |
|---|---|---|
| 统计冲突文件的「我方改动」得到整份文件 | 取基线的 `git show` 必须在**源仓库**跑（`-C 源仓库`）；目标仓库没有源提交对象 | A40 |
| 三方合并报出「整份文件一个冲突块」 | 先看目标文件有没有 CR（CRLF 与 LF 逐行都不同）→ 归一成 LF 再 merge-file | A41 |
| 冲突标记都清了，功能却重复触发 / 又冒出裸 `mb_right` | diff3 会保留「我方改写 + 上游重写」两版 → 扫重复判定与受保护特征串，合成单块 | A42 |
| 统计「源 yyp 有、目标 yyp 没有」的纹理组恒为 0 | 源 yyp 带尾逗号、目标不带，别按整行写正则；抓 `"name":"X","resourceType":"GMTextureGroup"` | B34 |
| 合并外部 PR 改名对象后，代码能用但 IDE 资源树里找不到它 | 用新 `path` 在 `folders/**/*.yy` 反查，0 命中就按原所在文件夹补一行 `listItems` | D7 |
| 上游新敌人的卡打不到 / 子弹穿过去 | 子对象 Step 不继承父事件 → 不进 `enemy_by_type`；在每个新敌人 `Step_0` 首部补注册块（先剥注释再找 `event_inherited()`） | C33 |
| 合并来的绘制代码报 `Variable obj_x._yyy not set` | 上游循环体里定义过的局部变量没跟着搬 → `rg -n '_yyy\b'` 核对定义行在不在前面 | C34 |
| 报 `local variable yyy not set` 而不是 `Variable obj_x.yyy` | 同事件里别处写过 `var yyy` 把实例字段遮住 → 改用 `variable_instance_get(id, "yyy")` | C35 |
| 情报岛 / 地图预览里换皮立绘「完全看不见」 | 包围盒表只扫原版注册脚本 → 重跑 `tools/gen_sprite_trim.py`，`sprite_clip_draw` 加运行时兜底 | C36 |
| 想用 `Get-Content` 看 `.gml` 中文 | 用 `read` / `grep` 工具；pwsh 只用 `[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8)` | A1 |
| 想用 `Get-Content` 数行数 | 用 `read` 工具或数 LF；`Get-Content` 会把 283 行数成 171 | A2 |
| 想把多行 python 塞进 `pwsh -Command` | 写 `.py` 文件再 `python x.py`，中文加 `PYTHONIOENCODING=utf-8` | A3 |
| 要用 python 改 `.ps1`（CRLF + BOM） | 先 `if '\r\n' in s` 规范化再比较，改完跑 `verify_gml.ps1` 确认 BOM 还在 | A4 |
| 改了 `Draw_0.gml` 画面毫无变化 | 先看该对象 `.yy` 的 `eventList` 有没有 `eventType:8` —— 没有就是孤儿文件，永不执行 | B1 |
| 动画看起来播了两遍 | 先查 sprite 表里有没有重复段，别先怀疑代码重播 | B2 |
| 贴图朝向反了 | 先开 `ViewImage` 看 sprite 首帧本身朝哪边，再决定翻转 | B3 |
| 卡片待机像「一直在长大 / 帧序错乱」 | 量每帧不透明 bbox 宽度分段：生长段单调增、爆炸段橙色像素=0、待机段稳定且末帧=首帧；别拿「项目帧 vs 源帧像素一致」当帧序没问题的证据 | B14 |
| 特效一闪一闪 / 消失又出现 | 逐帧量 `(alpha>8).mean()`：末帧 0% 的是一次性脉冲，不能 loop → 加 `hold` 帧锁在常亮段 | B15 |
| 反向飞的子弹贴图「倒着飞」/ 朝向不对 | 别写 `image_xscale = -1`（父 `obj_bullet_parent/BeginStep_0` 每帧夹回 1，且 `precise_bbox_collision` 不读翻转）→ 写 `image_angle = 180`，判定框会跟着转。子弹走对象池的话还要在 Create 里 `image_angle = 0` 归零 | B25 |
| 范围光环/圈「有动画但看起来一动不动」 | 查该特效有没有被写 `xg_hold_frame`（或等价 `image_index >= N → image_speed = 0`）锁帧；定格是治「循环到淡出帧就闪」的猛药，会同时杀掉常亮段的动画。改成**只在常亮段循环** `[淡入帧数, 淡出起始帧)`，两者兼得 | B24 |
| 动态任务每局都退回「待办」/ 重复弹完成提示 | 查启动顺序：`prune` 必须排在 `sync`（动态注册）之后，且 prune 不能用 `get_task_data == undefined` 当判据 | B16 |
| 范围框 / 光环大小和技能范围对不上（还「形态越高框越小」） | 用**四角括号臂跨度**换算（每行/每列不透明像素数最多的那条）；画布尺寸和 bbox 都不行——星芒把 bbox 撑大且各形态比例不同；中心取格心 | B17 |
| 卡片击杀后掉率 / 击杀结算没触发 | 别 `instance_destroy(敌人)`；置 `ash_death = true` + `image_alpha = 0`，让 `obj_enemy_parent/Step_0:427` 走完结算 | B18 |
| 改了精灵帧/像素，游戏里没变 | 同时写 `sprites/<名>/<帧GUID>.png`（顶层合成图，运行时读它）和 `layers/<帧GUID>/<图层>.png` | B19 |
| 卡片的元素效果 / 附加状态「有时候不生效」 | 五连查：① 效果是否包在 `if (hp > 0)` 里（秒杀即跳过）② `image_xscale` 与 `visual_scale_*` 是否同值，且是否在 **Step 里每帧重设**（父 `BeginStep_0` 每帧把 `image_scale` 夹回 1，只在 `Create` 里设等于没设）③ 特效用 `image_speed=1` 时短帧是否 0.1 秒就没了 ④ 派生伤害的 `target_type` 是否跟原卡一致 ⑤ **遍历源是不是 `global.enemy_by_type`**（见 B21：重写 Step 不写 `event_inherited()` 的敌人不在表里，子弹会从它们身上飞过去） | B20 / B21 |
| 子弹「只穿透障碍、打不到老鼠」 | 别用 `global.enemy_by_type` 当命中遍历源，改 `with (obj_enemy_parent)` 全量扫描 + `can_hit` 过滤；表是敌人自己注册的，57 个重写 Step 的敌人不写 `event_inherited()`、部分根本没注册 | B21 |
| 敌人「全体无视卡片、只走路不啃」，BOSS 却正常 | 先查判活：新版运行时实例是 `ref instance`，`is_real()` 恒 false → 别用 `is_real` 当类型闸门，改 `is_undefined/is_struct/is_array/is_string/is_bool` 反排除 + `instance_exists` | C28 |
| 用户对「穿不穿透老鼠」来回改口径 | 口径只留一个开关 `ys_stop`：Create 里初始化、命中非障碍时置 true 并在死亡结算**之后** break、循环外据它销毁。别每次重写整段循环 | B26 |
| 子弹「提前一格受击」/ 打错格的老鼠 | 命中别叠 bbox 相交，只认「同行 + 同列」；敌人 `image_xscale=1.8` + 声明 bbox 全帧并集 = 1.65 格宽，出生点格心 +30 会探进上一格 8px | B22 |
| 轰炸卡「陨石砸空地、锁的那只不掉血」 | 开火条件（跨 ±N 行）、落点候选、全额目标三处必须同一套行口径；候选只收本行 + 空地兜底落点 = 永远打不到邻行目标 | B23 |
| 报「贴图缺失」 | 先查 `sprites/<n>/layers/<frame>/<layer>/png` 层级与 `frames × layers` 数量，文件通常没丢 | B4 |
| 改关卡 `rewards[0]` 却没变化 | 发奖只读 `rewards[1]`；`rewards[0]` 仅用于 `obj_battle_pause_manager/Draw_0.gml:319` 显示 | B9 |
| 改了某张卡的数值，游戏里没变 | 数值唯一源是 `scripts/mod_cards_init/mod_cards_init.gml`；`mod_slots_init` 只是卡槽显示 | B10 |
| 新增 hp/atk 类新通道后词条恒 0 且不报错 | 按「字段 / 解析 / 读取 / 挂钩」四步逐项核对（漏「解析」最典型） | C3 |
| 新卡吃不到分类增幅 | 去 `mod_apply_category_buff_map`(`card_buff_category.gml:345`) 的 `_allowed`(:367-374) 或 `plant_buff_map_2` 副类型挂名字 | C18 |
| 某张卡的增幅「一点都没吃到」，且它不在四大分组（投掷/追踪/多向/喷壶）里 | 先 `rg -n "<plant_id>" scripts/card_buff_category` 确认 `plant_buff_map` 有没有它的条目；没有就是 `mod_get_buff_type` 返回 `"normal"`、switch 落 `default`、倍率恒 1。修法只加一行 `ds_map_set(global.plant_buff_map, "<id>", "tracker")`，**不要新建 type** | C22 |
| 卡面写「打不到某类老鼠」（非主流 / 幽灵），白名单也排除了，游戏里照样命中 | 那只老鼠的 `Step_0` 会**逐帧改写** `target_type`（非主流啃食→`normal`、幽灵见光→`normal`），类型白名单不可靠。按身份判：`is_non_mainstream(_inst)`（`can_target_on.gml:79`），索敌/候选/结算/单实例入口四处统一调用 | C23 |
| 攻击间隔压小后卡不发射 | `attack_timer == cycle - N*frame` 精确等号遇小数永不成立 → 取整 cycle，或置 `uses_fire_frame = true` | C2 |
| 想给对象加自定义速度 | 名字不要叫 `speed`（内置每帧按 `direction` 自动位移）；用 `xxx_speed` 并把 `speed/hspeed/vspeed = 0` | C1 |
| 想 `json.dump` 回写关卡 JSON | 手工改文本；回写会把 `1.666667` 变科学计数，且 203/314 个文件尾带 NUL | C6 |
| 想写嵌套三元 | 老 GML 运行时不认链式三元，要整体加括号 `(a) ? 1 : ((b) ? 2 : 3)` | C7 |
| 结构体字段想叫 `pi` / 撞内置常量 | 换名（`pi_value`），否则 GM1031 或静默取到常量值 | C8 |
| 想改某张卡的 `shape` 做测试 | 实例层改会被 `obj_card_parent/Other_10` 每帧按存档重建覆盖 | C9 |
| 想「扫一遍仓库找出所有引用」 | `rg -n -F "<名字>" objects scripts datafiles`（**0.14~0.31 s**）或 `tools/lookup.ps1 <名字>`；别用 `Get-ChildItem -Recurse`（15~22 秒/次） | A11 |
| 要下 GitHub release 资产（zip/exe） | 用 `https://ghproxy.net/https://github.com/...` 前缀；直链会 `curl (56) Connection was reset` | A12 |
| 全仓 `rg` 仍要 1~2 秒 | 少了「排大目录」或「文本白名单」：同时写 `-g "!{sprites,sounds,fonts,tilesets,shaders}/**"` 和 `-g "*.gml"`，立刻降到 0.1~0.2 s | A13 |
| `git merge` / 大区间 `git diff` 在 Bash 里被 SIGTERM，或报 `index.lock: File exists` | 上千文件级别的 git 操作改用 **PowerShell 工具**跑（同一命令即可成功）；残留锁先 `Remove-Item .git\index.lock -Force` 再 `git checkout -- .` 复原 | A15 |
| 多文件补丁里有一条旧内容没命中 → 整个补丁静默不写入 | 上下文从目标文件原样复制（连已有字段一起抄全）；失败先 `git diff` 看现状，再用精确上下文重试 | A16 |
| Runtime 里比较 `draw_get_alpha()` / `shader_current()` 结果误报，或改 `.yy` 后旧编译器报字段解析错 | 先把返回值存变量再比较（别拿字面量硬比）；改 `.yy` 单字段只替换目标值，保持原格式，禁止整份重新序列化 | A17 |
| 想一次校验多个目录 | `verify_gml.ps1` **只收一个位置参数**：写 `foreach ($p in @('a','b')){ ... -File tools\verify_gml.ps1 $p }`；直传两个目录报「A positional parameter cannot be found」 | A14 |
| 改了看板首行 y / 可见行数 | 三个文件必须同改：`obj_task_bg/Create_0`（首行 y）、`obj_task_bg/Mouse_60/61`（步长与边界）、`obj_task_line_bg/Step_2`（可见上界 + `else { y = -9999 }`）；只改一个会串位或叠到可见区 | C19 |
| 动态任务（`info_view_<卡>`）导致看板/领奖报错 | `get_task_data` 可能是 `undefined`：所有 `array_length(task_data.requirements)` 前加 `if task_data == undefined continue`；Draw 里还要判 `target_task_index < array_length(current_task_list)` | C20 |
| 要判断两套素材/精灵是不是同一份（男版女版、新旧版） | 逐帧逐像素比 `tobytes()`，看「一致帧数/总帧数」（18/18 vs 3/18）；别用缩略图平均差、别信文件夹名 | B13 |
| 没装宝石 / 卸了武器，变身立绘还是照播 | 判定「这个 id 生不生效」不能只扫 `gems` 数组：先要求该槽 `id` 非空、再 `gem_fits_weapon()` 通过；`remove_weapon()` 刻意留着数组 | C21 |
| 生成/导入脚本中断后重跑 | 先清残留再跑；幂等跳过要校验「内容完整」而非「文件存在」；`open('w')` 之前先完成模板格式化（见 A18） | A18 |
| 照抄/复制对象 .yy | `spriteId` 显式指向自己的 main 精灵，别透传原版（原版龙舟/旗舰本来就指错）；自检断言 spriteId 以自身 id 开头 | A19 |
| 换皮 BOSS（新精灵 + 照抄对象代码） | ① 同组身体精灵**统一锚点**：原版同组共用 origin，逐帧算锚点会让切换 sprite_index 时身体跳动；② 照抄代码里的**对象引用也要映射**（旧 BOSS 生成旧激光体/导弹/特效），`rg "obj_[a-z_0-9]+" 新对象目录` 清单里不许再出现旧 BOSS 专属对象；③ 新素材分段以 SWF FrameLabel 为准，输出帧数必须 resample 到与原版逐精灵一致（代码里 mod N 硬编码） | A20 |
| 用户报「某只怪突然闪一下变成残血/脱甲」 | 先看血条数字有没有接近 `maxhp*hurt_rate`（没接近就与状态机无关），再用视频帧拟合「白覆盖 vs 整体透明」定位到受击闪光的画法：`obj_enemy_parent/Draw_0` 用 `hit_effect_2` 把 rgb 换成纯白再按 `flash_value/200` 叠自己 → 大体积怪会变白影 | A21 |
| 要给关卡配鼠 / 判断某只鼠能不能放这张图 | 水陆只认 `register_enemy` 的 `feature`（`water` 只能落水行，`row` 写 -1 交给引擎），别按中文名猜；单行注册是 `"feature":"land"`，正则要容带引号的键 | C24 |
| Mod 生效了但 Mod 管理器列表里没有那个包 | 界面和加载器各扫一遍目录，别只信界面那次 `file_find_first`：列表取「磁盘扫描 ∪ `global.external_mod_loaded` ∪ `global.external_mod_errors`」并集，同时把 `目录：<mod_root>` 画在界面上 | C25 |
| 战斗偶发 `Unable to find instance for object index`，栈顶是 `combat_enemy_nearest_in_row` / `combat_enemy_in_rows` | 别只查敌人的 `Destroy_0`：`obj_pool_release()` 用 `instance_change` 回收，且 97 个敌人子对象的 `Destroy_0` 没写 `event_inherited()` → 先在池回收/销毁/清池三处显式 `combat_targets_invalidate`，再让查询函数用 `combat_targets_is_live` 剪枝，再把**所有**存下来的目标改成 `with (combat_live_or_noone(x, base))`（含子弹类 16 处与快照循环 3 处），最后确认玩家跑的不是旧 APK（改完源码 ≠ 修好） | C26 |
| 修了 C26 之后**仍**崩同一句（行号 -1，落在 `combat_enemy_*` 索敌） | 别再往判活函数加判据：病根是**取数路径**（行桶快照 / 跨帧缓存）存的是 id，同帧刚死/刚被池收的追不上。敌人查询一律 `with (obj_enemy_parent)` 引擎枚举（多行就 `for` 行 + 行内过滤），缓存 `combat_row_target` 删掉 | C29 |
| 安卓上目录里明明有 Mod 包，`file_find` 枚举出来 0 个 | 安卓/iOS 的 `file_find_*` 返回**完整路径**而不是名字：一律走 `global.native_util.android_list_dir()` / `android_list_subdirs()`，不要拿条目名拼 `目录 + "/" + 名字` | A26 |
| 上一轮改的代码「凭空消失」、用户复测报「根本没这个文件」 | 先 `git reflog`：出现 `reset: moving to <sha>` 就是上游同步 `git reset --hard` 抹掉了**未提交**改动。动完立刻 `git diff > .codex-tmp/xxx.patch` 存快照或提交，别让改动以未提交状态过夜 | A27 |
| 写完 `.nomedia`，相册照样显示 Mod 图片 | `.nomedia` 只挡之后的扫描，已入库的行不会消失。把图片搬进以 `.` 开头的子目录（MediaProvider 整目录跳过）并删原文件才是确定性做法 | C27 |
| 写脚本扫 `objects/` 下所有 `.yy`，输出条数是 0 | `objects/` 没有直接放 `.yy`：用 `Get-ChildItem objects -Directory` 拼 `<目录>/<名>.yy`，或 `rg -l -g '*.yy' --pcre2 '"parentObjectId":\s*\{\s*"name":"obj_card_parent"' objects` | A23 |
| 报 `Variable obj_xxx.<字段> not set before reading it`，而父对象 `Create_0` 里明明有这个字段 | 那个子对象 `Create_0` 没写 `event_inherited()`，父 `Create` 一行没执行。读取侧一律 `variable_instance_exists(_p,"字段") && _p.字段`；需要该字段就在子对象 `Create_0` 补默认值 | A24 |
| 上游同步后某个 `.gml` 的 `os_type != os_android` 守卫「凭空消失」，编译不报错、安卓一进界面就炸 | 同步后立刻跑「HEAD 版本 vs 现值」的守卫标记比对：`git grep -l -F "os_type != os_android" HEAD` 逐文件数标记数，少了就补回 | A28 |
| 三方合并取 ours 时得到的文件里带着 `<<<<<<<`，或「ours 与 merged 字节完全相同」 | `git merge-file --diff3 <ours> <base> <theirs>` **会原地改写 `<ours>`**：调用前先把 ours 另存为 `orig__<stem>`，之后所有「取 ours」的决议都读 `orig__` 而不是 `ours__` | A29 |
| 想用 ffmpeg 从屏幕录像抽帧 / 裁一块 | 本机 ffmpeg 是裁剪版（无 image2 muxer、无 crop 滤镜），抽帧只能 WPF `MediaPlayer` + `RenderTargetBitmap`；`CroppedBitmap` 直接出图会静默 0 字节，必须全幅抓完再用 Pillow 裁；本机无网，别 `pip install` | A22 |
| 要按 §1.2 跑 `tools/verify_gml.ps1` 却报「实际参数不存在」 | **本 Android 工作区没有这个脚本**（桌面工程才有）：改用 `%TEMP%` 下的自查脚本断言「无 BOM / 无 CRLF / 括号配平」；另外 `rg` 的 `-r` 是 `--replace`，`rg -rn "词"` 会把匹配换成 n，要行号只用 `-n` | A30 |
| `git push` 报 `schannel: CRYPT_E_NO_REVOCATION_CHECK (0x80092012)` | 走代理（`127.0.0.1:51415`）时证书被替换，吊销检查必然失败：单次命令加 `-c http.sslVerify=false -c http.schannelCheckRevoke=false`，别写进 config | A31 |

### A11 用 `Get-ChildItem -Recurse` 找文件 → 每次 15~22 秒
- **症状**：一件「找一下哪些文件引用了 X」的活儿拖到几十秒；换个关键词再扫一遍，时间线性叠加。
- **实测**：`Get-ChildItem -Recurse -Filter *.gml` **15.8 s**；`-Recurse -File | Where-Object Extension -eq '.gml'` **21.7 s**；`objects` 目录树 0.5 s（规模：5990 个 `.gml` / 10 MB / 1142 对象目录）。
- **错路**：先全仓列举再筛。
- **正确路径**：**`rg`（ripgrep）限定目录** → `read` 带 `offset/limit` 只读相关段。
  - 列文件 `rg --files -g "*.gml" objects scripts` → **55~64 ms**（3966 个）
  - 全仓列 gml `rg --files -g "*.gml" -g "!{sprites,sounds,fonts}/**" .` → **162 ms**（3970 个）
  - 搜名字 `rg -n -F "<名字>" objects scripts datafiles` → **135~309 ms**
  - 全仓搜词 `rg -n -F "<词>" -g "*.gml" -g "*.json" -g "*.md" -g "!{sprites,sounds,fonts,tilesets,shaders}/**" .` → **181 ms**
  - 一次吐全部触点（卡片/敌人/关卡）用 `tools/lookup.ps1 <名字>`，内部已改走 `rg`
  - 按命名规则直接拼路径仍是 0 秒：`objects/<名>/<名>.yy`、`scripts/<名>/<名>.gml`
- **证据**：2026-11-13 实测（v13 与 15.2.0 各 3 轮）；`rg` 装在 `%LOCALAPPDATA%\fvm-tools\rg.exe` 并已进用户 PATH；`tools/lookup.ps1` 即为此而建，并于同日改为调用 `rg`。

---

### A13 全仓 `rg` 仍要 1~2 秒 → 白名单不剪枝，缺的是「排除大目录」
- **症状**：照抄 `rg --files -g "*.gml" .` 或 `rg -n -F "词" -g "!sprites/**" -g "!*.png" .`，实测 1.2~2.2 s，怀疑 rg 没装上或没生效。
- **错路**：以为 `-g "*.gml"` 会先筛目录；实际上**白名单不剪枝**——rg 必须进入 `sprites/` 的 3903 个目录逐层枚举，才能判断里面有没有 `.gml`。反过来只排大目录不加文本白名单，则会去读 `.png/.ogg/.yy/.yyp`，耗时同样在 2 s 级。
- **正确路径**：两条同时写。
  - 剪枝（省 10 倍）：`-g "!{sprites,sounds,fonts,tilesets,shaders}/**"` — 黑名单匹配到目录就不再深入。
  - 白名单（省读二进制）：`-g "*.gml" -g "*.json" -g "*.md"`。
  - 最终两条：
    - 列全部 gml → `rg --files -g "*.gml" -g "!{sprites,sounds,fonts}/**" .` **162 ms / 3970 个**
    - 全仓搜词 → `rg -n -F "<词>" -g "*.gml" -g "*.json" -g "*.md" -g "!{sprites,sounds,fonts,tilesets,shaders}/**" .` **181 ms**
  - 再者：点名目录比剔目录更快 —— `rg --files -g "*.gml" objects scripts rooms datafiles tools extensions .dsh` **104 ms**。
- **实测对照（2026-11-13，各 3 轮取最低）**：
  | 写法 | 耗时 |
  |---|---|
  | `rg --files -g "*.gml" .`（仅白名单） | 1232 ms |
  | `+ -g "!{sprites,sounds,fonts}/**"` | 162 ms |
  | 点名代码目录 | 104 ms |
  | `rg -n -F "丰饶" -g "*.gml" .`（仅白名单） | 2055 ms |
  | `rg -n -F "丰饶" -g "!sprites/**" -g "!*.png" .`（仅排除） | 2232 ms |
  | 白名单 + 排大目录 | 181~219 ms |
  | `rg -n -F "丰饶" objects scripts datafiles`（点名目录） | 154 ms |
  | 对照 `git grep -n -F "丰饶"`（跟踪文件全仓） | **16 404 ms**（Windows 上逐 blob 解压，别用） |
  | 对照 `git ls-files "*.gml"` | 108 ms（但漏未跟踪文件 5 个） |
- **证据**：同日基准脚本输出；全仓 180 165 个文件 vs `.gml` 仅 3990 个 —— 瓶颈始终是目录遍历，不是匹配。

---
| 新卡「待机动画里带着施法/张嘴姿势」「攻击姿势永远不播」 | 别靠 `ViewImage` 肉眼判断「这批帧全是待机」——去 SWF 里读 `FrameLabelTag` 定分段：`java -jar ffdec.jar -swf2xml out.xml x.swf`（绝对路径），在 `DefineSpriteTag/subTags` 里按 `ShowFrameTag` 累计帧号，看「待机 / 攻击 / 技能」各落在第几帧 | B30 |
| 「子弹比动作先出来」/ 要定攻击段里哪一帧出弹 | 段标签只给段起点：先逐帧像素差分找峰值（阴阳蛇 17→18 帧差 2960 px、右缘 77→91），再把候选帧头部裁出来放大 8~10 倍拼图看姿态；落到代码盯 `image_index`，别数固定帧 | B30 |
| 子弹过火了：伤害和倍率都对，但**看起来还是原来那颗弹** | 换贴图**不是** `bullet_hazard_fire` 干的（普通火源分支只改倍率 / 尺寸 / 音效）→ 子弹自己的 Step 里写 `if (burnt > 0 && !冰弹) { sprite_index = spr_fire_bullet; image_speed = 0; image_index = (life div 4) mod 4; 放大 1.8 }`；融盆二转冰弹让路（`brazier_list` 有 `-9999` 就跳过） | B31 |
| 新加的不占格（gridless）卡能同一格无限叠 | 去 `place_mutex_class` 加一行 `case "<card_id>": return "<类名>";`；别改 `can_place_at_position` 的 gridless 分支（`return true` 是故意的） | C30 |
| 新卡特效糊在卡片前面 / 反而看不见 | depth **越小越靠前**：卡片是 `-10-45*row-5*col-层偏移`（全在 -10~-330）→ 要压卡片之下取 `-10-45*row_min+1`，别超过 `obj_battle` 的 `+50` | C31 |
| 多边形/区域特效「糊成一个方框」，跑到边线外面 | 方形贴图按包围盒拉伸裁不出斜边（四角也带 alpha）→ 用 `draw_primitive_begin_texture(pr_trianglefan)` 自己造几何：顶点=凸包、扇心=质心、uv 走 `sprite_get_uvs` 按包围盒映射，越界处没有三角形就不会被画 | C32 |
| 编在 `waves[].subwaves[].enemy_list` 里的敌人「不出场」，`wave_ignore` 也修不好 | 看它出生高度：波次路径没有整局时间等它从天上吊下来。落点/配对 target 全交给 Step 的 `banding_target_inst == noone` 补齐块，出生高度贴近落点（`_home.y - 80`），Create 只管数据 | B27 |
| 新敌人精灵「帧数跟原版一样」但游戏里播错段（走路播成攻击 / 死亡播一半） | 父类 `obj_enemy_parent` 按 `move*2 + attack*2 + death` 索引，**段序固定五段**：正常行走 / 受伤行走 / 正常攻击 / 受伤攻击 / 死亡。帧数要按原版精灵反推每段长度，不能照 SWF FrameLabel 顺序切 | B28 |
| 商城「看不到某件商品」（如新上的某套时装） | 先算页数再怀疑数据：`shop_list_recharge` 的列表序是 `ds_map_keys_to_array` 的**哈希序**，每页 16 个 → 178 件时装 = 12 页，同批写入的会被打散。先核对 `goods_map` 与 `attire_pool` 条数是否相等 | B29 |
| 想用 PowerShell 管道生成 `git` 补丁 | `git diff ... | Out-File` 会写 UTF-16/BOM 并改写行尾 → `git apply` 报 `No valid patches in input`（exit 128）。用 `cmd /c "cd /d SRC && git --no-pager diff A B -- path > D:\tmp\x.patch"`，再在目标仓库 `git apply --recount --whitespace=nowarn` | A36 |
| 上游有改动、本地有安卓嫁接的「冲突文件」怎么合 | 别整份覆盖也别手抄：`git show`/`diff` 出**单文件**上游补丁 → `git apply --recount` 打到安卓版上（本次 5 个冲突全部 exit=0），落地后再用断言脚本核对嫁接串是否还在 | A37 |
| 用正则读 `.yy` 里的 `textureGroupId` 判纹理组，7 个精灵被报「未分组」 | 别假设冒号后紧贴 `{`：GMS 两种排版都有（`"textureGroupId":{` 与 `"textureGroupId": {`）。正则用 `"textureGroupId"\s*:\s*\{[^{}]*?"name"\s*:\s*"([^"]+)"` 加 `re.S`，并且写成 `.py` 读文件（`pwsh` 里拼含引号的 `rg` 会静默返回空行） | A38 |
| 断言脚本报「函数没被调用」，实际明明调用了 | 断言别按 `f()` 空参匹配：带实参的调用（`craft_help_draw(craft_help_ok_hover)`）与定义（`function craft_help_draw(_hover)`）都不含 `f()`。用 `f(` 或只写函数名 | A39 |
| 统计「谁继承了某对象」得到 0 / 某事件查不到 | `.yy` 是跨行 JSON，匹配前先 `replace('\n','')` 或用 `re.S`；凡是「0 / 空 / 全缺失」这种反常却干净的结论，换一种写法复核一次再动手 | B32 |
| 点某个按钮却跳到别的页 / 叠层 UI 抢点击 | GMS 的 Mouse 事件**先于** Step 执行，depth 只影响绘制顺序、不影响谁收到点击；抄旧面板版式做新面板时，先给旧面板的按钮加上「新面板存在就 exit」的守卫 | B33 |
| 合并外部 PR 后 IDE 解析报错、资源树丢项，但 yyp 的 resources/Folders 逐条都对得上 | `folders/**/*.yy` 要逐个 `json` 解析（先 `re.sub(r',(\s*[}\]])', r'\1', s)` 去尾逗号，用 `utf-8-sig` 读），解析失败必须打印，不能 `except: continue` 静默跳过 | D6 |
| 全服设备的「随机」标识都一样（识别码 / install.id / 任何落盘指纹） | 本工程**从未 `randomize()`**，`irandom` 序列每次启动相同 → 改用 `auth_random_hex()`（多熵源 md5），且**换文件名 + 拉黑旧值**，否则老文件被原样沿用等于没修；`random_set_seed` 还原要放在 try 外面 | C37 |

## A. 工具与环境

### A1 `pwsh Get-Content` 读中文 `.gml` → GBK 乱码
- **症状**：输出 `娉℃鏄ョ瑡`；或 grep 明明存在的字搜不到。
- **错路**：为了省事用 `Get-Content` 直接看文件。
- **正确路径**：用 `read` / `grep` 工具；必须走 pwsh 时用 `[System.IO.File]::ReadAllText($p,[Text.Encoding]::UTF8)`。无例外。
- **证据**：`AGENTS.md` §0；本次契约勘察首日即撞。

### A2 `pwsh Get-Content` 数行数 → 数错
- **症状**：`(Get-Content x).Count` 得 171，而文件真是 283 行。
- **根因**：多字节内容下按管道解码后行边界被吞。
- **正确路径**：用 `read` 工具的行号，或 `[IO.File]::ReadAllText(...) -split "`n"` 数 LF。
- **证据**：2026-11-13 盲测 A 的实测对比（283 vs 171）。

### A3 多行 python 塞进 `pwsh -Command` → ParserError
- **症状**：`ParserError: 字符串缺少终止符`，脚本根本没跑。
- **正确路径**：`write` 一个 `.py` 文件 → `python .workbuddy\tmp\x.py`；中文输出设 `$env:PYTHONIOENCODING='utf-8'`，或写文件后用 `read` 看。
- **证据**：2026-11-13 批量改 AGENTS.md 时反复撞。

### A4 用 python 改 `.ps1`（CRLF + BOM）断言失败
- **症状**：`AssertionError: quiet block not found`，明明字符串就在文件里。
- **根因**：文件是 CRLF，待查串是 LF 写的，`old in s` 恒 false。
- **正确路径**：`if '\r\n' in s:` 先规范化（`s.replace('\r\n','\n')` 比对，写回时还原 CRLF），改完跑 `verify_gml.ps1` 确认 BOM 还在。
- **证据**：`tools/check_contract.ps1` 的 `-Quiet` 格式修正（patch6）。

### A5 新建 `.ps1` 忘 BOM
- **症状**：pwsh 5.1 下中文注释变乱码；`verify_gml.ps1` 报 FAIL。
- **正确路径**：`.ps1` 一律 `New-Object System.Text.UTF8Encoding($true)`；其它文件一律 `$false`。
- **证据**：`AGENTS.md` §1.1；`tools/check_contract.ps1` 建档时已按带 BOM 写。

### A6 逐条 `edit` 改 `AGENTS.md` → 上下文被全文注入冲爆
- **症状**：每改一次，下一轮就收到一份 37 KB 的 system-reminder 全文。
- **正确路径**：把多处改动攒成**一个** python patch 脚本，跑一次；跑完立刻 `verify_gml.ps1`。
- **证据**：2026-11-13 前三次 patch 的教训。

### A7 临时脚本散落仓库根 / `tools/` → git status 噪声
- **症状**：`git status` 里一堆 `_tmp_*.py`、`_tmp_xlsx_dump.txt`、`tools/_tmp_probe*.py`。
- **正确路径**：临时件一律放 `.workbuddy/tmp/`（已被 `.gitignore:64` 忽略），用完删；**不要**落 `tools/`。
- **证据**：2026-11-13 交付时 `git status` 实际输出。

### A8 `.yy` 用 `encoding='utf-8'` 读 → 误判「yy 损坏」
- **症状**：`json.load` 抛 `Unexpected UTF-8 BOM`，看着像文件坏了。
- **根因**：新建的 5 个 sprite `.yy` 带 BOM。
- **正确路径**：读 `.yy` 一律 `encoding='utf-8-sig'`；写回按 §1.1 用无 BOM。
- **证据**：2026-11-04 日志（`honglonglong_icon/idle/laser`、`infected_bingzha_ball/fire_ball`）。

### A9 yyp 一致性脚本按 `.gml` 拼 scripts 路径 → 假报大量缺失
- **症状**：脚本报 268 条 scripts 未注册，实际全在。
- **根因**：`.yyp` 里 scripts 也登记 `.yy` 后缀。
- **正确路径**：一致性核对统一按 `.yy` 拼路径。
- **证据**：2026-11-02 日志。

### A10 正则批量改表格误伤同形列
- **症状**：重排词条编号时 14 条银级「叠」列数字被改。
- **正确路径**：锚定行首 `(?m)^\| \d+ \|`，改完抽样核对非目标列。
- **证据**：2026-10-26 日志。

### A12 直接用 GitHub release 直链下载 → `curl: (56) Recv failure: Connection was reset`，得到 0 字节文件
- **症状**：`curl -L -o x.zip https://github.com/.../releases/download/...` 返回 exit 56，文件不存在或 0 B；但 `api.github.com` 能正常取 JSON。
- **错路**：先试官方直链（`objects.githubusercontent.com` 被重置），失败后才想起镜像；`Invoke-WebRequest` 结果一样。
- **正确路径**：下载 GitHub release 资产时**直接用镜像前缀**，一次成功：
  `curl -L --fail --silent -o out.zip "https://ghproxy.net/https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>"`
  （`gh-proxy.com` / `mirror.ghproxy.com` 为备选；资产名先用 `https://api.github.com/repos/<owner>/<repo>/releases/latest` 查 `assets[].browser_download_url`，API 本身是通的）
  下载后必查字节数 > 预期值再解压，避免拿 0 B 文件去 `Expand-Archive`。
- **证据**：2026-11-13 装 ripgrep 15.2.0 时实测：直链 RST / `ghproxy.net` 前缀 1 789 611 B 成功。

### A14 `verify_gml.ps1` 直传多个目录 → 位置参数报错
- **症状**：`verify_gml.ps1 a b c` 输出 `A positional parameter cannot be found that accepts argument 'b'`，exit 1，一个文件都没校验。
- **错路**：以为能像 `rg` 一样吃多个路径，结果整批改动没校验就往下走了。
- **正确路径**：一次一个路径，要批量就循环：
  `foreach ($p in @('objects\obj_task_bg','scripts\task_edit')) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\verify_gml.ps1 $p }`
  然后 `if ($o -match '失败 [1-9]')` 判失败，别只看最后一行。
- **证据**：2026-11-13 实施卡片情报任务时实测。

### A15 Bash 工具里跑上千文件的 `git merge` / `git diff` → SIGTERM 中断 + 残留 `.git/index.lock`
- **症状**：Bash 工具执行 `git merge --ff-only pr39`、`git diff --name-status <大区间> pr39` 被 `SIGTERM` 杀掉（exit 1、无输出），HEAD 不动但工作区已被删掉一批文件（`git status` 一片 `D`）；随后任何 git 写操作报 `fatal: Unable to create '.git/index.lock': File exists`。
- **错路**：以为命令本身出错反复重跑（撞锁）；`git diff` 加 `--no-renames` 后仍被杀；用 `core.renameLimit` 调参无效。
- **正确路径**：
  1. **上千文件的 git 操作（merge / reset / checkout / 大区间 diff）走 PowerShell 工具**，同一命令（`git merge --no-ff pr39 -F msg.txt`）一次成功。
  2. 中断后先判活：`Get-Process -Name git` 无进程 → `Remove-Item .git\index.lock -Force`；再查 `.git\MERGE_HEAD` / `.git\rebase-merge` 是否存在。
  3. 工作区被中途删文件：`git checkout -- .` 复原（`git status` 的 `D` 不是真实删除）。
  4. 合并提交的中文信息用 `Write` 写 UTF-8 文件 + `git merge -F`，别用 `-m` 直接传中文（PowerShell 控制台按 GBK 解码会显示乱码，虽未必写坏）。
- **证据**：2026-11-13 合并 PR39（1825 文件）时实测：Bash 两次 SIGTERM，PowerShell 一次成功。

---

### A16 多文件补丁上下文不完整导致整体校验失败
- **症状**：补丁没有命中 CHANGELOG 原有条目，整个补丁未写入。
- **错路**：手抄上下文时遗漏已有的 `hitted` 字段。
- **正确路径**：从目标文件复制完整上下文；失败后先检查 `git diff`，再用精确上下文重试。
- **证据**：2026-11-13 纹理驻留改动，`CHANGELOG.md` 的元素蛇修复条目。

### A17 GameMaker Runtime 临时检查的取值与资源格式
- **症状**：直接用 `0.5` 比较绘制 Alpha 导致误报；为修改纹理页尺寸重新序列化选项文件，触发旧编译器的字段解析错误。
- **正确路径**：保存 `draw_get_alpha()` / `shader_current()` 实际返回值再比较；单字段修改保持原 `.yy` 格式，只替换目标值。
- **证据**：2026-11-13 `.macos-build/texture-residency-check/`；修正检查方式后 69 项 Runtime 检查通过。

### A36 `git diff` 经 PowerShell 管道落成补丁 → `git apply` 报 `No valid patches in input`
- **症状**：`git --no-pager diff A B -- file | Out-File -Encoding utf8 x.patch` 生成的文件，
  在另一个仓库 `git apply` 时 5 个补丁全部 exit=128，报
  `error: No valid patches in input (allow with "--allow-empty")`。
- **错路**：以为是路径前缀问题，先后试了 `-p1` / `--recount` / 去 BOM（`utf-8-sig` 重写）都没用 ——
  文件本身已经不是补丁了：`Out-File` 会把 LF 改写成 CRLF、并可能插入 BOM 与换行折叠，
  `--- a/...`/`+++ b/...` 之外的行首 `+/-/空格` 语义被破坏。
- **正确路径**：让 `git` 自己重定向 —— `cmd /c "cd /d <源仓库> && git --no-pager diff <A> <B> -- <file> > D:\tmp\anpatch\x.patch"`，
  再在目标仓库 `git apply --recount --whitespace=nowarn D:\tmp\anpatch\x.patch`。
  本次 5 个冲突文件（craft_bg/readyroom/zodiac/game_init/external_mod_system）全部 exit=0。
- **证据**：2026-11-18 日志、`D:\tmp\anpatch\*.patch`。

### A37 上游有改动 + 本地有安卓嫁接的「冲突文件」→ 打单文件补丁，别整份覆盖也别手抄
- **症状**：同步时 8 个冲突文件里，5 个是「上游改了 1~25 行、安卓在其它位置有受保护嫁接」。
  整份取上游会丢嫁接（双指滑动块、`combat_targets_is_live` 判活、授权启动块、安卓 Mod 层），
  手抄又要逐个记住嫁接位置。
- **正确路径**：按文件出上游单文件补丁（见 A36 的生成方式）→ 在目标仓库 `git apply --recount`；
  因为上游 hunk 与嫁接块不在同一区域，普通 apply 就能干净落地。落地后立刻跑断言脚本核对嫁接串
  （本次核对 `craft_slot_table()` / `_two_n` / `panel_anim_end_parts(id, craft_parts, 260)` /
  `cross_server_coin_mult()` / `_ronghe_ice` / `combat_targets_is_live(e, obj_enemy_parent)` /
  `land_air_ug` + 安卓 `external_mod_*` 层 / `auth_gate_force` + `obj_mobile_buttons`），全部命中。
- **证据**：`.codex-tmp/an_sync.py`、`.codex-tmp/an_ref.py`、2026-11-18 日志。

### A40 三方合并的 base 用 `git -C 目标仓库 show <源提交>:<路径>` → 取到空串，整份文件都算「我方改动」
- **症状**：统计 27 个冲突文件的「目标自有改动行数」时，每个文件都报「基线=0 字节、目标自有改动 = 整份文件行数」，
  完全无法判断嫁接点在哪。
- **错路**：以为是文件里的 CRLF 或 BOM 让 `git show` 失败，去查编码、查换行。
- **正确路径**：`1e844c591c` 这类提交只存在于**源仓库** `D:\gameProject\FVM-Reborn-mod`，目标 Android 仓库里没有这个对象，
  `git -C <目标仓库> show 1e844c591c:path` 只会静默输出空串。取基线必须 `git -C <源仓库> show <提交>:<路径>`。
- **证据**：2026-11-22；`.codex-tmp/an_own4.py` 首跑 `尺寸 基线=0`，`.codex-tmp/an_merge4.py` 改用 `-C SRC` 后正常。

### A41 三方合并前不归一 CRLF → 整份文件被判成 1807 行全冲突
- **症状**：`git merge-file` 对 `objects/obj_player_shield/Step_0.gml` 报出 1 个 1807 行的冲突块（整份文件），
  `scripts/levels_init/levels_init.gml` 同样整块冲突；但上游对这两个文件的改动只有 4 行、9 行。
- **错路**：以为上游把文件重排了，准备「整份取上游再手工补安卓段」。
- **正确路径**：目标侧这两个文件带 CR（`obj_player_shield` 600 个、`levels_init` 7 个），CRLF 与 LF 逐行不同 →
  merge-file 视为全文改写。先把目标文件 `\r\n` → `\n` 归一（顺带满足 §1.1 的 LF 要求），再跑 merge-file：
  两个文件都变成 **0 冲突**直接采用。
- **证据**：2026-11-22；`.codex-tmp/an_lf4.py`（归一 + 重新合并），归一后字节 20599 → 19999、18977 → 18970。

### A42 diff3 把「我方改写某行 + 上游在同一处重写并挪位」判成两条都保留 → 重复逻辑块，其中一份还是裸 `mb_right`
- **症状**：合并后 `objects/obj_level_preview/Step_0.gml` 末尾出现两份「关闭预览」判定：第 74 行的上游版
  （`|| mouse_check_button_pressed(mb_right)`）和第 77 行的我方版（`|| ui_back_click_pressed()`）。
  两份都不冲突、都能编译，只有扫「裸 mb_right」时才暴露。
- **错路**：只看 `<<<<<<<` 有没有剩下，扫到 0 就以为合并干净。
- **正确路径**：合并后除扫冲突标记，还要扫「同一判定 / 同一赋值出现两次」与受保护层特征串（裸 `mb_right`、
  少参 `keyboard_virtual_show`、`surface_set_target` 不成对）。这里改成单块
  `if ((!global.console_open && keyboard_check_pressed(vk_escape)) || ui_back_click_pressed()){`。
- **证据**：2026-11-22；`objects/obj_level_preview/Step_0.gml:74-78`（修复后单块），断言见 `.codex-tmp/an_protect4.py`。

## B. 判断与定位（先查这里，别从代码猜）

### B1 改了 `Draw_0.gml` 完全没反应 → 孤儿事件文件
- **根因**：`objects/x/Draw_0.gml` 存在，但 `x.yy` 的 `eventList` 没 `eventType:8, eventNum:0` → 永不执行（`obj_12yinliao_effect` 踩过，改了两版都没反应）。
- **正确路径**：先读 `.yy` 的 `eventList`；补事件后必须自己 `draw_self()` 兜底。
- **证据**：2026-10-28 日志；`gml-pitfalls.md`。

### B2 动画「播两遍」→ 先查 sprite，不要先怀疑代码
- **正确路径**：看 sprite 帧表里有没有重复段，再回代码。
- **证据**：2026-10-27 日志。

### B3 贴图朝向反了 → 先看 sprite 本身
- **错路**：直接改对象里的 `image_xscale`。
- **正确路径**：`ViewImage` 看首帧朝哪边再定翻转；这是同类错误第二次犯（地精鼠 / 无常鸡毛掸子）。
- **证据**：2026-10-27 日志「同类错误第二次犯」。

### B4 「贴图缺失」→ 先查路径层级与数量，不是文件丢了
- **根因 1**：导入脚本把帧图平铺在 `sprites/<n>/<frameId>.png`，而 GM 只认 `sprites/<n>/layers/<frameId>/<layerId>.png`。
- **根因 2**：`.yy` 的 `layers` 有 6 条同名 `default`，`frames` 只有 2 个 → 2×5 = 10 条 missing。
- **正确路径**：先数 `frames × layers`，再查目录层级；正常 sprite 的 `layers` 只应有 1 条。
- **证据**：2026-11-04、2026-11-05 日志。

### B5 视觉大小不对 → 先核对原版精灵再缩放
- **证据**：2026-11-05 日志（`spr_blonde_mary_idle` 放大看就是同一只螃蟹人鱼）。

### B6 版面数字对不齐 → 不要在 Draw 里各写一份常数
- **正确路径**：一个基准变量算一次，两处引用同一值。
- **证据**：2026-10-29 日志。

### B7 底图上的绿星不是 bug
- **事实**：那是预置小火焰；出现位置错乱多半是行列写反。
- **证据**：2026-11-04 日志。

### B8 「卡能选中但放不下」→ 查 `hex_place_locked()`，不是 gridless
- **根因**：`hex_place_locked()` 只看 `hex_state.first_done`；任何一条路径关掉首抽面板却漏设标记，整局锁死且照常运行。
- **证据**：2026-10-26 日志。

### B9 改 `rewards[0]` 白改
- **事实**：发奖全用 `rewards[1]`（首通档）；`rewards[0]` 只在 `obj_battle_pause_manager/Draw_0.gml:319` 显示。
- **证据**：2026-11-13 关卡调研。

### B10 数值改了不生效 → 先过一遍「唯一事实源表」
- **典型**：改 `mod_slots_init` 的 atk（那里没有 atk 字段）；改 `register_enemy` 的 `speed`（那只喂情报岛显示，真正生效的是对象里的 `move_speed`）。
- **正确路径**：`AGENTS.md` §4 那张表，先定位再动手。

### B11 `spec` / 注释里的中文标签不可信
- **案例**：`zhuore_boss_spec.py` 里 skill_3/4 段定义循环错位一位 → 滚石与陨石动画互换；spec 自己写的中文标签是错的。
- **正确路径**：以实测「逐帧非透明面积曲线」或截图为准。
- **证据**：2026-11-09 日志。

### B12 跨服判断散在前缀里 → 用索引函数
- **错路**：`string_pos("ancient_castle_", id) == 1` 写死前缀（历史上散在 9 处，castle 走硬编码徽章档位、json 里根本没有 `gold`，新章节一上线就掉进普通关分支炸）。
- **正确路径**：`cross_server_level_index(id)`（非跨服 -1）+ `is_cross_server_level(id)`。
- **证据**：2026-11-04 日志；`AGENTS.md` §4。

### B13 按素材文件夹名判断「男版 / 女版」→ 男女反了
- **症状**：9 组变装里「星之焕男」「星之焕女」播反；用户指出 `DefineSprite_799_...StarRadianceGirlSkillEffectMovie` 才是女版。
- **错路**：① 拿桌面文件夹中文名（`星之焕男变身`）与 SWF 名里的 `Girl` 互相印证就当结论；② 用 48×48 缩略图算平均像素差判断精灵归属——男女两版构图高度相似，平均差都接近 0，等于没判。
- **正确路径**：**逐帧逐像素**比：`Image.open(a).convert('RGBA').tobytes() == Image.open(b).convert('RGBA').tobytes()`，计数后看 `18/18` 还是 `3/18`，量级差得很明显。同尺寸同构图的两套素材一定比到「N/总帧数」级别一致才认。
  实测归属：`星之焕男变身` ≠ SWF（3/18），`spr_huan_bianshen2` = SWF（18/18）。
- **证据**：2026-11-13 日志；`scripts/attire_transformation/attire_transformation.gml:29-36`。

### B14 卡片待机像「一直长大 / 帧序错乱」→ 先量每帧包围盒再定段落
- **症状**：`spr_shiliu_0/1/2` 待机时果实从 62px 一路涨到 74px 再跳回，用户报「精灵帧顺序不对」。
- **错路**：只比对「项目帧 vs 源帧」逐像素一致（结果全 0 差异）就下结论「帧序没问题，是代码问题」——像素一致只证明**导入没打乱**，证明不了**源文件名的顺序就是播放顺序**。
- **正确路径**：按帧打开、算不透明像素的 bbox 宽度序列，段落一眼分明：
  `[生长 宽 62→74 单调增] [爆炸 宽 165~331 且橙色像素=0] [成熟 宽 82~88 稳定，且末帧与段首帧逐字节相同 = 闭环]`。
  **段落切好之后还要问一句「卡片实际应该按什么顺序播」**——石榴的答案不是「待机在前」，
  而是 **生长 → 成熟 → 爆炸**（一次性卡先长出来再炸）。所以最终重排是
  `[生长 idx0..8][成熟 idx9..20][爆炸 idx21..][留档重复帧]`，`idle_anim = 20`。
  匹配不上「一次性序列」还会踩第二个坑：父类 IDLE 是 `0..idle_anim` 死循环，播完成熟段会回卷到幼苗，
  必须在 Step 里把回卷目标改到成熟段首帧（`image_index = 成熟起点 + (idx mod 成熟长度)`）。
  **闭环重复帧要留在成熟段末尾，不能丢到帧表最后**——帧表最后一段必须是「动作段」（爆炸/攻击），
  否则在 IDE 缩略图/预览里最后一眼看到的是一颗完好的果实，会被当成帧序还没修好。
  重排脚本：`tools/fix_shiliu_sprite_order.py`（原地重写每帧 PNG，GUID / `.yy` / 原点不动，帧总数不变）。
- **证据**：2026-11-13 日志；`objects/obj_shiliu_baobao_bing/Create_0.gml:17-36`、`Step_0.gml:32-42`。

### B15 特效「一闪一闪 / 消失又出现」→ 先量 alpha 曲线，别急着查代码
- **症状**：星轨神本体光环每播一遍就整片消失再淡入；用户描述为「特效应该一直存在，而不是消失又出现」。
- **错路**：先怀疑是不是特效对象被销毁 / 被 `visible` 开关切了（`xg_halo.visible = !xg_fullscreen` 确实是次要原因）。
- **正确路径**：对特效精灵逐帧算 `(alpha>8).mean()`：末帧 0.00% 的就是**一次性脉冲**（淡入→常亮→淡出→空），
  这类精灵**不能循环**，必须「播到常亮帧后 hold」：给特效对象加 `xg_hold_frame`，`image_index >= hold` 就 `image_speed = 0` 并锁帧。
  对照：`spr_haiyang_god_effect` 全程 alpha 28~35、无空帧 → 可以放心循环，所以海洋不闪。
- **证据**：2026-11-13 日志；`objects/obj_xinggui_god_effect/Step_0.gml`、`objects/obj_xinggui_god/Create_0.gml:60`。

### B16 动态任务每次进游戏都退回「待办」→ 查启动时的 prune / sync 顺序
- **症状**：卡片情报任务（`info_view_*`）完成后再开一次游戏又变待办，情报岛重复弹「任务完成」。
- **错路**：先怀疑 `card_info_task_complete` 的幂等判断 / state 没写进去（那两处确实也该加固，但不是主因）。
- **正确路径**：看启动流程 `objects/obj_game_init/Other_2.gml` —— 原来是 `prune → sync`，而
  `task_init()` **只注册 90 条静态任务**，动态 `info_view_*` 的池条目由 `card_info_task_sync()` 现场注册；
  prune 那一刻池里没有这些 key → `get_task_data(tid) == undefined` 成立 → 全部当孤儿删除，
  紧接着 sync 按 `new` 重建。修法：① prune 只用「卡还在不在解锁列表」判定；② 启动顺序改成 `sync → prune`。
- **证据**：2026-11-13 日志；`scripts/task_edit/task_edit.gml:219`、`objects/obj_game_init/Other_2.gml:180`。

### B17 范围框/光环画出来比技能范围大或小 → 按「括号臂跨度」换算，画布和 bbox 都不行
- **症状**：星轨神情报写 5*5。第一版用画布算：四转/终转的光环只有 4.4 格（0 转几乎准，越往后越缩）。
  第二版改用 bbox 算：shape0 5.2 格、shape1 5.0 格、**shape2 只剩 4.2 格**（用户三联截图直接指出）。
- **两层错路**（都要避开）：
  1. 用 `sprite_get_width/height`（**画布**）—— 特效素材为了容纳扩散/发光，四周留了大量透明边。
  2. 用**常亮帧的不透明 bbox** —— 四角括号的角上还挂着星芒/光晕，bbox 比「括号本体」大一圈，
     而且**各形态撑大的比例不一样**（shape0 +5%、shape1 +6%、shape2 +28%/+16%）。
     拿 bbox 当分母 = 按「星芒尖端」对齐，括号本体自然偏小，且形态越高越小。
- **正确路径**：摊成 alpha 掩码后统计**每一行 / 每一列的不透明像素数**，
  像素最多的那一行 / 那一列就是四角括号的四条臂，**臂的跨度才是玩家眼里的「框」**。
  `scale = 目标格数 * grid_cell_size / 臂跨度`，各轴独立；中心取**格心**
  （`grid_offset + (col+0.5)*cell`），别拿卡片 `x/y`（脚底原点 / 悬浮偏移会整体错半格）。
  脚本：`tools/measure_xinggui_halo.py`（换素材重跑，把常量表填回 Create）。三个形态的臂跨度量出来
  几乎相同（295~307 × 313~324）→ 说明美术本来就画成同一尺寸，按它缩放后三者视觉必然一致。
- **验证**：把缩放后的帧贴到 `9x7` 网格模拟图上、画目标 5*5 红框，四角必须贴在框角（三形态各一张并排比）。
- **证据**：2026-11-13 日志；`objects/obj_xinggui_god/Create_0.gml`（`_vis_w/_vis_h` 表）、`tools/measure_xinggui_halo.py`。

### B18 卡片击杀后直接 `instance_destroy(敌人)` → 漏掉掉落 / 击杀结算
- **症状**：石榴爆爆冰旧实现把老鼠打死就 `instance_destroy()` + 自己贴灰烬特效；海克斯模式下的
  `hex_on_kill` / `hex_try_drop` / 塔之诅咒全都不触发（掉卡、火苗、诅咒爆炸都没了）。
- **根因**：敌人死亡分两步 —— `obj_enemy_parent/Other_10.gml` 只负责扣血，**不销毁**；
  真正的死亡结算在 `Step_0.gml:427` 的 `if (hp <= 0 && state != ENEMY_STATE.DEAD)`：
  `hex_batch2_on_enemy_death` → `hex_on_kill` → `hex_try_drop` → `state = DEAD`；
  然后 `image_alpha <= 0 && state == DEAD` 才 `instance_destroy`。直接销毁 = 把整段跳过。
- **正确做法**：想「击杀但不播死亡动画」时置 `with (_t) { ash_death = true; image_alpha = 0; }`，
  父类会立刻隐形、照常走完结算再自己销毁；特效由卡片侧另建（如 `obj_shiliu_ash_fx`）。
- **另一个坑**：`obj_mouse_ash_death` 有自己的生命周期（`life 90` → `image_index 14` 定格 → 淡出），
  拿它贴自定义碎冰图并 `image_speed = 0` 结果是**永远不动**。要「完整播一遍」就写独立特效对象。
- **证据**：2026-11-13 日志；`objects/obj_shiliu_bullet/Step_0.gml`、`objects/obj_enemy_parent/Step_0.gml:427`。

### B19 改了精灵帧内容，游戏里却还是老画面 → 顶层合成图没同步
- **症状**：石榴帧序重排后 `--check` 逐帧全 OK，但游戏里播的还是旧顺序（用户报「没有按照你给的帧顺序实现」）。
- **根因**：GMS 精灵目录里有**两套图**：
  - `sprites/<名>/layers/<帧GUID>/<图层GUID>.png` —— 图层源图，IDE 编辑器读它；
  - `sprites/<名>/<帧GUID>.png` —— **顶层合成图，运行时和 IDE 预览读的是这一张**。
  只覆盖前者等于什么都没改。单图层无偏移时两者内容必须完全相同（可用 md5 校验）。
- **正确做法**：任何「原地重写精灵像素」的脚本都要两边一起写。
  `tools/make_multi_frame_sprite.py` 一直是对的（两个路径都 copy）；
  `tools/fix_shiliu_sprite_order.py` 已补齐，`--check` 也两边都比。
- **验证**：对每个精灵的每帧比 `md5(顶层) == md5(图层)`，不一致的报出来。
- **证据**：2026-11-13 日志；`tools/fix_shiliu_sprite_order.py:layer_png()`。

---

### B20 「子弹特效 / 附加效果有时候不生效」→ 四处静默吞掉，逐一排查
- **症状**：元素蛇四色子弹（定身 / 毒气 / 冰冻 / 暴击）大部分命中都没反应，偶尔才有。
- **四个原因**（全都不会报错）：
  1. **附加效果包在 `if (hp > 0)` 里**：卡攻击力高 → 命中基本秒杀 → 老鼠一死 `hp <= 0` 就整段跳过。
     元素效果应当「命中即判定」：已死目标写状态无害，毒气尤其要照放（它会在原地毒到周围）。
  2. **判定盒比画出来的小**：本项目子弹的 `bbox` 只看 `image_xscale`，而父类 `Draw_0` 优先用
     `visual_scale_*` 绘制。只设 `visual_scale = 1.3` 而 `image_scale = 1` → 判定盒比视觉小 30%，
     边缘命中被静默漏掉。**两个都要设成同一值**（父 Draw 优先 visual_scale，不会双倍放大）。
     ⚠️ 但**在 `Create` 里设 `image_scale` 也没用**：`obj_bullet_parent/BeginStep_0.gml:8-15`
     每帧先把 `image_scale` 拷进 `visual_scale_*`，随后**无条件夹回 1**。所以必须在**子弹自己的 `Step`**
     里每帧重设（`obj_yuansushe_bullet/Step_0.gml` 的 `image_xscale = _want_sx; image_yscale = 1.3;`），
     bbox 才会在判定那一瞬间是 1.3。2026-11-13 的 CHANGELOG 写「image_xscale 也设 1.3，画多大判定就多大」
     其实是错的，2026-11-14 实测后改掉。
  3. **特效用 `image_speed = 1` 播**：素材帧数差很多（暴击 5 帧 / 冰晶 6 帧 / 眩晕 20 帧），
     短特效只有 0.08~0.1 秒，肉眼看不到 → 用 `image_speed = 0` + 每帧停留 N tick，寿命按帧数算。
  4. **派生伤害的 `target_type` 抄错**：毒气沿用 `"normal"` 时 `can_target_on("normal","dance"/"invisible")`
     为 false，非主流鼠 / 未显形幽灵吃不到毒 → 应跟原卡一致（`"pierce"`）。
- **通用检查顺序**：先看「效果代码有没有被执行」（击杀分支 / hp 判定），再看「判定有没有命中」（bbox vs 视觉），
  最后看「特效有没有播出来」（帧数 × tick）。
- **证据**：2026-11-13 日志；`objects/obj_yuansushe_bullet/Step_0.gml`、`objects/obj_yuansushe_fx/*.gml`。

---

### B21 子弹「只穿透障碍、打不到老鼠」→ 遍历源 `global.enemy_by_type` 不完整
- **症状**：元素蛇子弹视觉上从老鼠身上飞过、一点伤害与特效都没有，但同一个子弹能打死障碍物。
- **根因**：命中循环按 `global.enemy_by_type` 的白名单分桶遍历。那张表**不是引擎自动维护的**，
  而是每个敌人对象在自己的 `Step_0` 里注册（`obj_enemy_parent/Step_0:7-23`，以及 30 多个重写 Step
  的对象各自抄了一份）。实测 **57 个敌人对象重写 `Step_0` 却完全没有 `event_inherited()`**，
  其中一部分（火车各节 `obj_mouse_train_1/2/3_body|head`、若干换皮鼠、部分 BOSS 部件）
  **没有写注册代码** → 它们永远不在表里。`obj_barrier` 自己手写了注册，所以只有它吃伤害。
- **正确路径**：命中遍历改成 `with (obj_enemy_parent)` 全量扫描，每只现场 `can_hit(other.target_type, target_type)` 过滤。
  进 `with` 前先用 `variable_instance_exists` 兜 `hp / grid_col / grid_row / target_type` 四项
  （GML 读未定义实例变量是硬崩，不是静默 false；`obj_enemy_parent` 的 296 个子对象里有 3 个
  `obj_*_bullet` 就缺 `target_type`）。
- **反向教训**：任何「靠敌人自己注册的全局表」做命中的子弹（`obj_double_blade_snake_bullet`、
  `obj_aladdin_lamp_bullet` 等同一写法）都有这个盲区，只是它们的卡平时打的多是常规鼠所以没暴露。
- **证据**：2026-11-14 日志；`objects/obj_yuansushe_bullet/Step_0.gml`、`objects/obj_barrier/Step_0.gml:6-24`、
  `objects/obj_mouse_train_1_body/Step_0.gml`（有 `grid_col` 赋值、无 `enemy_by_type` 注册）。

### B26 「穿透口径」这类卡，用户来回改三次 → 判据只该有一个开关位 `ys_stop`
- **症状**：元素蛇的子弹口径被反复调：2026-11-13 写成「打不到老鼠就自毁（只穿障碍）」→
  2026-11-14 上午用户说「只是穿透障碍，并不穿透攻击」→ 改成全行穿透 →
  同日下午用户又说「元素蛇子弹应该是非穿透老鼠的效果」→ 再改回「穿障碍、不穿老鼠」。
- **错路**：每次改动都重写整段命中循环（删 `ys_stop`、删 `break`、删循环后的自毁块），
  三处（Create 的标记位、命中分支的 break、循环后的 destroy）分散改，容易漏掉其中一处，
  漏 `break` 就是「口径改了但同格还顺手打第二只」，漏 `ys_stop` 就是「说了不穿透却照样飞到底」。
- **正确路径**：口径收敛成**一个标记位 + 三处固定位置**：
  1. `Create_0.gml` 里 `ys_stop = false;`（唯一的开关）；
  2. 命中分支里先算 `var _stop_here = (target_type != "obstacle");`，
     **必须放在死亡结算（`ash_death / image_alpha = 0`）之后**再 `if (_stop_here) { other.ys_stop = true; break; }`
     —— 先 break 会整段跳过死亡结算，老鼠带着 `hp <= 0` 赖在场上；
  3. 双层循环之后 `if (ys_stop) { instance_destroy(); exit; }`（放在循环外，本帧特效与伤害都结算完再销毁）。
  这样「穿障碍 / 不穿老鼠」= 只改 `_stop_here` 这一个布尔，其它两处永远不动。
- **反向教训**：文案（`mod_cards_init` 描述 / `mod_slots_init` 卡槽 / `mod_info_island_init` 情报岛）
  与实现必须一起改，三者都是玩家可见处；分类名 `[直线穿透类]` 指的是**弹道形态**，不代表「穿透老鼠」，
  别拿它当口径依据。
- **证据**：2026-11-14；`objects/obj_yuansushe_bullet/Create_0.gml:46-49`、
  `objects/obj_yuansushe_bullet/Step_0.gml:169-178`、`:216-222`。

### B22 子弹「提前一格受击」→ bbox 相交当判据，而敌人盒子有 1.65 格宽
- **症状**：穿透子弹视觉上还没碰到老鼠就打掉了它，或者打的是右边那一格的老鼠，
  用户原话「提前一格受击」。
- **根因**：命中判据写成 `(同列 || 横向包围盒重叠)`，其中 bbox 用的是**精灵声明 bbox**：
  - 敌人 `objects/obj_enemy_parent/Create_0.gml:2-3` 有 `image_xscale/yscale = 1.8`；
  - `sprites/spr_normal_mouse/spr_normal_mouse.yy` 的 `bboxMode=0`（自动），声明 bbox = `3..101`，
    这是**全帧并集** —— 含 32~36 帧倒地动作往左右伸出的像素（实测第 18 帧不透明区域到 3..88）；
  - 相对 bottom-centre 原点是 `[-51,+47]`，1.8 倍下 = **176px = 1.65 格**；
  - 敌人出生点 `objects/obj_battle/Create_0.gml:413` 是格心 **+30**，左沿 = 格心 −91.8，
    而格左沿 = 格心 −53.5 → **身体探进上一格最后 8px**；
  - 子弹 `spr_yuansushe_bullet` 60×28、1.3 倍下尖端比中心领先 37.7px。
  37.7 + 8 > 0 → 子弹中心还在上一格（进格 93%）时 bbox 就已相交 → 提前一格命中。
- **正确路径**：命中只认「同行 + 同列」，拿子弹自己 `floor((x - grid_offset_x)/cell_x)` 与敌人
  每帧从 x 反算的 `grid_col` 比。删掉任何 `bbox_right >= bbox_left` 式的像素级 `||` 分支 ——
  格子已经是权威坐标系，再叠一层像素判据只会引入精灵尺寸依赖。
- **反向教训**：`obj_double_blade_snake_bullet`（`Step_0.gml` 里同时比
  `bbox_right/bbox_left` 与 `bbox_bottom/bbox_top`）、`obj_bbq_bullet` 等都用 bbox 命中，
  敌人只要换成宽体/高体精灵就会偏；用户如果报同类症状，先量精灵声明 bbox 与 `image_xscale`。
- **量法**：`sprites/<名>/<名>.yy` 读 `bbox_left/right/top/bottom` + `origin`（枚举：4=中中、
  7=中下、9=中上），1.8 倍换算后除以 107 得到「占几格」。
- **证据**：2026-11-14；`objects/obj_yuansushe_bullet/Step_0.gml:42-70`、
  `sprites/spr_normal_mouse/spr_normal_mouse.yy`、`objects/obj_enemy_parent/Create_0.gml:2-3`。

### B23 轰炸类陨石「索敌有问题、砸空地」→ 开火条件按 ±N 行判，但落点候选只收本行
- **症状**：银河马这类跨行索敌 + 只砸一行的卡，明明场上有老鼠，陨石却砸在本行空地；
  或者砸下去后锁定的那只没掉血、旁边一只无辜的被打死。
- **根因**（三条同时成立才发作）：
  1. 开火判定 `gh_has_target()` 用 `abs(grid_row - other.grid_row) <= gh_search_rows`（±1 / ±2 行），
     可出弹时收集落点候选又写成 `grid_row == other.grid_row`（只收卡片本行）→ 邻行有鼠时开火、
     候选却是空数组；
  2. 候选为空走兜底 `min(global.grid_cols, grid_col + 2 + _k)` → 砸卡片右前方 2/3/4 格空地，
     离邻行老鼠远得连 `gh_splash_cols` 都够不着；
  3. 落地结算处**无条件**按「本行离落点最近的一只」重挑全额目标，把邻行锁定的那只降级成 50%
     溅射，全额糊给本行另一只。
- **正确路径**：开火条件、候选集合、落点、全额目标必须用**同一套行口径**。
  候选收集就照开火条件（`abs(grid_row - self.grid_row) <= gh_search_rows`），
  排序键 = 行距 → 列距，第 k 颗锁第 k 个候选；全额目标在出弹时就锁进子弹实例
  （`gh_target`），落地只作 `instance_exists` + `object_is_ancestor` 兜底，不再重挑。
- **反向教训**：任何「跨行索敌但落点只在本行」的轰炸卡（`chocolate_cannon` / `ronghedapao` /
  `gaia` 的落点也是本行 + 全屏索敌）都要核对「开火条件 ⊇ 落点候选集合」这条不变式；
  候选为空时宁可不出弹，也别兜底砸空地——玩家只会读成「锁不到老鼠」。
- **证据**：2026-11-14；`objects/obj_galaxy_horse/Other_11.gml`、`objects/obj_galaxy_horse_bullet/Step_0.gml`、
  用户截图现场（卡片 col2、老鼠 col8 相邻行、陨石落在 col4 / col5）。

### B24 范围光环「贴图和动画一样静止」→ 被 `xg_hold_frame` 写死定格
- **症状**：星轨神 5*5 范围框「和贴图一样一动不动」，其实美术是有动画的；转职后同样静止。
- **根因**：`objects/obj_xinggui_god/Create_0.gml` 创建光环时写 `xg_halo.xg_hold_frame = 10;`，
  而 `objects/obj_xinggui_god_effect/Step_0.gml` 的 `else if (xg_hold_frame >= 0 && image_index >= xg_hold_frame)`
  分支会把 `image_index` 钉在 10、`image_speed = 0` —— 永久静止。这是 2026-11-13 治
  「整段 loop 会播到淡出帧、导致范围框一闪一闪」下的猛药，代价就是动画全没。
- **正确路径**：先量精灵结构再决定循环区间。本工程范围特效精灵统一是
  「0~2 淡入 / 3~13 常亮 / 14~16 淡出 / 末帧全透明」，且**淡出起始的前一帧与常亮首帧像素完全相同**
  （shape0 帧3 与帧13 同 MD5 `AD8E7C54`，shape1 `EB846758`、shape2 `9729E34A`、shape3 `A0815735`）。
  于是给特效对象加一对循环窗口参数：`xg_loop_start` / `xg_loop_end`（右开区间），
  Step 里 `if (image_index < xg_loop_start || image_index >= xg_loop_end) image_index = xg_loop_start;`，
  `xg_hold_frame` 只留给「真·一次性脉冲」。调用方写 `image_index = 3; xg_loop_start = 3; xg_loop_end = 13;`。
  既永远播不到全透明帧（不闪），又保住常亮段的呼吸 / 旋转动画。
- **反向教训**：`hold` 定格与 `loop` 整段都不该当默认解，先看「常亮段是不是首尾同帧」——
  是就说明美术本来就设计成段内循环。查同类时注意 `obj_haiyang_god_effect` / `obj_fengrao_god_effect` /
  `obj_time_god_effect` / `obj_zhanqima_effect` 都只是 `image_speed = 0.75`（暂停置 0），没有定格问题。
- **证据**：2026-11-14；`objects/obj_xinggui_god_effect/Step_0.gml:21-27`、
  `objects/obj_xinggui_god/Create_0.gml:71-72`、四套 `spr_xinggui_god_effect*` 逐帧 MD5。

### B25 反向飞的子弹「倒着飞」→ 想用 `image_xscale = -1` 翻转，两处机制都不认
- **症状**：终转炎帝三发朱雀里，中路那发是从右往左飞的，但贴图还是朝右、整只鸟屁股朝前；
  截图里左侧那只火焰鸟与右侧两只同向，明显「倒着飞」。
- **错路**：写 `image_xscale = -1`（或 `image_xscale *= -1`）想镜像贴图。
- **根因（两条同时拦）**：
  1. `objects/obj_bullet_parent/BeginStep_0.gml` 每帧先把 `image_xscale` 抄进 `visual_scale_x`，
     然后**无条件** `image_xscale = 1; image_yscale = 1;`（目的是让 `bbox` 恒为原生大小、不随放大膨胀）。
     所以负值活不过一帧，绘制走 `visual_scale_x`（`Draw_0.gml` 用它 `draw_sprite_ext`）→ 负号也没传下去；
  2. 即使镜像成功，`scripts/precise_bbox_collision` 的判定框只用 `image_angle` 做旋转，
     **完全不读 `image_xscale` / `image_yscale`**（连放大都不认，只取 `sprite_get_bbox_*` 的原生值）→
     图转了判定框没转，看起来命中却在身后。
- **正确路径**：用 `image_angle = 180`。`precise_bbox_collision` 会按角度把四个角转过去，
  贴图和判定框一起转头；`obj_bullet_parent/Draw_0.gml` 也把 `image_angle` 传给 `draw_sprite_ext`。
  另外该子弹走对象池（`obj_pool_acquire` → `instance_change(obj, true)` 重跑 Create 但不清角度），
  必须在自己 `Create_0.gml` 里 `image_angle = 0; image_alpha = 1; image_blend = c_white;` 归零，
  否则被回收复用时带着上一发的 180° 出生（`objects/obj_ronghesanxian_bullet/Create_0.gml:34` 有同款注释）。
- **证据**：2026-11-14；`objects/obj_shennong_god/Other_11.gml:126-131`（写 `image_angle = _from_right[_i2] ? 180 : 0`）、
  `objects/obj_shennong_god_bullet_h/Create_0.gml:13-22`、`objects/obj_bullet_parent/BeginStep_0.gml:8-15`、
  `scripts/precise_bbox_collision/precise_bbox_collision.gml:23-58`。

---

### B27 「编在波次里的敌人不出场」→ 先看它的出生高度，别在 Create 里自己搬位置
- **症状**：梦魇天空的变异蝙蝠鼠（`type: "kuafu_bat"` 写在 `waves[].subwaves[].enemy_list`）进关卡看不到；
  用户口径「真因不是 `wave_ignore`，直接参考蝙蝠鼠的形式」。
- **错路**：在 `obj_kuafu_bat/Create_0` 里把 x/y 改成随机落点、出生点抬到落点上方 520px，
  再让 Step 用 `(x,y)` 反推格子建 target —— 两处各自算一遍落点容易对不上；即便对上，出生点在屏幕上方
  480~520px、APPEAR 状态还要先等 120 帧才开始下降，整段两秒多的「吊下来」没走完，波次已清完结算
  （`battle_finish_win()` 里 `global.is_paused = true`），蝙蝠永远留在屏幕外。
- **正确路径**：整份照抄能用的那个 —— `obj_bat_mouse`：Create 只管数据（不碰 x/y、不定落点），
  落点 / 配对 target / 出生高度全在 Step 的 `if (banding_target_inst == noone)` 自动补齐块里做；
  事件生成器（`obj_event_manager` 的 `bat_mouse_spawn` / `kuafu_bat_spawn`）成对创建 target + 敌人并互绑。
  **波次里放的**这一路要额外把出生高度贴近落点（`_home.y - 80`，target `-120`）。
- **证据**：`objects/obj_kuafu_bat/{Create_0,Step_0}.gml`、`objects/obj_bat_mouse/Step_0.gml:11-28`、
  `objects/obj_event_manager/Step_0.gml:372-404`、`scripts/battle_finish_win/battle_finish_win.gml:23-24`。

### B28 「新敌人精灵帧数照原版」但播错段 → 父类动画索引是固定五段，按原版精灵反推每段长度
- **症状**：跨服僵尸鼠四只（潜艇 / 突袭 / 忍者 / 小喽啰）精灵总帧数都对齐了原版同类鼠，
  但游戏里走路播成攻击、死亡只播一半、受伤段完全不出现。
- **错路**：拿 `ffdec` 导出的 `FrameLabel` 当分段依据按标签顺序切 —— SWF 里标签的时间轴顺序 ≠ 游戏里
  精灵的帧顺序。例如突袭 SWF 的攻击帧在 112..126（中间隔着陆地段），标签顺序一套上去整段错位。
- **正确路径**：父类 `obj_enemy_parent` 只认一套固定五段布局 —— 正常行走 / 受伤行走 / 正常攻击 /
  受伤攻击 / 死亡，索引 `move*2 + attack*2 + death`。先读原版同名鼠精灵的
  `move_anim / attack_anim / death_anim` 反推每段帧数（潜艇 8/8/4/4/12、突袭 8/8/4/4/8、
  忍者 12/12/29/29/12、小喽啰 12/12/29/29/13、蜗牛 8/8/8/9+8），再从 SWF 挑对应帧范围重采样。
  附带三条：① 同一只鼠的所有精灵必须共用同一个 origin 参考帧，否则切换水陆形态会跳一下；
  ② 全透明帧不能当参考帧（蜗牛爆炸末帧、黏液首帧），构建器加空帧守卫；
  ③ 1:1 复制的老素材（蜗牛 41 帧同构）要把 Step 的 `mod` / 锁帧 / 阈值一起改。
- **证据**：`tools/cross_new_mice_spec.py:112-265`、`objects/obj_snail_mouse_mucus/Step_0.gml`（`mod 6` → `mod 10`）。

### B29 商城「看不到某件商品」→ 先算页数，别先怀疑注册
- **症状**：新上架的四套时装里，用户只报「星之耀男B 在商城里看不到」（其余三套能看到）。
- **错路**：先去翻 `register_goods` / `register_attire` / 8 个精灵的 `.yy` 与帧图 / `obj_shop_bg` 的
  4×4 绘制循环 —— 全部完好，白绕五六轮。真因在列表顺序。
- **正确路径**：① 先核对条数：`shop_init` 里 `"type":"player_attire"` 条数 vs `attire_init` 里
  `"target_card":"player"` 条数（本次 178 = 178 → 没缺）；② 再看 `shop_list_recharge` 的
  `ds_map_keys_to_array(global.goods_map)` 是哈希遍历序，每页 16 个 → 178 件 = 12 页，
  同批写入会被打散；③ 自查话术：搜索框输入系列名能列全就说明数据在、只是翻不到；
  ④ 根治就让该页签按 `global.goods_id_pool` 下标插入排序（只挂 `shop_button_select == 5`，
  变量带 `5` 后缀避免与凭证页排序的 `_sn/_cur/_ck/_b` 撞名）。
- **证据**：`objects/obj_shop_bg/Create_0.gml:186-212`、`scripts/shop_init/shop_init.gml:226-229`。

### B30 新卡动画「待机里带施法姿势 / 攻击姿势不播」→ 帧分段要读 SWF 的 FrameLabelTag
- **症状**：阴阳蛇 22 帧整段当待机循环，待机动画里每隔一秒就张嘴喷一次；出弹时反而是呼吸姿势。
  用户报「IDLE 帧和发射子弹的帧不对」。结界马同样中招（21/24 帧里后半段是技能）。
- **错路**：靠 `ViewImage` 看 1.png / 11.png 的缩略图，觉得「几张长得一样 → 全是待机」，
  于是写 `idle_anim = sprite_get_number(sprite_index) - 1; attack_anim = 0;` —— 缩略图看不出 5px 的嘴部差异。
- **正确路径**：① `java -jar ffdec.jar -swf2xml out.xml x.swf`（必须绝对路径；`ffdec-cli.jar` 只是启动壳）；
  ② 解析 `DefineSpriteTag/subTags`，按 `ShowFrameTag` 累计帧号，`FrameLabelTag` 落在哪一帧就是段起点；
  ③ 换算（`obj_card_parent/Step_0:281-289`）：`idle_anim` = 待机段末下标，`attack_anim` = 攻击段长
  （阴阳蛇 22 帧 → `11 / 10`；结界马 21 帧 → `9 / 11`、24 帧 → `11 / 12`）；
  ④ 纯计时卡（结界马）用 `jj_skill_timer` 在结界结算那一帧点亮；
  ⑤ 出弹帧靠「逐帧像素差分找峰值 + 头部放大拼图」，代码里盯 `image_index` 并配兜底
  （`yy_fire_delay = 90`）；发弹后才补「攻击段剩余帧」到 `yy_anim_hold`，起手期间别停 `attack_timer`。
- **证据**：`objects/obj_yinyangshe/{Create_0,Step_0}.gml`、`objects/obj_jiejiema/Create_0.gml:29-47`、
  `objects/obj_jiejiema_field/Step_0.gml:65-72`。

### B31 子弹过火「伤害对、外观没变」→ 换贴图是子弹自己的事，父类只改倍率
- **症状**：阴阳蛇被火盆点燃后 `damage` / `fire_mult` 都对（毒伤也跟着乘了倍率），但屏幕上还是蛇弹原图。
- **错路**：以为 `bullet_hazard_fire` 是「过火的全部」，在子弹 Create 里声明 `hazard_fire = true` 就完事 ——
  它只负责门禁 / 同排 / 取最高倍率 / 音效 / 尺寸。
- **正确路径**（`scripts/mod_bullet_hazard/mod_bullet_hazard.gml:189-204`）：只有「冰火弹被更高倍率再点燃」
  这一支才 `sprite_index = spr_fire_bullet`；普通火源分支只写 `image_xscale = _scale`。
  换贴图必须写在子弹自己的 Step（`spr_fire_bullet` 41×14、4 帧、按 `life div 4` 轮播、放大 1.8）。
  两个配套点：① 融盆二转冰弹让路（`ds_list_find_index(brazier_list, -9999) != -1` 时不换）；
  ② 把 `hazard_fire` 声明成 `{ scale: 0 }`，否则父类普通分支写的是**无符号** `image_xscale = 1.8`，
  被弹回朝左飞的那一帧会被掰正、闪一下。
  口诀：过火三件事 —— 倍率（父类）、尺寸（父类或自己）、**贴图（一定自己）**。
- **证据**：`objects/obj_yinyangshe_bullet/{Step_0,Create_0}.gml`、`objects/obj_bbq_bullet/Step_0.gml:13-20`、
  `objects/obj_fashishe_bullet/Step_0.gml:17-25`。

### B34 用「只认目标无尾逗号」的正则读源 yyp → 源组解析成 0 个，误报「纹理组缺口 0」
- **症状**：`an_tg4b.py` 首跑打印「源组 0：/ 目标组 14 / 缺口 0：无」，但同一轮扫精灵时又有 120 个
  `textureGroupId = pack_desert_trip` 找不到归属组。
- **错路**：以为源 yyp 没有纹理组（被另外的字段名骗了），差点直接改 120 个精灵的组名。
- **正确路径**：源 yyp 每条都带尾逗号（`"resourceVersion":"2.0",},`），而目标 yyp 不带（`"resourceVersion":"2.0",}`），
  按整行结构写的正则只吃得下目标风格。改成只抓语义键
  `"name":"([^"]+)","resourceType":"GMTextureGroup"`，两种风格通吃 → 源组 15（多出 `pack_desert_trip`）。
  结论：**统计类正则先在一个已知答案的文件上验一次命中数**，别直接拿结果做决策。
- **证据**：2026-11-22；`.codex-tmp/an_tg4b.py`；`FVM_Reborn_makk.yyp`（源 15 组 / 目标 14 组）。

## C. 机制与数值（改了不生效 / 静默错）

### C1 自定义速度叫了 `speed`
- **现象**：向右飞的 16px/帧（双倍）、向左飞原地不动、竖向子弹向右漂。
- **根因**：内置 `speed` 每帧按 `direction`（默认 0=向右）自动位移，Step 里再 `x += dir*speed` 叠加。
- **正确路径**：私有名（`huagao_speed`），Create 里 `speed = 0; hspeed = 0; vspeed = 0;`。
- **证据**：2026-10-24 日志；`obj_huagao_bullet/Create_0.gml`。

### C2 `attack_timer == cycle - N*flash_speed` 精确等号 + cycle 变小 → 永不发射
- **现象**：技能等级高 / 攻速词条一压，卡就不出弹。
- **正确路径**：① `cycle` 取整（`max(1, round(base_cycle * clamp(...)))`，见 `obj_mod_battle_manager/Step_0`）；② 或抄 `obj_houyi_god/Step_0.gml:33-36` 的 `_spd` 压缩窗口；③ 或给对象置 `uses_fire_frame = true` 走 `obj_card_parent/Step_0.gml` 的 `_anim_flash`。
- **证据**：2026-11-05 日志；2026-11-13 未提交改动。

### C3 新增通道只写「字段 + 读取」漏「解析」→ 恒 0 且不报错
- **案例**：`cat_hp` 通道定义了字段、写了 `hex_hp_mult_for_card` 消费，漏 `hex_apply_core` 的解析分支。
- **正确路径**：新通道固定四步核对：字段定义 / 解析写入 / 读取消费 / 挂钩点。
- **证据**：2026-10-26 日志。

### C4 `register_card_skill` 只 add 不覆盖
- **事实**：`skill_init` 已注册的卡，`mod_skill_init` 的改写完全无效。
- **正确路径**：改技能走 `get_plant_data_with_skill` 的数组，或先确认 key 不存在。

### C5 `register_material` 静默失败，`register_goods` 可覆盖
- **事实**：前者 `ds_map_add`（重复 key 静默不写），后者 `ds_map_set`（覆盖）。
- **正确路径**：改价/改文案走 goods；材料只能新增 id。

### C6 `json.dump` 回写关卡 JSON → 数值被毁
- **事实**：会把 `1.666667` 写成科学计数/截断；**203/314** 个文件收尾 `}` 后带 NUL `0x00`（GML 容忍，python `json` 报 `Extra data`）。
- **正确路径**：手工改文本；批量任务用逐行替换，收尾保留原字节尾巴。

### C7 链式三元 → 编译错误
- **正确路径**：`(a) ? 1 : ((b) ? 2 : 3)`，或三档以上直接 `if` 顺序返回。
- **证据**：2026-10-26 日志 `obj_baibianshe/Step_0.gml:74`。

### C8 结构体字段撞内置常量
- **现象**：`_s.pi = x` → GM1031；读取时静默拿到 3.14159，只有赋值才炸。
- **正确路径**：换名 `pi_value`。

### C9 实例层改 `shape` 被覆盖
- **事实**：`obj_card_parent/Other_10` 每帧按存档重建 shape。
- **正确路径**：改存档字段，或改注册表形态数据。

### C10 后写循环覆盖前面的例外
- **案例**：`cold_drew` 必须在「散点追踪」循环之后写（否则被覆盖成 `tracker_advanced`，莓果点心那格没人读）。
- **正确路径**：改 `mod_apply_category_buff_map` 后，检查例外是否排在覆盖它的循环之后。
- **证据**：`card_buff_category.gml:409-415` 注释。

### C11 `var _l = save_data.xxx; array_push(_l, v)` 不回写
- **正确路径**：直接操作 `global.save_data.xxx`。

### C12 BOSS 不吃 PI / 词条倍率
- **根因**：BOSS 生成口是 `obj_battle/Step_2.gml` 手写 `instance_create_depth`，不走 `Create_0` 的组波循环，因此从不调 `hex_enemy_scale()`。
- **正确路径**：新增生成口必须显式补 `hex_enemy_scale_boss()`。

### C13 跨房间覆盖层的恢复逻辑只写在主菜单
- **案例**：跨服「回跨服页」恢复只写在 `obj_menu_manager/Create_0`，从 `room_map` 弹的就丢了。
- **正确路径**：任何「从 A 房间弹出的覆盖层」都在 A 房间的 Create 里做一份同构恢复。
- **证据**：2026-11-10 日志。

### C14 GameMaker IDE 开着时外部改 `.yyp`
- **现象**：脚本加进去的资源条目被 IDE 一次保存抹掉；自检报「yyp 未注册」。
- **正确路径**：先关 IDE；被抹后重跑注册脚本（按 path 去重、只增不删）。

### C15 在 IDE 里打开字体资源点「确定」
- **现象**：重新栅格化，把 `font_fill.py` 补进去的字形冲掉。
- **正确路径**：补字只用脚本，别在 IDE 打开字体资源。

### C16 `undefined` 参与乘法 → 静默变 0
- **正确路径**：可能未定义的量在 `obj_mod_manager/Create_0` 里先落默认值（`global.hex_mult = {atk:1.0,...}`）；实例变量先 `variable_instance_exists`。

### C17 脚本生成 sprite 时每帧新建 layer → 幽灵图层
- **现象**：`.yy` 声明 6 个 `GMImageLayer`（同名 `default`），每帧只有 1 张图 → 36 条引用缺 30。
- **正确路径**：同一 sprite 的所有帧共用 `layers[0]`；`layers` 恒为 1 条（多图层例外）。
- **证据**：2026-11-05 日志。

### C18 分类表没加自己那一行 → 按分类的增幅/词条全落空
- **正确路径**：新卡在 `card_category_data()`（`card_buff_category.gml:41-252`）补一行；吃增幅还要在 `mod_apply_category_buff_map` 的 `_allowed`(:367-374) 或 `plant_buff_map_2` 副类型挂名字。

### C19 改任务看板首行 y / 可见行数只改了一个文件 → 行串位或叠到可见区
- **症状**：新加的页签压住第一行；或者任务一多，未定位的行按 Create 时的 y 全叠在可见区上。
- **错路**：只把 `obj_task_bg/Create_0` 的 `y-130` 改成 `y-65`，忘了 `obj_task_line_bg/Step_2.gml` 里 `y_offset + 10` 的上界和 `Mouse_60/61` 的步长。
- **正确路径**：三处必须同改 ——
  1. `objects/obj_task_bg/Create_0.gml` 建行 y（`y-65+52*i`）；
  2. `objects/obj_task_bg/Mouse_60.gml` / `Mouse_61.gml` 的步长与边界（现为 9）；
  3. `objects/obj_task_line_bg/Step_2.gml` 的可见上界（`y_offset + 8`）+ **`else { y = -9999 }`**（原版靠「行数 ≤ 可见数」隐式成立，不加兜底就会叠）。
- **证据**：2026-11-13 加第 4 页签「卡片情报」时，首行 410→475、可见 11→9。

### C20 动态任务 id 让 `get_task_data` 返回 `undefined` → 看板/领奖崩
- **症状**：进战斗或在看板点开卡片情报任务时报 `array_length` 相关错误，或详情面板显示上一条任务的内容。
- **根因**：卡片情报任务 id 是 `info_view_<card_id>`，卡被清掉（`cleanup_orphan_cards`）后注册表里没了，但 `global.save_data.tasks` 里还留着条目。
- **正确路径**：所有拿 `get_task_data(x)` 结果用之前先判 `undefined`：
  `obj_task_manager/Create_0.gml` 的 `refresh_task_progress`、`obj_task_bg/Create_0.gml` 的 `check_card_upgrade` 与 `refresh_task_list`、`obj_task_claim_btn/Mouse_4.gml`、`obj_task_line_bg/Draw_0.gml` 与 `Mouse_4.gml` 的 `btn_index` 越界判断、`obj_task_bg/Draw_0.gml` 的 `target_task_index` 越界判断。
- **证据**：2026-11-13 `scripts/task_edit/task_edit.gml:145-182` 用动态 id；防护分别落在 `objects/obj_task_manager/Create_0.gml:43`、`objects/obj_task_bg/Create_0.gml:34`、`objects/obj_task_bg/Draw_0.gml:10-14`。

### C21 「没装宝石也在播变装立绘」→ 判定只扫 `gems` 数组，不看槽位是否真装着武器
- **症状**：只穿星之耀（或任意神装）时装、武器槽空着 / 装的是别的武器，进战斗放下人物照样播变身立绘。
- **根因**：`scripts/attire_transformation/attire_transformation.gml` 的 `player_has_gem()` 只看
  `equipped_items.{main,secondary,super}_weapon.gems` 数组里有没有这个 id。而
  `scripts/weapon_registry/weapon_registry.gml:155-172` 的 `remove_weapon()` **刻意保留 `gems` 数组**
  （注释写明：装回同一把武器时宝石原样还在，玩家不用手动重装）。于是「卸掉武器」后宝石 id 仍躺在数组里，
  判定照样 true。换武器时 `weapon_gems_reconcile()` 虽然会按 `allowed_weapons` 清不兼容的，但只要
  中途卸过武器、或旧版本存档留下的残留，就一直是 true。
- **正确路径**：判定加两条前置再用，缺一不可：
  ① 该槽 `id` 必须是非空字符串（真装着武器）；
  ② 必须 `gem_fits_weapon(_gem, _s.id, _slot_name)` 通过（同槽位 + `allowed_weapons` 命中）——
     与 `equip_gem()` / `weapon_gems_reconcile()` 用的是同一个判据，别另写一套。
  `player_has_weapon()` 不用改：星之神杖本体入场圈按原口径只看武器。
- **排查手法**：直接读 `%LOCALAPPDATA%\FVM_Reborn_makk\saves\save0.json`，把
  `equipped_items` 三槽的 `id` 与 `gems` 并排打出来 —— `id=""` 而 `gems` 非空就是残留，一眼定位。
- **反向教训**：任何「这个 id 在当前配置下发不生效」的判定，都不能只看 id 在不在数组里，
  要连「它所在的那个槽当前装的是什么」一起判。同类隐患排查点：`get_gem_index()`（`weapon_registry.gml:283-290`）
  同样只扫数组，UI 侧已由外层的 `if (... .id != "")` 挡住，但脚本层没有。
- **证据**：2026-11-14；`scripts/attire_transformation/attire_transformation.gml:46-71`、`scripts/weapon_registry/weapon_registry.gml:33-44 / 105-122 / 152-172`。

### C22 某张卡的增幅「一点都没吃到」→ `plant_buff_map` 里没有它的条目
- **症状**：把增幅卡（如宴飨女神 / 塔利亚）摆在目标卡旁边，目标卡攻击力一点没变；换别的目标卡同样的摆位又生效。
- **错路**：以为「把卡归到某个分类」就等于进了增幅名单，去 `_allowed` 里找、去 `plant_buff_map_2` 里补，都没命中。
- **根因**：增幅结算链是 `mod_get_buff_type(plant_id)` → `global.plant_buff_map` 查表 → `obj_mod_battle_manager/Step_0.gml` 的
  `switch (self.buff_type)` 挑对应网格。**必须在 `plant_buff_map` 里有条目**才会走到任何一格；
  没有 → 返回 `"normal"` → switch 落 `default` → `buff_multiplier` 恒 1，静默无报错。
  银河马（`galaxy_horse`）就是这种：`card_category_data()` 只有一行「灰烬类·轰炸类」，
  `mod_apply_category_buff_map()` 只扫投掷 / 追踪 / 多向 / 喷壶 / 五向这几个分类组，
  灰烬-轰炸整类都不在扫描范围里，而数值表 115 行脚注明写「受精灵龙&宴飨女神增幅」。
- **正确路径**（一步到位，2026-11-14 用户最终口径：**别新建 type，直接归到追踪类**）：
  1. `rg -n "<plant_id>" scripts/card_buff_category scripts/mod_buff_init` —— 搜不到条目就是本条命中；
  2. 在 `mod_apply_category_buff_map()` 末尾补一行 `ds_map_set(global.plant_buff_map, "<plant_id>", "tracker")`，
     让它吃 `tracker` 这一格（`obj_mod_battle_manager/Step_0.gml` 的 `case "tracker"` 已经取
     `max(buff_grid, buff_stack_grid)`，至尊形态的叠加倍率天然生效）；
  3. 不需要动 `build_buff_grid()` 的 `types` 数组、不需要加 `case`、不需要动 `apply_buff()` —— 这几处是共用通道。
- **被否掉的路**：自己新开 `tracker_yanxiang` 专属档（types 数组 + `apply_buff` 写入 + 两个 switch 各加 case + 挂名，四处同改），
  理由是「tracker 是莓果点心/香料虎/塔利亚共用的，挂进去会连带吃它们的增幅」。**用户 2026-11-14 明确否掉**：
  这类卡就按追踪类处理，共格是接受的口径；四处同改引入的静默失效面（漏一处就倍率恒 1）不值得。
- **反向教训**：任何「某张卡吃不到某个增幅」的排查，第一步永远是**确认目标卡在 `plant_buff_map` / `plant_buff_map_2` 里的条目是什么**，
  而不是从增幅源对象开始查。增幅源只负责往网格里写数，读不读是目标卡自己的 `buff_type` 决定的。
- **证据**：2026-11-14；`.workbuddy/tmp/xlsx_dump.txt:88`（数值表 115 行「受精灵龙&宴飨女神增幅」）、
  `scripts/card_buff_category/card_buff_category.gml:198`（银河马分类行）、
  `scripts/mod_build_buff_grid/mod_build_buff_grid.gml:38`、`objects/obj_mod_battle_manager/Step_0.gml:114-260`。

### C23 「打不到非主流 / 幽灵」这类口径，只靠 target_type 白名单一定漏 → 必须按身份再排一次
- **症状**：卡面（或数值表）写「无法攻击非主流鼠 & 幽灵鼠」，卡的白名单里也确实没写 `dance` / `invisible`，
  但游戏里这张卡照样索敌、照样命中非主流鼠。
- **错路**：
  1. 以为白名单有 `dance` 排除就够了，去 `gh_hittable` / `hittable_types` 数组里反复确认，没问题；
  2. 以为 `target_type` 是常量，只看敌人的 `Create_0`（那里确实写着默认 `"normal"`）。
- **根因**：非主流家族（`obj_non_mainstream_mouse`、1:1 仿它的 `obj_ly_gaoqiao`、跨服 `obj_kf_zr_nonmain`）
  **在 `Step_0` 里按状态逐帧改 `target_type`**：啃食（`ENEMY_STATE.ATTACK`）时改成 `"normal"`，
  其余时候 `"dance"`（三处都是 `Step_0.gml:3-8` / `:5-6`）。啃食那一瞬间它就是一个普通陆鼠，
  白名单里的 `dance` 排除完全失效 → 卡片照常索敌命中。幽灵鼠正相反：`obj_ghost_mouse/Step_0.gml:38-49`
  在光照足够时把 `target_type` 改成 `"normal"`（**这时它本来就该被打到**），所以「幽灵」不能按身份一律排除。
- **正确路径**：区分「按类型」和「按身份」两类口径
  1. **类型口径**（normal/dance/air/…，会随状态变）→ 用 `target_type` + 白名单，够用；
  2. **身份口径**（非主流、幽灵这种「这一类老鼠」，与当前状态无关）→ 写一个按 `object_index` + `mouse_id`
     的判定函数，在**索敌、候选收集、落地结算、单实例入口**四处统一调用。
     本仓现成入口：`is_non_mainstream(_inst)`（`scripts/can_target_on/can_target_on.gml:79`），
     覆盖三只非主流（`obj_non_mainstream_mouse` / `obj_ly_gaoqiao` / `obj_kf_zr_nonmain`），
     `mouse_id` 兜换皮与派生。银河马的四处调用点：`objects/obj_galaxy_horse/Create_0.gml`（`gh_can_hit`、
     `gh_has_target`）、`objects/obj_galaxy_horse/Other_11.gml`（收候选）、
     `objects/obj_galaxy_horse_bullet/Step_0.gml`（落地结算，两处：全额目标回退分支 + 溅射循环）。
- **反向教训**：任何「某类敌人打不到 / 打得到」的口径，先去那只敌人的 `Step_0` 里 `rg target_type`，
  看它有没有**逐帧改写**。有改写 → 类型白名单不可靠 → 按身份判。抄卡面口径时也别信 Create 里的默认值。
- **证据**：2026-11-14；`objects/obj_non_mainstream_mouse/Step_0.gml:3-8`、`objects/obj_ly_gaoqiao/Step_0.gml:5-6`、
  `objects/obj_kf_zr_nonmain/Step_0.gml:3-8`、`objects/obj_ghost_mouse/Step_0.gml:38-49`、
  `scripts/can_target_on/can_target_on.gml:79-89`、`.workbuddy/tmp/xlsx_dump.txt:89`（数值表 116 行「无法攻击非主流&幽灵鼠」）。

---

### C30 新增不占格（gridless）卡能「同一格无限叠」→ 少登记 `place_mutex_class`
- **症状**：二转结界马是悬浮卡，同一格拖几张就叠几张（用户要求照海洋女神只留一张）。
- **错路**：以为要改 `can_place_at_position` 的 `case "gridless"` 分支（那里 `return true` 是故意的：
  悬浮卡之间本来就允许叠放，海洋女神 / 战旗马 / 星轨神都是靠前置白名单单个限制）。
- **正确路径**：加卡的「同格唯一」登记在 `scripts/place_mutex_class/place_mutex_class.gml`，
  一行 `case "<card_id>": return "<唯一类名>";` —— 该检查在 `can_place_at_position:108` 跑，
  **早于** gridless 分支与海克斯「万物皆可炸」分支，绕不过去；也自动尊重 `global.replace_placement`。
- **证据**：`scripts/place_mutex_class/place_mutex_class.gml:9-24`、
  `scripts/can_place_at_position/can_place_at_position.gml:108-117`。

### C31 新卡特效「盖在卡片前面」→ depth 要按 `calculate_plant_depth` 那套行距反着算
- **症状**：结界马的结界格 / 连线 / 多边形墙画在所有卡片前面，把卡糊住了。
- **错路**：按「特效要显眼」的直觉给了 `depth = -400` —— 这个工程里 depth **越小越靠前**，
  而卡片是 `-10 - row*45 - col*5 - 层偏移`（`scripts/card_depth`），全在 -10~-330，-400 直接冲到最前。
- **正确路径**：想压在卡片之下就取比卡片更大的值；跨多行的特效取「场上最上一行」的行基准再 +1：
  `depth = -10 - row_min*45 + 1`。`+1` 是为了不跟同格 gridless 卡同深度。上限别超过
  `obj_battle` 的 `+50`，否则掉到地图背景后面。
- **证据**：`objects/obj_jiejiema_field/{Step_0,Create_0}.gml`、`scripts/card_depth/card_depth.gml:6-31`、
  `objects/obj_battle/Create_0.gml:5`。

### C32 多边形特效「糊成一个方框」→ 贴图是方的，按包围盒拉伸裁不出斜边
- **症状**：结界马 3 只以上围出的结界，内部雾铺成一个方框、跑到连线外面，还叠着每格一块的方块。
- **错路**：指望「贴图自带形状」自己裁 —— `spr_jiejiema_fx_inside` 是 485×455 的方形图，四角也有 alpha
  （均值 56/255），按包围盒 `draw_sprite_ext` 拉伸时根本没有可用的斜边。
- **正确路径**：几何自己造 —— `draw_primitive_begin_texture(pr_trianglefan, tex)` +
  `draw_vertex_texture_color`，顶点用凸包、扇心用顶点质心，uv 用 `sprite_get_texture` + `sprite_get_uvs`
  前四个分量按包围盒线性映射；画不出的地方就是没有三角形，**不需要 surface / stencil**。
  贴图边缘渐隐，uv 要内缩 2%；想加浓就叠第二层（uv 收到中央 32%、alpha 调低）。
- **证据**：`objects/obj_jiejiema_field/Draw_0.gml:51-107`、
  `scripts/jiejiema_field/jiejiema_field.gml:276-303`。

### C33 上游新敌人「卡片打不到」→ 子对象 Step 不继承父事件，就不进 `enemy_by_type` 空间索引
- **症状**：合并 v3.1.0 沙漠之旅后，滑板鼠、以及 `anubis_mouse` / `medusa` / `ufo_mouse` 等新 BOSS 站在场上，卡片不攻击、子弹穿过去不掉血；老敌人一切正常。
- **错路**：先怀疑新敌人的 `target_type` 写成 `"land"`（注册表里的 `feature` 是 `"land"`），去改 `get_hittable_enemy_types`；也怀疑过 `enemy_map` 漏注册。两条都不成立 —— `get_hittable_enemy_types` 的键是 `target_type`（`"normal"`/`"air"`/`"obstacle"`…），跟 `feature` 无关。
- **正确路径**：mod 的命中系统只认 `global.enemy_by_type`（`target_type` → 实例列表），而**这张表只有 `obj_enemy_parent/Step_0.gml` 开头那段注册代码在填**。上游敌人对象自带完整 `Step_0`、**不调用 `event_inherited()`**（文件第一行 `// Inherit the parent event` 只是注释，真正的调用在少数几个对象里才有）→ 父 Step 不执行 → 永不注册 → `obj_battle/Step_2` 建出来的 `enemy_sx` / `enemy_col_n` 里没有它，卡侧读列内敌人数为 0 干脆不开火。
  照 `obj_face_cookie/Step_0.gml:6-24` 的既有写法，在每个「有自己 Step 且不继承父事件」的敌人 `Step_0` **最前面**补一段注册块（幂等：`enemy_registered` + `enemy_registered_type` 双守卫）。
  判定要**先剥注释再找 `event_inherited()`**，否则会被那句注释骗过去（本次 24 只新敌人里 11 只被误判成已继承）。
- **证据**：2026-11-22；`objects/obj_enemy_parent/Step_0.gml:6-26`（唯一注册点）、`objects/obj_face_cookie/Step_0.gml:6`、`objects/obj_battle/Step_2.gml:263-311`（索引建表）；本次补注册的 9 个：`obj_anubis_mouse`、`obj_awaken_medusa`、`obj_hermit_crab_mouse`、`obj_medusa`、`obj_sandboarding_mouse`、`obj_tribal_chief_mouse`、`obj_ufo_mouse`、`obj_witch_shaman_mouse`、`obj_cactus_mouse_bullet`。

### C34 合并进来的绘制代码读「本作用域不存在的变量」→ Draw Event 每帧报 not set before reading it
- **症状**：打开情报岛（敌人页签）立即报
  `Variable obj_info_island_bg._ca(104644, -2147483648) not set before reading it. at gml_Object_obj_info_island_bg_Draw_0 (line 362)`。
- **错路**：三方合并时上游那一行写的是 `sprite_clip_draw(..., _esc, _ca)`，把上游的 `_ca`（它在自己的循环里定义过）连同 mod 的 `_cell_alpha` 一起搬进了同一个 `for` 体；校验脚本只查 BOM 与括号配平，**查不出未定义变量**，直到运行时才炸。
- **正确路径**：合并「整段取自上游」的绘制/循环体后，逐行核对它引用的局部变量在本作用域的赋值点（`rg -n '_ca\b' <文件>`）。这里改成传本循环已有的 `_cell_alpha`（格子淡入透明度）语义等价。
  更通用的自检：合并后对改动行里的每个 `_xxx` 局部变量跑一次「定义行号 < 使用行号」的扫描，别等实机。
- **证据**：2026-11-22；`objects/obj_info_island_bg/Draw_0.gml:357`（`var _cell_alpha = cell_reveal_alpha(row,col)` 定义）、`:362`（修复点）。

### C35 同事件里别处写了 `var target_type` → 整个事件里的 `target_type` 都按局部解析，读实例字段要 `variable_instance_get`
- **症状**：给 `obj_sandboarding_mouse` 的 `Step_0` 最前面补了敌人注册块，实机一进沙漠关就报
  `local variable target_type(102436) not set before reading it. at gml_Object_obj_sandboarding_mouse_Step_0 (line 12) - var _reg_key = target_type;`
  —— 注意报的是 **local variable**，不是 `Variable obj_x.target_type`。
- **错路**：以为父对象 Create 没把 `target_type` 设上（它明明在 `obj_enemy_parent/Create_0.gml:42` 设了 `"normal"`），
  还想过去补 `event_inherited()`。
- **正确路径**：GML 里**同一事件作用域内只要出现过 `var target_type`，这个名字在整个事件里就都是局部变量** ——
  `obj_sandboarding_mouse/Step_0.gml:137,214` 的 `var target_type = ds_list_find_value(global.eat_order, i);` 就是这么把实例字段遮住的。
  读实例字段一律走 `variable_instance_get(id, "target_type")`（缺了给 `is_undefined` 兜底），别直接写名字。
  补这类「前置挂钩代码」前，先 `rg -n 'var <变量名>' <文件>` 确认没被同名局部遮蔽。
- **证据**：2026-11-22；`objects/obj_sandboarding_mouse/Step_0.gml:137,214`（遮蔽源）、`:5-9`（改用 `variable_instance_get`）、`objects/obj_enemy_parent/Create_0.gml:42`。

### C36 立绘裁剪表只按「原版注册脚本」生成 → 本工程自有的换皮美术不在表里，退回整张画布后整个飘出裁剪框
- **症状**：合并上游 3.1.0 的「情报岛立绘裁剪框 + 普通/BOSS 分级缩放」之后，原版老鼠正常，但本工程自己的换皮敌人
  （感染鼠 `spr_infected_*`、跨服鼠 `spr_kuafu_*`、龙渊 BOSS `spr_longzhu_*_icon` 等）在情报岛**完全看不见**（用户 2026-11-22 报）。
- **错路**：先怀疑「缩放太小 / 裁剪框太小」，去调 `enemy_scale_normal/boss` 与 `enemy_clip_w/h`；
  也怀疑过 `sprite_get_bbox_*` 是自动包围盒不准。实际两者都不是 —— 缩放到 1.0 也照样看不见。
- **正确路径**：`scripts/sprite_clip_draw` 的锚点是「内容包围盒水平居中 + 底边贴框底」，
  而包围盒来自离线表 `scripts/sprite_trim_get`（`tools/gen_sprite_trim.py` 生成）。**那个脚本原来只扫
  `scripts/enemy_init/enemy_init.gml`**，mod 的敌人注册在 `mod_enemy_init` / `longyuan_enemy_init` /
  `shuihuo_enemy_init` / `zhuore_enemy_init` / `wudu_enemy_init` 里 → 表里缺 103 条 → 缺条目的精灵退回
  **整张画布**贴底对齐；画布大、内容偏上的贴图（`spr_infected_submarine_mouse_land` 193×322、内容仅占 9%）
  就被整个推到裁剪框上方，一个像素都看不见。
  两条一起改：①生成脚本改为扫描 `scripts/` 下所有带 `spr` 字段的注册脚本（排除 `attire_init`，那是装扮），
  表从 158 → 366 条；②`sprite_clip_draw` 的包围盒加运行时兜底（离线表 → `sprite_get_bbox_*` → 整张画布），
  并把调用方给的缩放改成**上限**（内容超框时等比缩到刚好放得进）。
- **证据**：2026-11-22；`tools/gen_sprite_trim.py`（扫描范围）、`scripts/sprite_clip_draw/sprite_clip_draw.gml:53-84`（三级回退 + `_fit`）、
  `objects/obj_info_island_bg/Create_0.gml:39-51`、`objects/obj_mouse_preview/Create_0.gml:7-19`。

### C37 全服安卓设备识别码都是 `E52D26F9B8`：没 `randomize()` 时 `irandom` 序列是定死的

- **症状**：`scripts/auth_client/auth_client.gml` 的安卓识别码（`auth_hwid.dat` 里那 8 位正文 + 2 位校验）在所有设备上都一样，玩家报「不同的设备都是同一个码 E52D26F9B8」。
- **错路**：以为 `irandom(15)` 就是"随机"、每台设备自然不同。实际本工程**全仓一次都没调用 `randomize()`**（`rg -n "randomize|random_set_seed|random_get_seed" objects scripts` 只命中 `__scribble_*` 里的同名变量，与 RNG 无关），GameMaker 在未 randomize 时 RNG 种子固定 → 每台设备第一次运行都吐出同一串。更坑的是老代码已经把这个值写进了每台设备的 `auth_hwid.dat`，**只改生成算法不改文件名，老文件会被原样沿用，等于没修**。
- **正确路径**：三层一起改，缺一层都还会撞。
  1. 生成改走 `auth_random_hex(_len)`（`scripts/auth_client/auth_client.gml:248`）：熵源 `auth_entropy_mix()` 取 `get_timer()` / `current_time` / `date_current_datetime()` / `game_save_id` / 自增 tick / 分辨率 / DPI / `os_get_info()` 六键，再逐轮 `md5_string_utf8(熵 + "|" + 轮次)` 派生。**RNG 只借一次，且 `random_set_seed(_seed)` 的还原必须放在 `randomize()` 的 try 外面**——异常路径也要还原，否则游戏带着随机化后的种子继续跑，等于越权改行为。
  2. `#macro kAuthHwidFile "auth_hwid2.dat"`（`:69`）换文件名，逼老设备重摇；老 `auth_hwid.dat` 留着当排障线索。
  3. `#macro kAuthHwidBadA "E52D26F9"` / `kAuthHwidBadB "00000000"`（`:73-74`）拉黑撞车值，读到就重置重摇（`auth_hwid_android()` 里 `_guard < 16` 重试）。
  另：原本写的「8 位旧正文就地升级成 10 位」必须改成**直接重置**——那个值八成就是 `E52D26F9`，升级等于把 bug 保留下来。
- **证据**：`scripts/auth_client/auth_client.gml:185-257`（熵源与派生）、`:69-74`（宏）、`:364-429`（分支与黑名单）、`tools/qq_auth.py:120 hwid_check()`（`E52D26F9 → B8` 可复现），2026-11-24 现网反馈。
- **连带**：任何要随机的字段都不许直接 `irandom` 拼——`auth_install_id()` 原来用 `string(irandom(...)) + "|" + string(current_time)` 做种子，同一个坑，也一并改成 `auth_random_hex(16)`。

## D. 契约与流程（自己的规矩没守）

### D1 改了文件没跑 `verify_gml.ps1`
- **后果**：BOM/括号问题留到 IDE 编译才炸，定位成本翻十倍。
- **正确路径**：改完立刻 `powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_gml.ps1 <路径>`。
- **已知误报**：`verify_gml.ps1` 校验它自己会报 `[] 28/29`（正则/类型加速器的方括号），忽略。

### D2 引用不存在的章节号
- **案例**：`AGENTS.md` 与 `verify_gml.ps1` 头部都写「第 2.2 条」，而现行文件只有 §1.2 → 编号漂移。
- **正确路径**：引用章节一律写 `§x.y`，改章节结构时全仓 grep 一次旧编号。

### D3 契约文档里写「示例数字」
- **案例**：`SKILL.md` 写过「283 行 / 30431 B」当示例，subagent 可能直接照抄。
- **正确路径**：一律写 `<实测行数>` / `<实测字节>` 占位。

### D4 只在对话里下结论，没落盘
- **后果**：下一轮/下一个 agent 重新踩。
- **正确路径**：结论进 `AGENTS.md`（契约）或 `.workbuddy/memory/topics/`（细节）或本文件（错误路径）。

### D5 明知文件是 CRLF，还用 LF 字符串去 python 里做替换
- **症状**：`AssertionError: show-dirs body`，而 `grep` 明明能搜到那段文本。
- **错路**：`io.open(..., newline="")` 读进来是带 `\r\n` 的串，`old` 却按 `\n` 拼。
- **正确路径**：读后立刻 `s = raw.replace("\r\n", "\n")` 再比；写回前 `s.replace("\n", "\r\n")`（`.ps1` 还要 `utf-8-sig`）。这是 A4 的复发——**改 `.ps1` 前先看 A4**。
- **证据**：2026-11-13 `tools/lookup.ps1` 打补丁时第二次踩。

### A18 生成脚本中途报错后直接重跑，留下半成品残留
- **症状**：`cross_new_maps_import.py` 第一次跑在「文件已复制、`.yy` 未写出」处崩溃；重跑后目录里多出 yy 不引用的孤儿帧 png；另一个 0 字节的文件夹 `.yy` 是 `open('w')` 先建空文件、模板 `%` 格式化才报错留下的。
- **错路**：脚本幂等检查用「目录/文件是否存在」当跳过依据，没校验「已存在的内容是否完整、是否与引用一致」。
- **正确路径**：① 生成类脚本的跳过条件要对准**实际交付物**（yy 存在且可解析、帧数与图像数一致）；② 中断过的输出先清理再重跑；③ `with open(...)` 的内容参数在求值阶段就可能抛错（如 `TMPL % dict(...)`），先格式化后 open；④ 收尾自检清单：`yyp` resources/Folders、yy JSON、顶层合成图与 `layers/<帧>/<层>.png` 数量与 md5。
- **证据**：2026-11-14 跨服新地图导入，`spr_bingfengyiji_0` 孤儿帧 + `folders/精灵/mod/Cross Server/bingfengyiji.yy` 0 字节，清理重建后自检通过。

### A19 照抄对象时透传原版 .yy 里错误的 spriteId
- **症状**：`obj_dragon_boat_mouse` / `obj_flagship_mouse` 的 `.yy` 里 `spriteId` 本来就误指向 `spr_rowboat_mouse`（运行时 Step_0 立即改 sprite_index 才没暴露）；照抄脚本按「原名→新名」映射替换，映射里没有的名字原样透传 → 新对象引用了别的章节的精灵，自检才抓到。
- **正确路径**：照抄对象时 `spriteId` 一律显式指向自己的 main 精灵（`smap.get(x, main)`），不要信任原版 `.yy` 的指向；同理凡「原版数据本身有错」的字段（spriteId / origin / move_speed 取整）都要在规格里显式覆盖，并跑结构自检（spriteId 必须以自身 id 开头）。
- **证据**：2026-11-14 跨服新章节小怪导入，`obj_kf_sh_dragon_boat` / `obj_kf_sh_flagship` 首轮 spriteId=spr_rowboat_mouse，自检 `FAIL spriteId` 后修复。

### A20 换皮 BOSS 锚点逐帧算 + 忘映射代码里的对象引用
- **症状**：① 同一 BOSS 的 appear 锚点与其他精灵差 170px（appear 首帧是走进的小老鼠，bbox 和绿巨人完全不同）；② 新钢铁侠 SKILL2/SKILL3 拉出来的是**旧版** `obj_iron_man` / `obj_iron_man_bullet`（代码照抄只换了精灵名映射，对象名没换）。
- **错路**：每个精灵用自己的首帧 bbox 算锚点；对象克隆只做 `spr_xxx → spr_new` 替换。
- **正确路径**：① 同画布的身体精灵一组**只算一次锚点**（取待机参考帧），全组共用；② 克隆后用 `rg -o "obj_[a-z_0-9]+" 新对象/*.gml` 列清单，凡旧 BOSS 专属对象（激光体/子弹/伴随特效）必须映射到克隆；③ 分段重采样以「输出帧数 == 原版精灵帧数」为硬约束（代码 mod N 硬编码）。
- **证据**：2026-11-14 变异钢铁侠/绿巨人导入，`obj_kf_sh_iron_man/Step_0.gml:194/276` 首轮仍指向旧对象，复查清单后修复。

### A21 判断「大怪残血闪一下」错当成状态机/精灵分带问题，实际是受击白闪的叠加方式
- **症状**：用户报「变异特种鼠满血走着走着突然闪现一下残血状态」。血条一直是 51840→51090→49590，从没接近 `maxhp*hurt_rate`（25920），说明视觉变化与血量无关。
- **错路（当轮实际走过）**：先怀疑 ① `Step_0.gml:18` 的投掷阈值 `hp <= maxhp*hurt_rate` 误触发；② NORMAL↔ACTING 的 `image_index` 分带来回跳；③ `obj_pool` 复用残留 alpha。三条都被代码检查 + 精灵分带实测否定（0..20 vs 21..41 逐像素差只有 4.4~5.8，受伤带不改剪影）。
- **正确路径**：**先量化「变了什么」，再猜代码**。对视频帧做双模型拟合（`b = a*(1-t) + 255*t` 白覆盖  vs `b = a*s + bg*(1-s)` 整体透明），对**深色描边像素**（`max(rgb)<90`，原画那里本来是黑边）看哪条模型残差小：实测 p_015 描边 `53,51,58 → 159,157,156`，白覆盖 t=0.51、透明模型 s=-0.09（不可能）→ 判定是**白覆盖**。据此一步定位到 `obj_enemy_parent/Draw_0.gml:5-9` 的受击 shader。
- **证据**：2026-11-14 视频分析，`.workbuddy/tmp_vid/outline.py` 输出；`git diff objects/obj_enemy_parent/Draw_0.gml`。

### A22 本机 ffmpeg 是裁剪版，视频抽帧只能走 WPF MediaPlayer
- **症状**：`ffmpeg -i x.mp4 -vf fps=10 out_%03d.png` 报 `Unable to choose an output format`；`-filter_complex crop=...` 报 `No option name near '380:500:1400:240'`；`pip install imageio-ffmpeg` 无网络卡死。
- **错路**：以为装了 ffmpeg 就能抽帧/裁剪；`CroppedBitmap` + `RenderTargetBitmap` 也想直接出小图，结果 png 全是 0 字节（`NotSupportedException`）。
- **正确路径**：① 该 ffmpeg（`Trae CN/resources/app/bin/ffmpeg.exe`）只有 mov/mp4 muxer + libx264 + scale/fps/trim 几个滤镜，**没有 image2、没有 crop**，用来抽帧必失败；② 抽帧只能 `Add-Type PresentationCore` + `MediaPlayer` + `RenderTargetBitmap`（可用脚本 `.workbuddy/tmp_vid/grab.ps1` seek 版、`grab2.ps1` 连播版）；③ **只能抓全幅再离线用 Pillow 裁**，直接 `CroppedBitmap` 会静默产出 0 字节；④ 本机无网，不要 `pip install` 任何包。
- **证据**：2026-11-14 `.workbuddy/tmp_vid/` 下 `raw/`、`sm/`、`crop3/` 三次 0 字节产出。

### A23 `Get-ChildItem objects -Filter *.yy` 不递归 → 扫出 0 个子对象，白跑一轮
- **症状**：写脚本统计「`obj_card_parent` 的所有后代里哪些 `Create_0` 没写 `event_inherited()`」，输出 `descendants=0`，明明有 232 个。
- **错路**：`Get-ChildItem objects -Filter *.yy` —— `objects/` 下没有直接放 `.yy`，每个对象在子目录里，不加 `-Recurse` 就是空集。
- **正确路径**：按 §0.0 的路径公式拼：`Get-ChildItem objects -Directory | ForEach-Object { Join-Path $_.FullName ($_.Name + '.yy') }` 再 `Test-Path` 过滤；或直接 `rg -l --pcre2 '"parentObjectId":\s*\{\s*"name":"obj_card_parent"' -g '*.yy' objects`。**先看输出条数是不是 0，是 0 先怀疑遍历方式，别怀疑结论。**
- **证据**：2026-11-14 排查 `have_loder` 崩溃时第一次统计输出 `descendants=0`。

### A24 子对象 `Create_0` 没 `event_inherited()` → 父 `Create` 里的字段在它身上根本不存在
- **症状**：`Variable obj_player_character.have_loder(112628, -2147483648) not set before reading it.`（`obj_repairman_mouse/Step_0.gml:39`）。字段在 `obj_card_parent/Create_0.gml:62` 明明写着 `have_loder = false`。
- **错路**：只 `rg have_loder` 看到父对象有定义，就以为所有卡片实例都有这个字段。
- **根因**：`obj_player_character`（以及它代表的这类「自己重写 Create 的人物/特殊卡」）`Create_0.gml` 没有 `event_inherited()` —— 父 `Create` 一行都不执行，父对象声明的所有字段（`have_loder`、`_prev_hp`、`shape`…）在这份实例上都不存在。工程里刻意如此（父 `Create` 会重置 hp/grid/state 一整套，人物用自己那版数值），见 `objects/obj_player_character/Other_12.gml:4` 注释里同类结论。
- **正确路径**：① 凡是「遍历 `global.grid_plants` / `obj_card_parent` 后直接读字段」的地方，一律 `variable_instance_exists(_p, "字段") && _p.字段`（`obj_enemy_parent/Step_0.gml:132/154` 早就是这个写法，照抄）；② 新字段若必须被这类对象读到，在它自己的 `Create_0` 里补一份默认值；③ 判定「子对象有没有父字段」用 §0.0 的遍历脚本一次查全，别逐个猜。
- **证据**：2026-11-14 修理工鼠放梯子崩溃；`objects/obj_player_character/Create_0.gml`（补 `have_loder = false`）、`objects/obj_repairman_mouse/Step_0.gml:39`、`objects/obj_undersea_repairman_mouse/Step_0.gml:39`。

### C24 按名字猜「水鼠 / 陆鼠」，把突袭鼠、蝴蝶鼠当陆地怪投进无水关卡
- **症状**：给跨服章节配波次时，水鼠数量与「水行占比」怎么算都对不上；把 `assault_mouse` / `butterfly_mouse` 放进陆地章节，游戏里会报 `错误：没有适合water敌人的行！` 并全挤到第 1 行。
- **错路**：凭中文名/外观判断水陆（「突袭鼠」听着是地面冲过来、「蝴蝶鼠」像飞的）。
- **正确路径**：水陆**只认 `global.enemy_map[? id].feature`**（`obj_battle/Create_0.gml:317-386` 按它强制分派行；`row=-1` 才走自动分派）。一次性导出全表：`rg -n 'register_enemy\(' scripts | ...` 抽 `feature`；注意单行式注册写的是 `"feature":"land"`（带引号的键），多行式是 `feature: "land"`，正则要写成 `"?feature"?\s*:\s*"([^"]*)"`，否则 200+ 条会被误判成「未登记」。实测 `assault_mouse`（突袭鼠）、`butterfly_mouse`（蝴蝶鼠）、`frog_prince_mouse`、`diver_mouse` 全是 `water`。
- **证据**：2026-11-14 重排 `shuihuo_0..7` / `wudu_0..7`；`scripts/enemy_init/enemy_init.gml:23-24`（突袭鼠/青蛙王子 feature=water）。

### C25 安卓上「Mod 卡片已生效，但 Mod 管理器列表里没有这个包」
- **症状**：`external_mod_load_all()` 注册成功、卡片在战斗里能用，`obj_mod_menu` 打开的列表却是空的（或少了那几个包）。看起来像「管理器没扫到目录」，实际两条路径不同源。
- **错路**：只盯 `get_mod_root()` 的探测结果，认为界面和加载器读同一个函数就必然同一个目录；反复改路径判定，列表照旧空。
- **正确路径**：**列表取三路并集**，不要只信界面自己那次 `file_find_first` ——
  ① 磁盘扫描 `scan_mod_folders()`（空结果时补一次 `fa_directory` 枚举，安卓 `external_mod_find_flags()` 退化为 `0`，子目录未必带出）；
  ② `global.external_mod_loaded`（加载器真正注册成功的包名）；
  ③ `global.external_mod_errors`（存在但校验失败）。
  另外：界面顶部常驻 `目录：<mod_root>` 让玩家自查；`save_state()` 必须过滤 `missing`/`failed` 占位行，否则它们带着 `enabled=false` 落盘，下次启动把能用的 Mod 静默关掉；新包默认开启用 `!state_read_failed`，别用 `state_default_enabled`（有状态文件时恒 `false`）。
- **证据**：2026-11-14；`objects/obj_mod_menu/Create_0.gml`（`scan_mod_folders()` / `refresh_mods()` 三路并集 / `save_state()` 过滤）、`objects/obj_mod_menu/Draw_0.gml:31`、`scripts/external_mod_system/external_mod_system.gml:529-545`、调试行 `[Mod menu] root=… folders=… listed=… loaded=…`。

---

### A26 安卓 `file_find_*` 返回完整路径 → 所有「按名字拼路径」的枚举口全部失灵
- **症状**：文件管理器里 `/Android/media/com.company.game/files/mod/<包>/manifest.json` 看得见，游戏里 Mod 管理器显示「还没有安装 Mod」，加载器也一个包都没注册；`directory_exists(<mod_root>)` 为真而 `android_dir_entry_count` 为 0。
- **错路**：认定「路径选错 / 权限不够 / 目录没建出来」，反复改 `get_mod_root()` 探测、加 `fa_directory` 二次枚举、加加载器与界面并集——都不解决，因为这些写法都建立在「条目是名字」这个前提上。
- **正确路径**：① 安卓/iOS 的 `file_find_first/next` 返回**带目录的完整路径**，Windows 只返回名字；任何 `_dir + "/" + _f` 在安卓上都会拼成 `…/mod//storage/emulated/0/…`。② 统一走 `NativeUtil.android_list_dir(_dir, _dirs_only)` → `[{name, path, is_dir}]`（`name` = 最后一段，`path` 直接用），只取子目录名用 `android_list_subdirs`。③ 掩码跑两遍 `[fa_directory, 0]` 再按名字去重：`fa_directory` 在非 Windows 无效，Windows 的 `0` 只带普通文件，单跑任一遍都会漏。④ 新增枚举口后 `rg -n "file_find_" scripts objects` 把所有「拿条目名拼路径」的地方换掉。
- **证据**：2026-11-14 用户反馈「mod管理器还是看不到实际的mod」；`scripts/NativeUtil/NativeUtil.gml:109-208`（三个新口 + `.nomedia`）、`scripts/external_mod_system/external_mod_system.gml:35-46 / :275-291 / :590-615`、`objects/obj_mod_menu/Create_0.gml:78-90`。

### A27 上游同步 `git reset --hard` 会抹掉未提交改动 → 用户复测「根本没这个文件」
- **症状**：上一轮明确改过并自检通过的文件，下一轮 `git diff` 里没有；`rg` 搜不到自己刚写进去的函数名；用户复测时行为与改动完全无关。
- **错路**：怀疑自己改错副本、怀疑 APK 没重打包，继续在原地重做一遍——大概率下一轮再被抹一次。
- **正确路径**：① 先 `git reflog -8`，看到 `reset: moving to <sha>` 就是被硬重置；② 重做改动；③ 立刻 `git diff > .codex-tmp/<主题>-<日期>.patch` 留快照（不入库、不污染 git），需要时 `git apply`；④ 告诉用户「要长期保留必须提交」，提交由用户决定。
- **证据**：2026-11-15 `git reflog`：`49ab6cc2b HEAD@{0}: commit: Revert ...`、`4770af7a1 HEAD@{1}: reset: moving to 4770af7a1`、`4770af7a1 HEAD@{4}: reset: moving to 4770af7a1`。

### C26 `combat_targets_row()` 缓存里留着已回收的 id → `with (id)` 处 `Unable to find instance for object index`
- **症状**：战斗中点出错框 `Unable to find instance for object index 100345`，栈顶是 `gml_Script_combat_enemy_nearest_in_row` → `gml_Object_obj_stinky_tofu_pult_Step_0`。对象池开着时偶发，关池就复现不了。**2026-11-15 第二次出现**：修好的提交 `135f733c6` 被 `49ab6cc2b` 整份 revert（同一批改动被上游 `git reset --hard` 抹过，见 A27），源码回到未修状态，于是原样复发。
- **错路**：以为是敌人 `Destroy` 没清 `target_plant`／`enemy_by_type` 没注销，去查 `obj_enemy_parent/Destroy_0.gml`；那几处都正常。真正的入口是 `combat_targets_row()` 返回的 id 数组。
- **正确路径**：三条一起做，缺一条仍会复发 ——
  1. **缓存失效不能只靠 Destroy 事件**：`obj_pool_release()` 走的是 `instance_change(obj_pool_holder, true)`（**不会**触发 Destroy），而 **97 个敌人子对象的 `Destroy_0.gml` 没有写 `event_inherited()`**（`obj_enemy_parent/Destroy_0.gml:1` 的 `combat_targets_invalidate` 根本不执行）。在 `obj_pool_release()` 里显式 `combat_targets_invalidate(_obj)`；同理 `obj_pool_destroy_native()`（真销毁）与 `obj_pool_clear()` 也要补。
  2. **查询函数不要 `with` 别人的 id**：`combat_targets_row()` 只用 `instance_number` 做重建判据，而「池回收一个 + 池取用一个」计数不变 → 缓存留着死 id。落地：新增 `combat_targets_is_live(_inst, _base)`（先 `is_real` 卡类型 → `instance_exists` → 用 `object_exists(_inst)` 排除对象索引 → 最后按 `object_index`/`object_is_ancestor` 判身份；**`instance_exists(对象索引)` 恒为真，不排掉下一行 `_inst.object_index` 必炸**）与 `combat_targets_prune()` / `combat_targets_row_compact()`，三个查询函数改成逐个直读字段、扫到死 id 才整理那一行。不要无条件每帧剪枝（每帧 × 每卡 × 每行都多一趟）。
  3. **存下来的目标 id 一律用 `combat_live_or_noone(inst, base)` 包一层再 `with`**：`with (noone)` 是空操作，天然安全。已覆盖 `with (target_plant)` 14 处、`with (target_instance)` 1 处（`obj_ice_god_bullet/Step_0.gml:15`）、`with (target_enemy)` 1 处（`obj_rongheshuanggu_bullet_air/Step_0.gml:34`）及 20 处 `instance_exists(target_instance)`；另 16 处子弹/射线类 `with (存下来的 _e/_hit/_best)`，全工程共 32 处。**光改 `combat_targets` 的查询函数不够**：命中目标一旦被存成实例变量、下一帧再 `with`，池回收后同一 id 被复用，照样崩。候选表是「本 step 早段快照」的循环（`obj_zodiac_projectile/Step_0.gml:112`、`obj_yinghuoshe/Step_0.gml:24` 与 `:55`）要在进循环先 `if (!combat_targets_is_live(x, obj_enemy_parent)) continue;`，因为前一条的 `event_user(0)` 结算可能打死下一条。
  4. **别指望「改了源码就修好」**：报错行内的 `with` 在当前工作区已为 0 时，说明玩家跑的是旧 APK。先核 `rg -c "with" scripts/combat_targets/combat_targets.gml` 与报错栈，再让用户重新打包复测，不要继续在源码里找第二条路径。改完立刻提交或 `git diff > .codex-tmp/…patch` 存快照（A27）。
- **证据**：2026-11-14 首次崩溃（index 100563）、2026-11-15 复发（index 100345，同为 `obj_stinky_tofu_pult` / `combat_enemy_nearest_in_row`）；`scripts/combat_targets/combat_targets.gml:30-58`（`is_live` / `combat_live_or_noone`）、`:60-110`（`prune` / `row_compact`）、`:146-165`（`nearest_in_row` 直读）、`scripts/obj_pool/obj_pool.gml:175-196`（回收前失效）、`:224-239`（真销毁前失效）、`:272-281`（清池全体失效）；97 个缺 `event_inherited()` 的敌人 Destroy_0 由「解析 `.yy` 的 `parentObjectId` 遍历 313 个敌人」实测得出。

### C27 `.nomedia` 不生效 ≠ 写失败：已入库的相册行不会消失，必须换存储位置
- **症状**：`.nomedia` 写进去了（或没写成），相册里 Mod 的 png 依旧显示。
- **错路**：反复增强 `.nomedia` 的递归深度、重试、清媒体库；换台机器又复现。
- **正确路径**：把「被媒体扫描的目录里躺着 png」这件事本身消掉——`external_mod_hide_assets(root)` 把 `png/jpg/jpeg/gif/webp/bmp` 搬进 `<包>/.assets/<原相对路径>` 并删原文件；MediaProvider 扫描跳过以 `.` 开头的目录，这是确定性行为，不依赖机型与 `.nomedia` 支持。`external_mod_path()` 优先返回 `.assets` 路径，校验与 `sprite_add` 无需改动。
- **证据**：2026-11-15 用户反馈「没有创建这个文件，还是被相册读取了」；`scripts/external_mod_system/external_mod_system.gml:101-166`（`external_mod_assets_dir` / `is_media_relative` / `hide_assets` / `_walk` / `external_mod_path` 的 `.assets` 优先）、`:614-620`（加载前搬动）、`scripts/external_mod_import/external_mod_import.gml:198-206`（导入收尾搬动）。

### A28 上游同步把 `os_type != os_android` 守卫整段吃掉 → 编译通过、安卓才炸
- **症状**：某轮同步后 `objects/obj_file_manager/Step_0.gml` 的 5 处 `os_type != os_android` 前缀消失（`git show HEAD:<path>` 有 5 处、现值 0 处），GMS 编译零报错，安卓真机调 `native_enable_ime` / `native_stop_mouse_limit` 这类 Windows-only 扩展函数。
- **错路**：以为「编译过了就没事」，或以为 `global.ime_block` 会兜住全部调用点 —— `global.ime_block` 在 `objects/obj_game_init/Create_0.gml:190` 确实是 `os_type == os_windows && ini_read_bool(...)`（安卓恒 false），IME 那几处被短路，但 `native_stop_mouse_limit` 的两次调用（`:72` / `:104`）**不受 `ime_block` 保护**，必须自己加平台判定。
- **正确路径**：每轮同步后固定跑两步 ——
  1. `git grep -l -F "os_type != os_android" HEAD -- '*.gml'` 取 HEAD 的 10 个文件清单，逐文件比较「标记数 HEAD vs 现值」，少了就是被上游覆盖吃掉；
  2. 再扫一遍「无守卫的 `native_*` 调用行数」：逐行看是否含 `os_type` / `os_android`，或处于 `if (os_type == os_windows)` / `if (global.ime_block ...)` 作用域内；本轮新增数必须为 0。
  补守卫的写法：`if (os_type != os_android && global.ime_block && native_enable_ime != undefined)`、`if (os_type != os_android && native_stop_mouse_limit != undefined) native_stop_mouse_limit();`。
  用 Python 精确替换时锚点必须唯一 —— `    if (native_stop_mouse_limit != undefined)` 在文件里出现 2 次，要在前面带 `ml_focus_count = 0;\n` 才能唯一定位。
- **证据**：2026-11-15 第十三轮同步；`objects/obj_file_manager/Step_0.gml` HEAD 版 `os_guard=5` / 2973 B，SRC `337ee95861` 版 `os_guard=0` / 2848 B，SRC 工作区版 `os_guard=0` / 3262 B —— **上游本身就是无守卫版**，不是我们引入的；`extensions/WindowsNative/WindowsNative.yy` 的 `copyToTargets: 66`（Windows + macOS，无 Android）、`ProxyFiles` 只有 `libFvmNativeSupport.dylib`（TargetMask 1）；修复后全仓「无守卫 `native_*` 调用」新增 0（现存 36 处里 26 处是 HEAD 既有设计）。

### C28 新版运行时实例是 `ref instance`，`is_real()` 判活恒 false → 小怪全体无视卡片（只走路不啃）
- **症状**：安卓包（v2.8.0 同步后）所有非 BOSS 敌人直接走过卡片、永不进入啃食；BOSS 照常拆卡；桌面版同一关卡正常。屏幕诊断读数为 `卡id=ref instance 100264 real=0 iex=1 oex=0 / anc=1 / live卡=0 / live敌=0`，行缓存 `keys=[0:0 1:0 2:0 3:2 4:0 5:3]`（桶被 prune 清空）、`缓存行卡=0` 而 `真值 同行=8`。
- **错路**：先怀疑 `plant_type`/`feature_type`/`eat_order`/`grid_row`/`attack_range` 正负号/存档迁移/`event_inherited` 缺失/平台守卫；又因为「桌面版正常」而一度归因成「桌面运行时旧、`is_real` 为 true」。**实际桌面版压根没有这套守卫**：`combat_targets_is_live` / `prune` / `row_compact` / `combat_live_or_noone` 在 `D:\gameProject\FVM-Reborn-mod` 里 0 处引用（上游 `49ab6cc2b` 整份 revert 后的旧版，判活只有一句 `combat_target_alive = instance_exists && !object_exists`）。所以「桌面不炸」证明不了运行时差异，只能证明**只有安卓副本走过这条路**——而这条路是 11-14 重新捡回、从未真机验证的守卫补丁。
- **正确路径**：判活/判句柄不要用 `is_real()` 当类型闸门。新版运行时实例是 `ref instance`（`string(id)` 形如 `ref instance 100264`、`string(obj_index)` 形如 `ref object obj_goblet_lamp`），`is_real()` 返回 **false**，于是 `combat_targets_is_live()` 第一行就把所有活实例判死 → `combat_targets_prune()` 把每行卡桶清空 → `combat_enemy_find_plant()` 全程 `continue` 返回 `noone` → 状态机进不了 `ATTACK`；BOSS 走自己的 Step 不调此函数，所以表现正常。改成「只排除确定不是实例的容器类型」再交给 `instance_exists`：
  ```gml
  if (is_undefined(_inst)) return false;
  if (is_struct(_inst) || is_array(_inst) || is_string(_inst) || is_bool(_inst)) return false;
  if (_inst == noone) return false;
  if (!instance_exists(_inst)) return false;
  if (object_exists(_inst)) return false;   // 排除误传对象索引（实测 ref 实例过 object_exists 为 0）
  ```
  同一个坑已在 `scripts/gacha_random_card/gacha_random_card.gml:565` 的注释里记过（ds_map 句柄过 `is_real` 也是 false），当时只修了那一处，没有全仓排查。
- **证据**：2026-11-16 真机三版屏幕诊断（`obj_battle/Draw_0`，定位后已删除）；`scripts/combat_targets/combat_targets.gml:33-52`（修复点）；`scripts/gacha_random_card/gacha_random_card.gml:562-570`（同类历史坑）。**仍待排查的同型隐患**：`scripts/hex_batch3/hex_batch3.gml:1656` 与 `:2588`（`is_real` 卡 ds_map 卡组元素 → 词条整条失效）、`scripts/obj_pool_deck/obj_pool_deck.gml:284` 与 `:290`（`is_real` 卡对象索引/池 id）。

### A29 `git merge-file` 原地改写 ours → 三方合并的「我方原文」被污染
- **症状**：批量三方合并脚本跑完，对某个文件决议「取 ours」，产出的 `final__` 里却带着 `<<<<<<<` / `=======` / `>>>>>>>` 标记；或者反过来，`merged__` 与 `ours__` 字节完全相同（比对 sha1 才会发现），让人误以为「上游没改动这一处」。
- **错路**：把 `git merge-file --diff3 ours base theirs` 当成只读操作，合并脚本里直接 `subprocess.run([...])` 后立刻 `read(ours_p)` 去当「TGT 原始文本」做 hunk 比对与 `assert h['ours'] == ...`。实际 git 的语义是「就地合并到第一个文件参数」，跑完 `ours_p` 已经是**带冲突标记的合并结果**，`base` / `theirs` 不动。
- **正确路径**：合并脚本写成三步 ——
  1. 先在临时目录物化 `base__<stem>` / `orig__<stem>`（= TGT 工作区原文）/ `theirs__<stem>`，全部先做 LF 归一化（`Save-LF`），因为 TGT 的 `.gml` 常是 CRLF、`base` blob 是 LF，直接 merge 会整文件冲突；
  2. `git merge-file --diff3 <tmp_ours> base theirs`，**`<tmp_ours>` 拷自 `orig__` 的副本**，不是 `orig__` 本身；
  3. 决议函数 `read(stem, 'ours')` 一律读 `orig__`，`read(stem, 'merged')` 读合并产物。产出 `final__` 后强制断言 `'<<<<<<<' not in text`。
- **证据**：2026-11-16 第十四轮同步；`.codex-tmp/merge_d14.py` 首版触发，`scripts/combat_targets/combat_targets.gml` 的 `merged__` 与 `ours__` sha1 同为 `d3191719e30b`（15199 B），加 `orig__` 快照后重跑才区分出「merged == ours 是因为 TGT 已把上游该函数合进来」，最终 4×ours 决议才正确（终版 214 行，保留 `combat_target_alive` 定义 + 我方 `combat_targets_is_live`）。

### C29 `combat_enemy_in_rows` / `combat_enemy_nearest_in_row` 仍崩（行号 -1）→ 敌人查询别读行桶，引擎枚举活实例
- **症状**：卡片 Step 直接弹错框，栈顶是索敌函数、**行号 -1**：
  ```
  of Step Event0 for object obj_double_long_bao:
  Unable to find any instance for object index '104446'
  at gml_Script_combat_enemy_in_rows  (line -1)
  ```
  `obj_double_long_bao` 只是撞上的一例，任何调 `combat_enemy_in_rows` 的卡（长包全家、玉米、咖啡杯、欧丁、后羿…）都可能崩。
- **错路**：按 C26 的思路继续加固判活 —— `combat_targets_is_live` 里 `instance_exists` + `object_exists` + `object_index == obj_pool_holder` 三条都齐了，`with` 一个都没留，**照崩**。因为病根不在判据，在**取数路径**。
- **正确路径**：**别 `with` / 别读行桶里的 id**。行桶是「本 step 首次建桶那一刻」的快照，建桶之后同一 step 里死掉 / 被池回收的敌人还留在数组里，后面任何判据都追不上（`instance_exists` 对同帧刚销毁的实例不可靠）；`id.字段` 或 `with (id)` 一碰就抛上面那句，且报错行号恒为 -1，看着像崩在函数入口，容易让人以为入口参数有问题。
  - `combat_enemy_in_rows` → `for` 行 + `with (obj_enemy_parent)` 行内过滤（保住「多行卡第一行优先、行内原生 with 顺序」）；
  - `combat_enemy_nearest_in_row` → 一次 `with (obj_enemy_parent)` 扫完取列差最小（严格 `<`，同距先登记者胜）；
  - 跨帧缓存 `combat_row_target`（唯一读取点就在 `combat_enemy_in_rows` 里）一并删除，别再让 id 跨帧存活。
  - `combat_enemy_find_plant`（敌人啃卡）也换成一次 `with (obj_card_parent)`：原先靠行桶取「本行卡片」，
    同帧死掉的卡一样会崩。定序语义不变 —— `eat_order` 分四档、**同档内后登记的覆盖先登记的**，
    靠的正是原生 `with` 顺序，与建桶时一致；矮卡 / 高跷鼠白名单 / 梯子宿主 / 身前判定的顺序照旧。
  - **行桶本体整段删除**：`combat_targets_state` / `combat_targets_row` / `combat_targets_row_compact` /
    `combat_targets_prune` 全部移除。只剩三个入口做兼容空实现 —— `combat_targets_invalidate`（11 处
    调用：池回收 / 真销毁 / 清池 / 卡与敌的 Create·Destroy / `src_hook_function`）、
    `combat_targets_begin_step`（`obj_battle/Create_0`、`obj_mod_manager/Step_1`）、
    `combat_targets_row_value`（13 处摆放 / 传送 / 击退改行，现在直接返回行号）。
- **代价**：每张卡每帧多扫一遍场上敌人、每只鼠每帧多扫一遍卡片（同屏各 ≤ 40），与 `d6ae7a5b7d` 重构前一致；换来「不存在悬空 id」这个结构性保证。
- **证据**：`scripts/combat_targets/combat_targets.gml:1-21`（行桶删除说明 + 三个空实现）、`:84-155`（三个查询全改引擎枚举）；判活三条判据见同文件 `:53-74`；桌面工程同日同症（`obj_stinky_tofu_pult` / `combat_enemy_nearest_in_row`，index 100203）已用同一口径修好；2026-11-17 日志。

### A30 本 Android 工作区没有 `tools/verify_gml.ps1`；`rg -rn` 把搜索干成了替换
- **症状**：① 按 §1.2 跑 `powershell -File tools\verify_gml.ps1 objects\obj_mobile_buttons` 报「实际参数不存在」（Bash 里调还会先被安全策略拦掉，要求改用 PowerShell 工具）；② `rg -rn "obj_card_slot" objects scripts` 的输出里匹配文本全变成了 `n`，看上去像「文件里写的就是 n」。
- **错路**：① 以为脚本只是被执行策略挡住，换 PowerShell 工具重跑一遍才确认是**文件真的不在这个工作区**；② 把 `-rn` 当成「递归 + 显示行号」。
- **正确路径**：
  - 本 Android 工作区 `tools/` 只有字体/数值/音频那几个脚本，**没有** `verify_gml.ps1` / `check_contract.ps1`（那两件在桌面工程 `D:\gameProject\FVM-Reborn-mod\tools\`）。§1.2 的必跑改成等价自查：写一个临时脚本放 `%TEMP%`（不要落仓库根，见 A7），逐文件断言「UTF-8 无 BOM / 无 CRLF / 剔注释与字符串后三类括号配平 / 行数字节数」，5 个改动文件全绿再交付。
  - `rg` 的 `-r` 是 `--replace`，`-rn <模式>` 等于「把匹配替换成 n 再打印」。要行号就用 `-n`（递归是 `rg` 默认行为，不需要 `-r`）：`rg -n "关键词" objects scripts`。
- **证据**：2026-11-17 缓时按钮这轮；`ls tools` 输出与 `rg --files -g "*verify*"` 双空；自查脚本 `%TEMP%\check_gml.py` 输出 5×OK。

### A31 `git push` 报 `schannel: CRYPT_E_NO_REVOCATION_CHECK`（0x80092012）
- **症状**：`git push origin main` 直接 fatal：
  ```
  fatal: unable to access 'https://github.com/mgqs/FVM-Reborn-mod---Android.git/':
  schannel: next InitializeSecurityContext failed: CRYPT_E_NO_REVOCATION_CHECK (0x80092012)
  ```
  同一时刻 `curl -sI https://github.com` 也是 `exit 35`（SSL connect error），浏览器/网页却可能能开。
- **错路**：只加 `-c http.schannelCheckRevoke=false` 一条 **不管用**，仍报同一句（该开关不影响代理链路里被替换掉的证书链校验）。
- **正确路径**：本机 `HTTP(S)_PROXY=http://127.0.0.1:51415`（沙箱代理）会替换 TLS 证书，schannel 做吊销检查必然失败。推送用**单次命令**关两处：
  ```
  git -c http.sslVerify=false -c http.schannelCheckRevoke=false push origin main
  ```
  改完立刻用 `git status -sb` + `git log origin/main -1` 核对远端确实前进。**不要**把这两条写进仓库 `.git/config`（`git config --global` 更不行）：等于全机永久不校验证书。
- **证据**：2026-11-17 推送 `ff9f923c1` / `8b32a2dc2`，前两次（含 `schannelCheckRevoke=false`）失败、加 `sslVerify=false` 后 `d90fbbc16..8b32a2dc2 main -> main`。

### A32 用正则统计「源 yyp 里有、目标 yyp 里没有」的资源条目，恒等 44（一条都没匹配上）
- **症状**：`an_yyp.py` 先报「缺 44 项」，准备插入时却一条也找不到插入点；把正则单独跑，`re.findall` 返回空。
- **错路**：正则写成 `^    \{"id":\{"name":"([^"]+)","path":"([^"]+)",?\},?\},?\n$` —— 想在行尾再要求一个换行符。
- **正确路径**：`re.M` 下 `$` 匹配的是「换行符之前」的位置，`\n$` 永不成立。写成 `\},?$` 收尾即可；另注意两边 yyp 风格不同：源带尾逗号（`…yy",},},`）、目标不带（`…yy"}},`），正则要 `,?` 通吃。
- **证据**：`.codex-tmp/an_yyp.py`，2026-11-17 同步 3.0.2.19 这轮；修正后 `git diff --stat FVM_Reborn_makk.yyp` = 46 insertions、复核缺项 0。

### A33 Python `%` 模板里写 `"%Name"` 直接 `ValueError: unsupported format character 'N' (0x4e)`
- **症状**：拼 GameMaker 文件夹 `.yy` 的模板字符串一格式化就炸，整条命令不执行。
- **错路**：以为 `%` 只在 `%(name)s` 形态才生效。
- **正确路径**：模板里凡是要输出字面量 `%` 一律写 `%%`（GMS 的 `.yy` 大量使用 `$GMFolder` / `%Name` / `%Path` 这种键名）；或者改用 `str.replace` / f-string 拼装。
- **证据**：`.codex-tmp/an_yyp.py` 的 `FOLDER_LINE`，2026-11-17。

### A34 资源父文件夹的 `.yy` 连源工程磁盘上都没有（只存在于 IDE 内存里）
- **症状**：31 个新增 `spr_zz_*` 的 `"parent"` 全指向 `folders/精灵/mod/zhuanzhuan.yy`，但该文件在源仓库工作副本里 `os.path.exists` = False；照原样拷过去会在 IDE 里挂到空文件夹。
- **错路**：只信 `git ls-files`（那里也没有），于是想跳过文件夹注册。
- **正确路径**：拿同级真实存在的 `folders/物体/mod/zhuanzhuan.yy` 当模板生成该文件（`$GMFolder` / `%Name` / `folderPath` / `listItems` 填实际条目），再把它挂进 `folders/精灵/mod.yy` 的 `folders` 数组。判断「某文件夹该不该存在」看资源的 `parent` 字段，不要看源仓库有没有那个文件。
- **证据**：`.codex-tmp/an_mkfolder.py`，2026-11-17；生成后 31 个精灵 + 4 个 `obj_zz_*` 全部有父文件夹。

### A35 受保护层自检按「规则文描述」猜断言字符串，报了两条假异常
- **症状**：`an_protect.py` 首跑报 `objects/obj_game_init/Create_0.gml 缺 keyboard_virtual` 与 `objects/obj_auth_gate/Draw_0.gml 缺 os_type == os_android`，但这两处代码其实都正常。
- **错路**：按 `.trae/rules/android设置.md` 的文字描述直接推断标记串。
- **正确路径**：写断言前先用 `rg -n` 把真实标记打出来再抄。事实：软键盘只落在 `objects/SearchBox/Create_0.gml`、`objects/obj_auth_gate/Create_0.gml`、`objects/obj_material_sell_confirm/Create_0.gml` 三处（`obj_game_init` 只持有 `global.mobile_slowmo_enabled`）；`obj_auth_gate/Draw_0.gml` 的粘贴按钮守卫是 `if (android_paste)`，变量定义在 `objects/obj_auth_gate/Create_0.gml:98` `android_paste = (os_type == os_android);`。
- **证据**：`.codex-tmp/an_protect.py` 首跑 2 条异常，改成真实标记后 35/35 通过（`.codex-tmp/protect_report.txt`）。

### A38 用正则读 `.yy` 的 `textureGroupId` 判纹理组 → 两种排版只认出一种，7 个精灵被误报「未分组」
- **症状**：核对 30 个新精灵的纹理组时，24 个 `spr_holiday_*` 正常报出 `UI`，另 7 个（`spr_craft_arrow_l/r`、
  `spr_craft_help_btn`、`spr_craft_onekey_btn`、`spr_craft_warcard_label`、`spr_holiday_pager`、`spr_holiday_pop`）
  落进 `?` 桶，看起来像是「没分组」。
- **错路**：正则写成 `"textureGroupId":\{\s*"name":"([^"]+)"`（假设冒号后紧贴 `{`）；另一条路是在 `pwsh` 里
  拼 `rg -n '"path": ?"texturegroups/' $f`，引号在命令链里被吞，整批返回空行，越查越像没分组。
- **正确路径**：`.yy` 两种排版都存在（`"textureGroupId":{` 与 `"textureGroupId": {`），正则一律写
  `"textureGroupId"\s*:\s*\{[^{}]*?"name"\s*:\s*"([^"]+)"` 并加 `re.S`；凡是跨文件的批量属性核对，
  都写成 `.py` 文件读文件（`.codex-tmp/an_tg4.py`），不要靠 `pwsh` 里内联正则 + 引号拼接。
  实测这 7 个精灵确实都在 `UI` 组（`spr_craft_help_btn.yy:198-200`、`spr_holiday_pager.yy:140-142`）。
- **证据**：`.codex-tmp/an_tg3.py`（误报）→ `.codex-tmp/an_tg4.py`（7/7 命中 `UI`），2026-11-21 日志。

### A39 断言脚本按 `f()` 空参匹配 → 带实参的调用被判「没调用」
- **症状**：嫁接后断言 `objects/obj_craft_bg/Draw_0.gml` 含 `craft_help_draw()` / `craft_onekey_draw()`，
  报「命中 0」，看着像上游那两个弹窗根本没接进绘制。
- **错路**：把「函数被调用」写成 `count('craft_help_draw()')`。
- **正确路径**：实参调用是 `craft_help_draw(craft_help_ok_hover)`、定义是 `function craft_help_draw(_hover)`，
  两者都不含 `f()`。断言应写成 `f(` 或只写函数名（实测 `Draw_0.gml:1468-1469` 两处都在）。
  同理「开关是否已删」这类断言要用 `count == 0`，而本轮 `craft_rate_enabled` 因为出现在**自己写的说明注释里**
  仍计数 1，断言要排除注释或改判「不在 ini_read 行里出现」。
- **证据**：`.codex-tmp/an_assert3.py` 首跑 3 条假异常 → 改写成 `f(` 后全绿，2026-11-21 日志。

### B32 统计「谁继承了某对象」得到 0 → `.yy` 的 `parentObjectId` 是跨行 JSON，单行正则静默匹配不到
- **症状**：查 `obj_bullet_parent` 的子对象数得到 **0**，据此认定「全工程没有子弹继承子弹父类、
  出生认领从未执行」，把根因判错、还要去写一套全局扫描，实际子对象有 **140** 个。
- **错路**：`s = open(yy).read().replace(' ', '')` 之后就按 `'"parentObjectId":{"name":"obj_bullet_parent"'` 匹配 ——
  只去了空格没去换行，`.yy` 里是 `"parentObjectId": {\n    "name": ...`，正则跨行匹配不到，**静默返回 0**（不报错）。
- **正确路径**：先 `s.replace('\n', '')`，或用 `re.search(r'"parentObjectId":\s*\{[^}]*"name":\s*"([^"]*)"', s, re.S)`；
  凡是拿到「0 / 空 / 全缺失」这种反常却干净的结论，换一种写法复核一次再动手。
- **证据**：`objects/obj_bullet_parent/BeginStep_0.gml:20`（注释写着「122 个子弹一次覆盖」）、
  `objects/*/*.yy` 实测 140 个 `parentObjectId` = `obj_bullet_parent`，2026-11-20 日志（上游条目 B48 并入）。

### B33 叠层 UI 的点击：鼠标事件先于 Step，depth 管不到谁收到点击
- **症状**：抽卡 / 欧皇模式下在「金马盛典 → 兑换商城」点购买，弹的是**商城**的「抽卡模式无法购买卡片」，
  幸运星花不出去；普通模式不易察觉（只会莫名弹商城确认框）。
- **错路**：先在 `zz_shop_list` / `zz_buy_shop` / `obj_zz_shop_bg/Step_0` 里找模式门禁 —— 这三处一个 `play_mode` 都没有。
- **正确路径**：先按提示原文反查唯一出处（`rg "<提示原文>"`），再问「这个对象的判定框为什么和当前界面重合」。
  本例唯一出处是 `obj_shop_buy_btn/Mouse_4`，而兑换页是照商城逐像素抄的（4×4 格 + 按钮同在「格心 +77/+60」+
  同一个 `spr_shop_buy_btn`），商城还活着时两组判定框完全重合。GMS 里 **Mouse 事件在 Step 之前执行**，
  depth 只影响绘制顺序 → 底下那层按钮先吃掉点击。另外商城关闭时 `menu_type` 在收缩动画**开始前**就清零，
  「商城还在、上层界面已开」是真实可达状态，只靠 `menu_type` 拦不住。
  修法：`obj_shop_buy_btn/Mouse_4` 顶部加「`obj_zz_bg` / `obj_zz_shop_bg` / `obj_zz_buy_confirm` 任一存在就 exit」，
  `obj_zz_enter/Mouse_4` 补 `instance_exists(obj_shop_bg)` 早退。
- **证据**：`objects/obj_shop_buy_btn/Mouse_4.gml:1-12`、`objects/obj_zz_enter/Mouse_4.gml:5-7`、
  `objects/obj_zz_shop_bg/Create_0.gml:26-33,57-67`，2026-11-20 日志（上游条目 B49 并入）。

### D6 外部 PR 合并后工程解析失败，但 yyp 的 resources/Folders 逐条都对得上
- **症状**：合并别人的 PR 后，`FVM_Reborn_makk.yyp` 的 `resources` / `Folders` 都能对出来，资源目录也在磁盘上，
  但 IDE 打开报错、资源树丢项。
- **错路**：只校验 yyp 的两条（resources 与 Folders），把 `folders/**/*.yy` 的 JSON 语法当默认正确；
  扫描脚本用 `except Exception: continue` 跳过解析失败的文件，结果把「解析失败」误报成「资源未被收录」。
- **正确路径**：合并后必跑一次全量解析，**失败项要打印**：
  `json.loads(re.sub(r',(\s*[}\]])', r'\1', open(p, encoding='utf-8-sig').read()))`
  对 `folders/**/*.yy` 逐个跑。本轮实测三类缺陷：32 个 `folders/精灵/mod/Cards/Assistant/*.yy` 的
  `$GMFolder` 值后多了一个引号（正常是 `"$GMFolder":""`，坏文件写成三个引号再接逗号）、
  `nengliangmiao.yy` 末尾 `"children":[]` 后多一个引号再接右花括号、
  `folders/精灵/mod/Bullet.yy` 两条 `listItems` 之间缺逗号（后两个在源工程同样存在）。
  另有 3 个 GBK 乱码目录 `folders/绮剧伒` / `folders/鐗╀綋` / `folders/鑴氭湰`（63 个 `.yy`，yyp 零引用）已删除。
- **证据**：`.codex-tmp/an_json.py`（体检）、`.codex-tmp/an_fixjson.py --apply`（34 个修复、复核 0 失败）、
  `folders/物体/mod.yy:26`（上游 D7 的 `],,` 双逗号案例），2026-11-21 日志。

### D7 外部 PR 把对象改名，只删旧 `listItems` 条目、没补新条目

- **症状**：合并后对象在 yyp `resources` 里（能编译、代码引用也对），但 IDE 资源树里看不到它；
  全仓 `folders/**/*.yy` 搜新名字 0 命中。
- **错路**：只查「旧名字有没有残留」（0 残留就以为干净）、只看 yyp 的 `resources` + `Folders`
  （两者都通过），漏掉「新名字要重新进某个文件夹的 `listItems`」这一步。
- **正确路径**：合并后对每个状态为 `A` 的对象/脚本/精灵，用它的 `path` 在
  `folders/**/*.yy` 的 `listItems` 里做一次反查；0 命中就按原文件夹补一行
  （`{"name":"<名>","path":"<path>",}`）。PR49 的 `obj_immortal_pick` → `obj_immortal_confirm`
  就是只删了 `folders/物体/mod/UI.yy` 里的旧行，已补回。
- **证据**：`folders/物体/mod/UI.yy`（补入前 listItems 6 条、无新对象）、2026-11-22 日志。

## 追加模板

```
### X{n} <一句话症状>
- **症状**：看到什么、在哪一步暴露。
- **错路**：当时怎么做的。
- **正确路径**：下次一步到位的动作（可复制）。
- **证据**：`文件:行` 或 `YYYY-MM-DD 日志`。
```
