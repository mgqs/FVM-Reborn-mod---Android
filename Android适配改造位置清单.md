# Android 适配改造位置清单

> 本文档记录「美食大战老鼠：重生」项目在 Android 版适配过程中，所有改动项的所在文件与位置。
> 所有 Android 专属逻辑统一用 `if (os_type == os_android)` / `if (os_type != os_android)` 分支包裹，原 Windows 实现保持不变。

---

## 1. Esc / Shift 虚拟按键（左下角）

功能：游戏左下角绘制两个虚拟按键。Esc 在下、全局生效；Shift 在上、仅对局内（`instance_exists(obj_battle)`）生效。绘制放 Draw GUI（每帧），输入处理放 Begin Step（保证先于其它对象 Step）。

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_mobile_buttons/obj_mobile_buttons.yy` | 整个文件 | 对象定义：`persistent=true`，事件 = Create / Begin Step / Draw GUI |
| `objects/obj_mobile_buttons/Create_0.gml` | 整个文件 | 初始化按钮尺寸、间距、边距，以及脉冲/闪烁计时变量 |
| `objects/obj_mobile_buttons/Step_1.gml` | 整个文件 | Begin Step：触摸命中判定 → `keyboard_key_press/release` 模拟按键；Shift 仅对局内、Esc 全局 |
| `objects/obj_mobile_buttons/Draw_64.gml` | 整个文件 | Draw GUI：左下角绘制圆角按钮（Esc 下 / Shift 上），非对局不画 Shift |
| `objects/obj_game_init/Create_0.gml` | L72–76 | 启动时 `instance_create_depth(0,0,-9999, obj_mobile_buttons)`（持久化跨房间存活） |
| `objects/obj_battle/Step_0.gml` | L233–243 | Shift 加速消费端：检测 `global.mobile_shift_pressed` 锁存标志 → 切换 `speed_up` / `game_set_speed` → 清除标志。与虚拟按键配套，同步/合并覆盖此文件后必须重新嫁接此段（`keyboard_key_press` 模拟按键实测无法触发 `keyboard_check_pressed`，勿用） |

---

## 2. 存档导入 / 导出

功能：Android 端用剪贴板作为数据交换载体（不依赖 Windows 原生文件系统接口）。

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_edit_menu_button/Mouse_4.gml` | L30–41（`export_save_backup`） | 导出：Android 用 `clipboard_set_text(json_stringify(global.save_data))`；Windows 用 `native_start_backup` |
| `objects/obj_edit_menu_button/Mouse_4.gml` | L45–（`import_save_backup`） | 导入：Android 用 `clipboard_get_text()` → `json_parse` → 校验 `is_struct` + `player` 字段 → `save_file` + `load_file`；Windows 用 `native_restore_backup` |
| `scripts/save_file/save_file.gml` | L4 | `save_file(file_slot)` 底层存档写入 |
| `scripts/load_file/load_file.gml` | L4 | `load_file(file_slot)` 底层存档加载 |

---

## 3. 删除存档

