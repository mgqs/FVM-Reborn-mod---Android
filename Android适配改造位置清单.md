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

### 5.2 输入法（IME）/ 鼠标限频

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/obj_file_manager/Step_0.gml` | L37 / L42 / L52 | `native_enable_ime` / `native_disable_ime` 加 `os_type != os_android` |
| `objects/obj_file_manager/Step_0.gml` | L62 / L67 | 鼠标限频 `native_stop/start_mouse_limit` 加 `os_type != os_android` |
| `objects/obj_file_manager/Other_3.gml` | L5 | 关闭鼠标限频加 `os_type != os_android` |
| `objects/SearchBox/Create_0.gml` | L69 / L79 | IME enable / disable 加 `os_type != os_android` |

### 5.3 文件夹 / 目录操作

| 文件 | 位置 | 说明 |
|------|------|------|
| `objects/LaboratoryGUI/Create_0.gml` | L194 | `native_open_folder` Android 分支提示 |
| `objects/obj_mod_menu/Create_0.gml` | L2 | mod 目录创建加 `os_type != os_android` |
| `objects/obj_mod_menu/Step_0.gml` | L74 / L105 | mod 打开目录 / 删除文件夹 Android 分支 |

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