功能：Android 端原「打开存档目录」按钮改为「删除当前槽位存档」，删除后自动重置为开局存档。

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_edit_menu_button/Mouse_4.gml` | L15–27（`open_save_folder`） | Android 分支：`reset_file(global.save_slot)` + 提示「存档已删除」；Windows 保留 `native_open_folder` |
| `objects/obj_edit_menu/Create_0.gml` | L21 | Android 端按钮文字改为「删除存档」 |
| `scripts/load_file/load_file.gml` | L203 | `reset_file(file_slot)` 重置为开局存档 |

---

## 4. 双指滑动

功能：移动端滚动交互，统一采用「双指触点中点帧间差值」驱动内容偏移。触点检测必须遍历 `device_mouse_check_button(_d, mb_left)`（`_d = 0..9`）收集全部按下的触点，**不得硬编码 0/1**（Android 触点索引不保证连续分配，硬编码是「双指从未生效」的根因）。坐标一律用房间坐标 `device_mouse_x/y()`，与各面板的 `point_in_rectangle` 判定保持一致（Draw GUI 场景才用 `_to_gui`）。

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/GridList/Create_0.gml` | L317 | GridList 通用列表组件（Begin Step 内 `apply_wheel`；修正原 GUI 坐标误用） |
| `objects/obj_package_bg/Draw_0.gml` | L728 | 背包面板滚动 |
| `objects/obj_craft_bg/Draw_0.gml` | 文件尾部滚动条段 | 合成屋面板滚动（`Create_0` 含 `two_touch_scroll_*` 初始化；尾部双指段按 `craft_top_tab` 分流：==2 转职页驱动 `tg_scroll_target`/`tg_rows_max`、==3 进化页驱动 `evo_scroll_target`/`evo_rows_max`（整行 96px 折算）、==0 强化页驱动 `y_offset_target`；同步源端覆盖后必须重新嫁接此段） |
| `objects/obj_info_island_bg/Draw_0.gml` | L535 | 信息岛面板滚动 |
| `objects/obj_readyroom_manager/Draw_0.gml` | L191 | 选卡界面滚动（`Create_0` 含 `two_touch_scroll_*` 初始化） |
| `objects/obj_cookbook_bg/Draw_0.gml` | L9 | 食神谱滚动（按行高 101 折算 `y_offset`；`Create_0` 含初始化） |
| `objects/obj_craft_bg/Draw_0.gml` | 文件末尾 | 强化页（tab 0）收尾 `panel_anim_end_parts(id, craft_parts, 260);` —— 源端仍缺这行，同步后必须补回，否则开动效必报 `Unbalanced surface stack` |
| `scripts/GuiStack/GuiStack.gml` | `panel_anim_step()` 开头 L231-234 | 漏 reset 自愈：`pnl_recording` 仍为 true 时补 `surface_reset_target()` 并置 false；各 `panel_anim_end_*` 收尾后亦置 false |
| `objects/obj_craft_bg/Destroy_0.gml` / `CleanUp_0.gml` | Destroy L8-10 / CleanUp L3-5 | `surface_free(card_surface)` 判存在并置 `-1`，避免 Destroy 与 CleanUp 双重释放 |
| `objects/obj_package_bg/Draw_0.gml` | L258 / L524 / L677 / L762 | 四处 `surface_reset_target()` 与 `surface_set_target()` 同条件 `surface_exists` 保护，避免 surface 缺失时弹掉上层动效目标 |

---

## 5. Windows 原生功能禁用 / 防止安卓报错

功能：所有 Windows 原生（`native_*`）调用在 Android 上通过 `os_type` 分支跳过或替换为安全返回，避免 `.dll` 不存在导致的「Variable not set before reading it」崩溃。

### 5.1 启动初始化（日志 / 迁移 / Mod 目录 / IME）

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_game_init/Create_0.gml` | L2 | `init_native_log()` 内 `if (os_type == os_android) return;` |
| `objects/obj_game_init/Create_0.gml` | L12 | `move_files()` 内 `if (os_type == os_android) return;` |
| `objects/obj_game_init/Create_0.gml` | L65 | Mod 包目录初始化包裹 `if (os_type != os_android)` |
| `objects/obj_game_init/Create_0.gml` | L219 | `native_disable_ime` 加 `os_type != os_android &&` 短路 |
| `objects/obj_game_init/Create_0.gml` | 文件末尾（native_disable_ime 之后） | 授权启动块：`auth_init();` → `global.auth_gate_force = true;` → `if (!auth_ok() && !instance_exists(obj_auth_gate)) instance_create_depth(0, 0, -9500, obj_auth_gate);` → `global.auth_gate_force = false;`。**源端**同位置已有启动块但缺 `global.auth_gate_force` 传参（Create 是同步执行的，在外面拿到实例再赋值已太晚）；同步覆盖后必须重新嫁接此块

### 5.2 输入法（IME）/ 鼠标限频

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_file_manager/Step_0.gml` | L37 / L42 / L52 | `native_enable_ime` / `native_disable_ime` 加 `os_type != os_android` |
| `objects/obj_file_manager/Step_0.gml` | L62 / L67 | 鼠标限频 `native_stop/start_mouse_limit` 加 `os_type != os_android` |
| `objects/obj_file_manager/Other_3.gml` | L5 | 关闭鼠标限频加 `os_type != os_android` |
| `objects/SearchBox/Create_0.gml` | L78 / L96 | IME enable / disable 加 `os_type != os_android` |
| `objects/SearchBox/Create_0.gml` | `focus()` L84-88 | 安卓调起系统软键盘：`if (os_type == os_android) try { keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_sentences, true) } catch(_e){}`。**4 个参数缺一不可**（GM1020 只认 4 个，少写必编译报错）；该文件是所有输入框（存档命名 / 实验室 / 联机地图搜索等）的公共组件，改一处全局生效；部分机型此调用无效，靠 try/catch 兜底，失败仍可粘贴或外接键盘 |
| `objects/SearchBox/Create_0.gml` | `blur()` L100-102 | 安卓收起软键盘：`if (os_type == os_android) try { keyboard_virtual_hide() } catch(_e){}`，避免点空白 / Esc / 切界面后键盘一直压着画面 |
| `objects/obj_material_sell_confirm/Create_0.gml` | Create 末尾 L56-65 | 道具出售窗（兼作凭证回收 / 凭证购买）开窗即弹**数字软键盘**：`if (os_type == os_android) try { keyboard_virtual_show(kbv_type_numbers, kbv_returnkey_done, kbv_autocapitalize_sentences, true) } catch(_e){}`。该对象没有 focus 概念，全靠每帧读 `keyboard_string`，键盘生命周期跟窗口走；**4 个参数缺一不可**（GM1020） |
| `objects/obj_material_sell_confirm/Create_0.gml` | `trade_close()` 开头 L68-73 | 关窗收起软键盘：`if (os_type == os_android) try { keyboard_virtual_hide() } catch(_e){}`。确定 / 取消 / ESC 三条关闭路径都走 `trade_close()`，一处覆盖全部关闭场景 |

### 5.3 文件夹 / 目录操作

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/LaboratoryGUI/Create_0.gml` | L194 | `native_open_folder` Android 分支提示 |
| `scripts/FileUtil/FileUtil.gml` | `find_sub_folders` / `find_files_with_extension_recursively` | `file_find_first` 的 `fa_directory` / `fa_archive` / `fa_readonly` 只在 Windows 有效，非 Windows 一律传 `0`（否则安卓永远扫到空列表） |

### 5.4 地图下载 / 在线地图

| 文件 | 位置 | 说明 |
|------|------|------|
| `scripts/MapDownloadManager/MapDownloadManager.gml` | L69 / L256 / L276 | `is_downloaded` / `unzip` / `delete_download` Android 直接返回安全值（false / 0 / -1） |
| `objects/OnlineMapGUI/Create_0.gml` | 通过 NativeUtil + MapDownloadManager 间接安全 | 不直接调用裸 `native_*` |

### 5.5 Mod Lua 调用

| 文件 | 位置 | 说明 |
|------|------|------|
| `scripts/external_mod_system/external_mod_system.gml` | L22–23 / L27–28 / L31–32 | `native_mod_lua_create` / `call` / `destroy` Android 返回安全值 |
| `objects/obj_external_mod_card/Create_0.gml` | L29 | 调用上述安全包装函数 |
| `objects/obj_external_mod_card/CleanUp_0.gml` | L3 | 调用 `native_mod_lua_destroy` |
| `objects/obj_external_mod_card/Destroy_0.gml` | L4–5 | 调用 `native_mod_lua_call` / `destroy` |

### 5.6 原生工具封装

| 文件 | 位置 | 说明 |
|------|------|------|
| `scripts/NativeUtil/NativeUtil.gml` | 整个文件 | NativeUtil 封装（`to_native_absolute`、`show_error` 等） |
| `scripts/__scribble_misc_functions/__scribble_misc_functions.gml` | L516 | Scribble 库内置宏 `__SCRIBBLE_ON_MOBILE`（含 `os_android`，非本次改造点） |

---

### 5.7 Mod 管理器 Android 适配

功能：Mod 管理器在安卓上从「点了没反应 / 卡片必然加载失败」改为可用 —— 声明式 Mod（纯 JSON + PNG）照常注册，Lua 行为脚本自动跳过。

> 本节的**规则化版本**已沉淀到 `.trae/rules/android设置.md` 末尾《文件路径 / 存储位置规范（Windows → Android）》。此后任何「Windows 绝对路径 → Android」的新改造都按那份规范写，并把新落点登记进那里的表格；本节表格保留作为 Mod 管理器的具体位置索引。

| 文件 | 位置 | 说明 |
|------|------|------|
| `scripts/NativeUtil/NativeUtil.gml` | `get_android_package()` | 返回 `com.company.game`，必须与 `options/android/options_android.yy` 的 domain / company / product 三字段一致 |
| `scripts/NativeUtil/NativeUtil.gml` | `android_storage_base()` | 用户存储根，按 `EXTERNAL_STORAGE` → `/storage/emulated/0` → `/sdcard` → `/storage/self/primary` 取第一个存在的挂载点（不带尾斜杠） |
| `scripts/NativeUtil/NativeUtil.gml` | `android_mkdirs(_dir)` | 逐级建目录。`directory_create` 一次只建一级，而 `Android/media/<包名>/files` 的中间层往往不存在，直接建末级会失败 |
| `scripts/NativeUtil/NativeUtil.gml` | `android_dir_usable(_dir)` | 建目录 + 列一次 + 写 `.probe` 探针，返回「GML 真的能用」；只看 `directory_exists` 不够（分区存储下不存在也可能返回 true）。可写性另记在 `global._android_last_dir_writable` |
| `scripts/NativeUtil/NativeUtil.gml` | `android_dir_readable(_dir)` | 只判断「已存在的目录能否读到」，**不建目录**。旧落点回退用它，免得没装过 Mod 的机器被凭空造出 `/Android/data/<包名>/files/mod` |
| `scripts/NativeUtil/NativeUtil.gml` | `android_legacy_files_root()` | 旧落点 `…/Android/data/<包名>/files`，仅作回退（Android 11+ 文件管理器看不到，adb 仍可投放） |
| `scripts/NativeUtil/NativeUtil.gml` | `android_copy_tree(_src, _dst)` | 纯 GML 递归复制目录：目录递归，文件先 `file_copy`、失败再 `buffer_load`/`buffer_save` 整块搬。**不要用 `file_bin_*` 逐字节循环**（大 PNG 会卡主循环） |
| `scripts/NativeUtil/NativeUtil.gml` | `android_migrate_legacy_mods()` | 老安装升级后首次启动，把旧落点里已有的 Mod 复制进新落点；只在「新目录为空 + 旧目录有货」时执行，旧包**不删**，复制完新目录非空，天然不会重复搬。条数记在 `global._android_mod_migrated` |
| `scripts/NativeUtil/NativeUtil.gml` | `get_external_files_root()` | 安卓返回 `/storage/emulated/0/Android/media/<包名>/files`（免权限 + 文件管理器/MTP 可见）；该目录建不出来时回退 `/Android/data/<包名>/files`；桌面回落 `%LOCALAPPDATA%\FVM_Reborn_makk` |
| `scripts/NativeUtil/NativeUtil.gml` | `get_mod_root()` | Windows 行为不变；安卓先调 `android_migrate_legacy_mods()` 尝试把旧目录的包搬进新目录，再按 `Android/media/<包名>/files/mod` → 旧 `Android/data/<包名>/files/mod` 顺序择优（新目录有包就用新目录，新目录空而旧目录有包则先迁移、迁移失败才继续用旧目录，避免升级后老 Mod 消失），两处都不可用才降级沙盒相对路径 `"mod"`；结果缓存在 `global._android_mod_root`，同时记 `_android_mod_root_primary/_legacy/_writable/_usable/_android_mod_migrated`，并打 `[NativeUtil] android mod root = …` 调试行 |
| `scripts/NativeUtil/NativeUtil.gml` | `mod_root_is_writable()` / `mod_root_is_user_visible()` / `get_mod_root_hint()` / `get_mod_root_hint_lines()` | 目录能力与提示文案查询；`_lines` 版本给界面逐行画（当前生效目录 + 推荐投放位置 + 旧位置/adb 提示） |
| `scripts/external_mod_system/external_mod_system.gml` | `external_mod_state_path()` | 安卓开关状态固定写沙盒相对路径 `mod_state.json`（外部私有目录未必可写）；Windows 仍是 `<mod>/mod_state.json` |
| `scripts/external_mod_system/external_mod_system.gml` | `external_mod_find_flags()` | `file_find_first` 属性常量按平台返回（Windows `fa_directory`，其他 `0`） |
| `scripts/external_mod_system/external_mod_system.gml` | `external_mod_delete_folder()` | Windows 先走 `native_delete_folder`，失败或非 Windows 走纯 GML 递归删除 |
| `scripts/external_mod_system/external_mod_system.gml` | `external_mod_validate()` | 安卓上行为脚本可选：缺失 / 非 `.lua` 时 `has_script = false`，`source` 置空不再抛「文件不存在」 |
| `scripts/external_mod_system/external_mod_system.gml` | `external_mod_load_all()` | 根目录改用 `get_mod_root()`；Lua probe 加 `d.has_script && os_type != os_android` 守卫 |
| `objects/obj_external_mod_card/Create_0.gml` | L30 | Lua 句柄创建包进 `mod_definition.has_script && os_type != os_android`，安卓声明式卡片不再尝试建句柄 |
| `objects/obj_mod_menu/Create_0.gml` | L1-L4 / L13 / L66-L96 / L108-L225 | 根目录与状态文件同源；建目录改走 `android_mkdirs`；`notify_result` 的 `show_message` 换 `show_message_async`（安卓模态会卡主循环）；`scan_mod_folders()` 在空结果时补一次 `fa_directory` 枚举；`refresh_mods()` 合并三路来源（磁盘扫描 / `global.external_mod_loaded` / `global.external_mod_errors`），并在「当前不在首选 `Android/media` 目录」或「扫到 0 个包」时用 `get_mod_root(true)` 重探；`save_state()` 过滤 `missing`/`failed` 占位行，只写 `{folder, enabled}` |
| `objects/obj_mod_menu/Step_0.gml` | L23-L77 | 安卓「导入」变「刷新列表」（没有 `get_open_filename` / `native_unzip_map_file`），提示文本改用 `get_mod_root_hint_lines()` 拼当前目录 + 推荐目录 |
| `objects/obj_mod_menu/Step_0.gml` | L79-L89 | 安卓「打开目录」变「复制目录到剪贴板」（沙盒目录文件管理器进不去） |
| `objects/obj_mod_menu/Step_0.gml` | L91-L113 | 行点击：占位行（`missing`/`failed`）只弹原因不同步开关；旧目录残留行给出 `get_mod_root_legacy_hint()` 完整路径与目标目录 |
| `objects/obj_mod_menu/Step_0.gml` | L131 | 删除 Mod 统一走 `external_mod_delete_folder`，去掉「仅支持 Windows」限制 |
| `objects/obj_mod_menu/Draw_0.gml` | L24-L39 | 列表顶部常驻「目录：`<mod_root>`」，路径不同源时玩家能自查；`list_top` 因此从 `y-205` 调到 `y-192` |
| `objects/obj_mod_menu/Draw_0.gml` | L41-L83 | 四类行状态：正常开启/关闭、加载失败（红字点名）、旧目录残留（橙字「需要搬到新目录」）、扫描不到（红字）；占位行状态栏画「—」 |
| `objects/obj_mod_menu/Draw_0.gml` | L96-L123 | 列表为空时安卓额外画投放引导：标题 + `get_mod_root_hint_lines()` 逐行（按像素宽度截断加 `…`，绝对路径不会画到面板外）+ 回来点刷新；外部目录不可用时改为只提示「无法访问外部目录」 |
| `scripts/NativeUtil/NativeUtil.gml` | `get_mod_root_legacy_hint()` | 返回旧落点完整路径，供「你的 Mod 还在旧目录里」提示使用 |
| `objects/obj_game_init/Create_0.gml` | L67-L77 | 安卓分支主动调 `get_mod_root()`，启动时就建好 / 探测好目录（含 `Android/media` 中间层建立） |

安置位置的三类对照（为什么选第二类）：

| 位置 | 需 root | 需权限 | 玩家怎么放 | GML 能否读写 |
|------|---------|--------|-----------|--------------|
| `/data/data/com.company.game/`（引擎保存区） | 否，但玩家看不见 | 无 | 只能游戏内导入 | 能读写 |
| `/storage/emulated/0/Android/media/com.company.game/files/`（应用外部私有目录的 media 分支，**当前采用**） | 否 | 无 | 任意文件管理器 / USB / MTP 直接可见，也能 `adb push` | 能读写 |
| `/storage/emulated/0/Android/data/com.company.game/files/`（旧落点，**保留为回退**） | 否 | 无 | Android 11+ 文件管理器看不到，只能 `adb push` / MTP | 能读写 |
| `/storage/emulated/0/Download/` | 否 | `MANAGE_EXTERNAL_STORAGE` | 任意文件管理器 | 有权限才通 |

注意：`WRITE_EXTERNAL_STORAGE` 在 API 30+ 被系统忽略，本项目 targetSdk 35 下即使打开也拿不到公共目录；要公共目录只能申请 `MANAGE_EXTERNAL_STORAGE`（会弹「访问所有文件」授权）。`/Android/media/<包名>/` 不需要任何权限，这是把它作为首选落点的原因。

安卓端功能边界（改造后仍然的限制）：
- Lua 行为脚本不执行（后端是 Windows PE DLL，工程内无 `.so`），卡片退化为「纯 JSON 声明式」——属性、子弹、动画都正常，只有自定义行为没有。
- 压缩包导入不可用（无 `get_open_filename`、无 ZIP 解包）：玩家必须在 PC 上解压好，把文件夹整体投放进 `/storage/emulated/0/Android/media/com.company.game/files/mod/`。
- 老安装上放在 `/Android/data/<包名>/files/mod/` 的 Mod 会在首次启动时**自动复制**进 `/Android/media/com.company.game/files/mod/`（旧包不删，确认无误后可手动清理）；若复制失败（如旧目录只读），仍会回退旧目录继续加载。
- 目录若被系统拒绝写入，`mod_state.json` 仍会落在沙盒，界面会提示「Mod 目录只读」。

---

## 6. 异步弹窗修复（show_question 废弃）

功能：Android 禁止同步弹窗 `show_question`，改为异步 `show_question_async` + Async-Dialog 事件处理。

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_update_checker_btn/Other_62.gml` | 整个文件 | 改为 `update_url = html_url; show_question_async(msg);` |
| `objects/obj_update_checker_btn/Other_63.gml` | 整个文件（新建） | Async-Dialog 事件：`async_load` 处理，用户确认后 `url_open(update_url)` |
| `objects/obj_update_checker_btn/Create_0.gml` | 整个文件 | 新增 `update_url = ""` 初始化 |
| `objects/obj_update_checker_btn/obj_update_checker_btn.yy` | eventList | 注册 `eventNum:63` / `eventType:7`（Async-Dialog）事件 |

---

## 7. 横屏锁定

| 文件 | 位置 | 说明 |
|------|------|------|
| `options/android/options_android.yy` | 整个文件 | `option_android_orient_portrait` / `option_android_orient_portrait_flipped` 设为 `false`（仅保留横屏及横屏翻转） |

---

## 8. 授权系统

功能：启动未授权时强制弹授权窗（mandatory，不给走）。授权码 30+ 位，PC 端手打 + 复制识别码发 QQ 机器人；Android 端没有物理键盘，**全部手写适配**（源端 auth 实现无安卓分支，`NativeUtil` 也拿不到移动端稳定设备 ID，所以机器码改成首次启动随机生成）。

> ⚠️ 卸载重装 / 清除数据会删掉 `auth_hwid.dat`，机器码变旧授权码失效，需重新领码换绑；这是设计上的取舍（换绑成本 > 重装丢失成本），不要尝试让机器码"稳定"——移动端不存在稳定的设备指纹。

| 文件 | 位置 | 说明 |
|------|------|------|
| `scripts/auth_client/auth_client.gml` | `auth_file_path()` | 安卓 → `"auth.dat"`（沙盒内相对路径，不能用 `get_path_in_local_appdata`）；Windows → `%LOCALAPPDATA%\FVM_Reborn_makk\auth.dat` |
| `scripts/auth_client/auth_client.gml` | `auth_hwid()` | 安卓：读 `auth_hwid.dat`，缺失 → 随机 8 位十六进制写回；Windows：MD5(COMPUTERNAME \| PROCESSOR_IDENTIFIER \| NUMBER_OF_PROCESSORS) 取前 8 位 |
| `scripts/auth_client/auth_client.gml` | `auth_save()` | 写入目录创建逻辑包裹 `if (os_type != os_android)`（Windows 端 `directory_exists + directory_create`，Android 端相对路径直接落沙盒） |
| `objects/obj_auth_gate/Create_0.gml` | 顶部 | 面板高度按安卓加 72px：`panel_h = 470 + (os_type == os_android ? 72 : 0);`（粘贴按钮放在状态提示与底部按钮之间，其余版面全部用相对偏移，不影响） |
| `objects/obj_auth_gate/Create_0.gml` | 中部 | 新增安卓粘贴按钮变量：`android_paste / paste_x / paste_y / paste_w / paste_h / hover_paste`（位置 = 状态提示行下方、`status_y + 18`，整条 860×52） |
| `objects/obj_auth_gate/Create_0.gml` | `input_box.focus()` 之后 | 软键盘尝试：`if (os_type == os_android) try { keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_sentences, true); } catch(_e) {}`。**4 个参数缺一不可**（GM1020 只认 4 个，少写必编译报错）；`kbv_returnkey_done` 让回车键显示"完成"，`kbv_autocapitalize_sentences` 关自动大写（授权码要纯大写）。部分机型此函数无效，try/catch 只包软键盘这一行，粘贴按钮兜底 |
| `objects/obj_auth_gate/Step_0.gml` | `hover_ok/hover_no/hover_hwid` 之后 | 每帧追加 `hover_paste` 命中判定 |
| `objects/obj_auth_gate/Step_0.gml` | `_clicked/hover_no` 之前 | 粘贴按钮点击流程：`android_paste && _clicked && hover_paste` → `clipboard_get_text()` → 空则提示"剪贴板是空的" → `auth_clean()` 清洗空格/换行/零宽字符 → `input_box.set_text()` + `keyboard_string` → `_paste_submit = true` → 直接提交绑定（清洗很关键：QQ 复制常带杂字符，多一个就验不过） |
| `objects/obj_auth_gate/Step_0.gml` | `var _confirm = …` | 追加 `|| _paste_submit`，粘贴按钮点一次等同点"确认绑定" |
| `objects/obj_auth_gate/Draw_0.gml` | 状态提示行之后 | 安卓粘贴按钮绘制：`if (android_paste) { draw_roundrect_ext(…); draw_text_transformed("粘贴授权码（从剪贴板填入并确认）", …); }`（整条可点，不画外框） |
| `objects/obj_auth_gate/Create_0.gml` | 文件末尾 | 源端 Create 末尾已有授权启动块但缺 `global.auth_gate_force` 传参（Create 是同步执行的，在外面拿到实例再赋值已太晚）；**已嫁接**：`global.auth_gate_force = true; if (!auth_ok() && !instance_exists(obj_auth_gate)) instance_create_depth(0, 0, -9500, obj_auth_gate); global.auth_gate_force = false;` |
| `objects/obj_auth_gate/Step_0.gml` | 顶部 | `mandatory` 分支下关闭按钮移到屏幕外（`btn_no_x = -9999`），防止改坐标绕过 |
| `objects/obj_auth_gate/Other_3.gml` | 整个文件 | Async-Dialog 事件：授权成功弹窗后 3 秒自毁 |
| `objects/obj_auth_button/` | 整个目录 | 仅对象注册（Draw 里画"授权"按钮、Step 里 `mouse_check_button_pressed` 打开授权窗），无安卓分支，随目录整体保留即可 |

**同步覆盖必须重新嫁接的段**（源端 auth 实现无安卓分支，整文件覆盖会删掉下面所有 Android 专属逻辑）：

1. `auth_client.gml` 三处：`auth_file_path()` 相对路径、`auth_hwid()` 随机落盘、`auth_save()` 跳过建目录
2. `obj_auth_gate/Create_0.gml` 面板高度 + 粘贴按钮变量 + 软键盘尝试
3. `obj_auth_gate/Step_0.gml` 粘贴按钮 hover + 点击提交流程 + `_confirm` 追加 `_paste_submit`
4. `obj_auth_gate/Draw_0.gml` 安卓分支粘贴按钮绘制
5. `obj_game_init/Create_0.gml` 末尾授权启动块（含 `global.auth_gate_force` 传参）

---

## 9. 移动端软键盘（keyboard_virtual_show / hide）

功能：安卓没有物理键盘，所有需要打字的地方必须主动调起系统软键盘。`keyboard_virtual_*` 是 Android 专属调用，源端完全没有，同步覆盖必然丢失。

> ⚠️ **4 个参数缺一不可**：`keyboard_virtual_show(type, return_key, autocapitalization, predictive)`。只传 2 个会编译报错 `GM1020 函数 'keyboard_virtual_show' 接受至少 4 个参数`。

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/SearchBox/Create_0.gml` | `focus()` L84-88 | 全局输入框组件，弹**默认文本键盘** `kbv_type_default`（中英标点都能打）。改这一处覆盖存档命名 / 实验室 / 联机地图搜索等所有 SearchBox 输入框；输入仍走 `keyboard_string`，与既有 `on_step` 同步逻辑天然兼容，调用方无需改动 |
| `objects/SearchBox/Create_0.gml` | `blur()` L100-102 | 收起软键盘。`blur()` 是所有失去焦点的公共出口（点空白 / Esc / 切界面），一处覆盖全部关闭场景 |
| `objects/obj_auth_gate/Create_0.gml` | `_box.focus()` 之后 | 授权窗开窗时手动再拉一次 `kbv_type_default`。**与 SearchBox.focus() 内部那次是重复调用，属已知冗余，禁止以「去重」为由删除**（删除属于改动授权受保护层） |
| `objects/obj_material_sell_confirm/Create_0.gml` | Create 末尾 L56-65 | 道具出售窗（三用：卖材料 / 凭证回收 / 凭证购买）弹**数字键盘** `kbv_type_numbers`。该对象没有 focus 概念、全生命周期每帧读 `keyboard_string`，所以键盘跟着窗口生命周期走 |
| `objects/obj_material_sell_confirm/Create_0.gml` | `trade_close()` 开头 L68-73 | 收起键盘。确定 / 取消 / ESC 三条关闭路径全部经过 `trade_close()`，一处覆盖全部 |

### 统一规范（新增任何移动端输入时照此写）

1. 一律 4 个参数，少写必 GM1020 编译报错
2. `try/catch` **只包软键盘那一行**，不要把业务逻辑圈进去（部分机型 / 定制系统上该调用无效，失败不能影响输入流程）
3. 有 show 必须有配对的 hide；hide 放在**所有关闭路径都能走到的公共出口**（SearchBox → `blur()`，出售窗 → `trade_close()`），不要在每个按钮里各写一遍
4. 新增输入框一律用 `SearchBox`（自动获得弹/收键盘能力），**不要另手搓一套 `keyboard_virtual_show`**
5. 键盘类型按内容选：文本 → `kbv_type_default`；纯数字 → `kbv_type_numbers`；纯英文 → `kbv_type_ascii`

### 已知局限（真机表现，不是 bug）

- `keyboard_virtual_show` 在部分机型 / 定制系统上无效，退路是「最大」按钮 / 剪贴板粘贴 / 外接键盘
- 键盘弹起可能压缩 application surface，导致 `device_mouse_x_to_gui()` 与 `room_width/room_height` 混用的界面错位（如 `obj_material_sell_confirm`）。真机出现错位时把界面坐标统一改成 GUI 尺寸口径，或调整 `options/android` 的缩放策略
- 键盘唤出瞬间部分系统会重置输入缓冲区，`keyboard_string` 可能从预填值变空（如出售窗初值 `"1"`），属正常空态

---

## 10. 移动端右键取消（双击 / 双指误触）

功能：Windows 端各面板用 `mouse_check_button_pressed(mb_right)`（右键）作为「取消 / 返回」。安卓真机上，双指同按与快速连点会被引擎映射成 `mb_right`，表现为**在选卡界面连点两下就弹出退出确认窗**；同类误触还会让卡槽误取消选择、关卡预览窗误关、万皮龙误取消前摇。

> 处理口径：**安卓不认右键**，移动端返回只走虚拟 Esc 键（`obj_mobile_buttons`）。判定统一收敛到底层函数 `ui_back_click_pressed()`，禁止在安卓分支里另写裸 `mouse_check_button_pressed(mb_right)`。

| 文件 | 位置 | 说明 |
|------|------|------|
| `scripts/ui_input/ui_input.gml` | 全文件 | 新增底层判定函数 `ui_back_click_pressed()`：`if (os_type == os_android) return false;` 否则等价于 `mouse_check_button_pressed(mb_right)`。脚本已在 yyp 注册（`Folders: Util`） |
| `objects/obj_readyroom_manager/Step_0.gml` | L8 | 选卡界面退出确认窗（本次报障点）。改成 `keyboard_check_pressed(vk_escape) \|\| ui_back_click_pressed()` |
| `objects/obj_card_slot/Step_0.gml` | L151 | 右键取消选卡 |
| `objects/obj_level_preview/Step_0.gml` | L20 | 关闭关卡预览 |
| `objects/obj_shovel_slot/Step_0.gml` | L26 | 取消铲子选择 |
| `objects/obj_wanpilong/Step_0.gml` | L326 / L383 / L465 | 前摇取消（3 处） |

### 统一规范（新增「右键取消」入口时照此写）

1. 一律调用 `ui_back_click_pressed()`，**不要**直接写 `mouse_check_button_pressed(mb_right)`
2. `ui_back_click_pressed()` 只用于「取消 / 返回 / 关闭」，不要用于会改变游戏状态的战斗操作
3. 若某个入口在安卓上确实需要右键语义（例如外接鼠标的场景），必须先征得用户同意再单独开分支，不得默认放开
4. 源端没有 `scripts/ui_input/`，同步覆盖时**不得删除该脚本与其 yyp 注册**

---

## 附：全局事件类型映射（GMS2）

用于定位 `.yy` 中的事件文件：

| eventType / eventNum | 含义 | 文件命名 |
|------|------|------|
| 0 / 0 | Create | `Create_0.gml` |
| 3 / 1 | Begin Step | `Step_1.gml` |
| 3 / 0 | Step | `Step_0.gml` |
| 8 / 0 | Draw | `Draw_0.gml` |
| 8 / 64 | Draw GUI | `Draw_64.gml` |
| 7 / 62 | Async HTTP | `Other_62.gml` |
| 7 / 63 | Async Dialog | `Other_63.gml` |
| 6 / 4 | Mouse 左键按下 | `Mouse_4.gml` |