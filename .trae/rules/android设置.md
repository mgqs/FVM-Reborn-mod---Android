以下文件/目录属于本项目的 Android 适配「受保护基础层」：此后 任何会话、任何修改、合并、重构或调试，一律不得改动其中既有的 Android 适配逻辑 （`os_type == os_android` 条件分支、剪贴板存档导入导出、`show_question_async` 异步弹窗、`obj_mobile_buttons` 虚拟按键、横屏锁定等）；若确需调整，必须先征得用户明确同意。完整位置索引见项目根目录《Android适配改造位置清单.md》。

**新增文件路径 / 存储位置改造（Windows 绝对路径 → Android）另受本文末尾《文件路径 / 存储位置规范（Windows → Android）》约束，务必先读那一节再动手。**

受保护清单：

- `objects/obj_mobile_buttons/` （虚拟按键 Esc/Shift）
- `objects/obj_battle/Step_0.gml` （仅限其中移动端 Shift 加速接线段：`global.mobile_shift_pressed` 锁存标志的消费与清除，约 L233-243；该文件其余游戏逻辑不受保护，同步覆盖后必须重新嫁接此段）
- 双指滑动受保护组（遍历 `device_mouse_check_button(_d, mb_left)` 0..9 收集触点取中点、帧间差值驱动滚动；禁止整文件覆盖，同步覆盖后必须重新嫁接此段；对应 Create_0 的 `two_touch_scroll_active/two_touch_scroll_y` 初始化同属受保护）：
  - `objects/obj_package_bg/Draw_0.gml` （背包，驱动 `y_offset_target`，上限 `max_y_offset_1..4`）
  - `objects/obj_craft_bg/Draw_0.gml` + `Create_0.gml` （合成屋；尾部滚动条段内按 `craft_top_tab` 分流：==2 转职页驱动 `tg_scroll_target`/`tg_rows_max`、==3 进化页驱动 `evo_scroll_target`/`evo_rows_max`（整行 96px 折算）、==0 强化页驱动 `y_offset_target`；双指入口须带 `!tg_sb.on && !evo_sb.on` 滑块拖动优先判断）
  - `objects/obj_info_island_bg/Draw_0.gml` （情报岛）
  - `objects/obj_readyroom_manager/Draw_0.gml` + `Create_0.gml` （选卡界面，上限 `ready_max_y_offset`）
  - `objects/obj_cookbook_bg/Draw_0.gml` + `Create_0.gml` （食神谱，按行高 101 折算）
  - `objects/GridList/Create_0.gml` （通用列表 `apply_wheel` 段）
- 移动端右键取消受保护组（2026-11-03 入库；Android 上双指同按 / 快速连点会被引擎映射成 `mb_right`，导致选卡界面误弹退出确认窗、卡槽误取消选择、关卡预览窗误关闭、万皮龙误取消前摇。统一收敛到 `ui_back_click_pressed()`，安卓恒返回 `false`，移动端返回只走虚拟 Esc）：
  - `scripts/ui_input/ui_input.gml` + `ui_input.yy` —— 新增脚本资源，yyp 已注册；属底层保护层，同步时不得删除、不得被源端无此文件覆盖掉
  - 全部调用点（一律用 `ui_back_click_pressed()` 替代裸 `mouse_check_button_pressed(mb_right)`，禁止在安卓上另写裸右键判定）：
    - `objects/obj_readyroom_manager/Step_0.gml`（选卡界面退出确认窗，约 L8）
    - `objects/obj_card_slot/Step_0.gml`（右键取消选卡，约 L151）
    - `objects/obj_level_preview/Step_0.gml`（关闭关卡预览，约 L20）
    - `objects/obj_shovel_slot/Step_0.gml`（取消铲子选择，约 L26）
    - `objects/obj_wanpilong/Step_0.gml`（前摇取消，3 处）
- 面板动效 surface 收尾 / 自愈受保护组（2026-10-28 修「Unbalanced surface stack」后入库；源端合成屋强化页仍缺收尾，同步覆盖会重新引入，必须保留）：
  - `objects/obj_craft_bg/Draw_0.gml` 文件末尾 `panel_anim_end_parts(id, craft_parts, 260);` —— 强化页（`craft_top_tab == 0`）分支的唯一收尾，与转职/进化/融合三页同口径；删掉即每开动效必报错
  - `scripts/GuiStack/GuiStack.gml` —— `panel_anim_step()` 开头 `if (pnl_recording) { surface_reset_target(); pnl_recording = false }` 自愈块，以及各 `panel_anim_end_*` reset 后置 `pnl_recording = false`
  - `objects/obj_craft_bg/Destroy_0.gml` 、 `CleanUp_0.gml` —— `surface_free(card_surface)` 判存在并置 `-1`，避免 Destroy 与 CleanUp 双重释放
  - `objects/obj_package_bg/Draw_0.gml` —— 四处 `surface_reset_target()` 必须与 `surface_set_target()` 同条件 `surface_exists` 保护，否则 surface 缺失时会弹掉上层动效目标（如 `pnl_surf`）
- `objects/obj_edit_menu_button/Mouse_4.gml` 、`objects/obj_edit_menu/Create_0.gml` （存档导入导出/删除）
- `objects/obj_game_init/Create_0.gml` （启动 os 守卫 + 创建虚拟按键 + 授权启动块：文件末尾 `auth_init();` → `global.auth_gate_force=true;` → `if(!auth_ok() && !instance_exists(obj_auth_gate)) instance_create_depth(…);` → `global.auth_gate_force=false;`；源端同位置已有授权启动块，但缺少 `global.auth_gate_force` 传参——同步覆盖后必须重新嫁接此块）
- `objects/obj_file_manager/Step_0.gml` 、`Other_3.gml` （IME/鼠标限频守卫）
- `objects/SearchBox/Create_0.gml` （IME 守卫 + 移动端软键盘：`focus()` 里 `if (os_type == os_android) try { keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_sentences, true) } catch(_e){}`，`blur()` 里 `if (os_type == os_android) try { keyboard_virtual_hide() } catch(_e){}`；**4 个参数缺一不可**，少写必编译报错 GM1020；该文件是所有输入框的公共组件，同步覆盖后必须重新嫁接这两个安卓分支）
- `objects/LaboratoryGUI/Create_0.gml` 、`objects/obj_mod_menu/Create_0.gml` 、`Step_0.gml` （目录操作守卫）
- `objects/obj_update_checker_btn/` （show_question_async 异步弹窗）
- `objects/obj_material_sell_confirm/Create_0.gml` （移动端数字软键盘；该窗三用：道具页卖材料 / 凭证回收 / 凭证购买，全生命周期每帧读 `keyboard_string`，没有 focus 概念：Create 末尾 `if (os_type == os_android) try { keyboard_virtual_show(kbv_type_numbers, kbv_returnkey_done, kbv_autocapitalize_sentences, true) } catch(_e){}`，`trade_close()` 开头 `if (os_type == os_android) try { keyboard_virtual_hide() } catch(_e){}`（确定/取消/ESC 三条关闭路径都走 trade_close，一处覆盖全部）；**4 个参数缺一不可**，少写必编译报错 GM1020；同步覆盖后必须重新嫁接这两段）
- `scripts/MapDownloadManager/MapDownloadManager.gml` 、`scripts/external_mod_system/external_mod_system.gml` （地图下载 / Mod Lua 守卫）
- `scripts/NativeUtil/NativeUtil.gml`
- `options/android/options_android.yy` （横屏锁定）
- `FVM_Reborn_makk.yyp`
- 移动端软键盘受保护组（2026-10-30 入库；`keyboard_virtual_show/hide` 是 Android 专属调用，源端完全没有，同步覆盖必然丢失）：
  - 三个落点，全部必须重新嫁接：
    - `objects/SearchBox/Create_0.gml` — 全局输入框组件。`focus()` 弹键盘（`kbv_type_default` 文本键盘）、`blur()` 收起。改这一处覆盖存档命名 / 实验室 / 联机地图搜索等所有 SearchBox 输入框
    - `objects/obj_auth_gate/Create_0.gml` — 授权窗开窗时 `_box.focus()` 之后手动再拉一次键盘（`kbv_type_default`）。**与 SearchBox.focus() 内部那次是重复调用，属已知冗余，禁止以「去重」为由删除**
    - `objects/obj_material_sell_confirm/Create_0.gml` — 道具出售窗（三用：卖材料 / 凭证回收 / 凭证购买）。Create 末尾弹 `kbv_type_numbers` 数字键盘，`trade_close()` 开头收起（确定/取消/ESC 三条关闭路径都走这里）
  - **统一规范（新增任何移动端输入时照此写）**：
    1. 一律 4 个参数：`keyboard_virtual_show(kbv_type_*, kbv_returnkey_done, kbv_autocapitalize_sentences, true)`。少写必编译报错 GM1020（`keyboard_virtual_show` 至少 4 个参数）
    2. `try/catch` **只包软键盘那一行**，不要把业务逻辑圈进去（部分机型/定制系统上该调用无效，失败不能影响输入流程）
    3. 有 show 必须有配对的 hide；hide 放在**所有关闭路径都能走到的公共出口**（SearchBox 用 `blur()`，出售窗用 `trade_close()`），不要在每个按钮里各写一遍
    4. 新增输入框一律用 `SearchBox`（自动获得弹/收键盘能力），**不要另手搓一套 `keyboard_virtual_show`**
  - 已知局限（真机表现，不是 bug）：`keyboard_virtual_show` 在部分机型无效（退路是「最大」按钮 / 粘贴 / 外接键盘）；键盘弹起可能压缩 application surface 导致 `device_mouse_x_to_gui` 与 `room_width` 混用的界面错位，出现时再单独处理
- 授权系统安卓适配受保护组（2026-10-29 入库；源端 auth 实现无安卓分支，全部手写嫁接）：
  - `scripts/auth_client/auth_client.gml` — `auth_file_path()` 安卓返回相对路径 `"auth.dat"`（沙盒内），`auth_hwid()` 安卓读/写 `auth_hwid.dat`（首次启动随机生成 8 位十六进制），`auth_save()` 跳过 Windows 建目录逻辑；源端这三处都是裸实现，同步覆盖会删掉所有安卓分支，必须重新嫁接
  - `objects/obj_auth_gate/Create_0.gml` — 面板高度按安卓加 72px、新增 `android_paste/paste_x/paste_y/paste_w/paste_h/hover_paste` 变量、尝试 `keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_sentences, true)` 拉软键盘（4 个参数，GM1020 只认 4 个，少写必编译报错）、`input_box.focus()` 之后接软键盘调用；**注意**：`keyboard_virtual_show` 在部分机型上无效，try/catch 只包软键盘这一行
  - `objects/obj_auth_gate/Step_0.gml` — 每帧计算 `hover_paste`、新增「点粘贴按钮 → `clipboard_get_text()` → `auth_clean()` → `input_box.set_text()` + `keyboard_string` → 直接提交绑定」流程；`_confirm` 判定须追加 `|| _paste_submit`
  - `objects/obj_auth_gate/Draw_0.gml` — 只在 `os_type == os_android` 分支下画整条可点的粘贴授权码按钮（矩形 + 居中文案）
  - `objects/obj_auth_button/` — 仅对象注册与创建，无安卓分支，随目录整体保留即可

---

## 文件路径 / 存储位置规范（Windows → Android）

2026-11-14 入库。**本工程此后凡遇到「Windows 绝对路径 → Android」的改造（读取玩家投放的文件、程序自写状态、日志、缓存、地图、Mod、音乐……），一律按本节规范执行，并把每个新落点登记到本节末尾的表格里。** 这是硬规则，不是建议；违反它的改动在合并时要退回重做。

### 两类目录，不要混用

| 用途 | 位置 | 写法 | 说明 |
|------|------|------|------|
| 玩家要投放 / 取回的文件 | `/storage/emulated/0/Android/data/<包名>/files/<子目录>`（**应用外部私有目录**） | 绝对路径，由 `get_external_files_root()` 拼接 | 零权限、无需 root、USB/MTP/`adb push` 可投放、GML 可读写 |
| 程序自己写、玩家不需要看的 | 沙盒相对路径（如 `saves/saveN.json`、`mod_state.json`、`auth.dat`） | 直接相对路径，不要拼 `%LOCALAPPDATA%` | 引擎映射到保存区；Windows 是 `%LOCALAPPDATA%\FVM_Reborn_makk`，Android 是 `/data/<包名>`（未 root 不可见） |

公共目录（`/storage/emulated/0/Download/` 等）**不采用**：需要 `MANAGE_EXTERNAL_STORAGE`（弹「访问所有文件」授权）；而 `WRITE_EXTERNAL_STORAGE` 在 API 30+ 已被系统忽略，本项目 targetSdk 35 下打开也无效。

### 新增跨平台路径时必须照此写

1. **路径拼接一律收敛到 `scripts/NativeUtil/NativeUtil.gml`**，不要散落在业务代码里。先加 getter，业务只调 getter。
2. **不得为安卓改动而变更 Windows 行为**：Windows 侧继续 `get_path_in_local_appdata("\\FVM_Reborn_makk\\...")`。
3. **禁止**把 `%LOCALAPPDATA%`、盘符、反斜杠绝对路径直接喂给安卓的 `file_*` / `directory_*` / `audio_create_stream`。喂错会静默返回 −1 / 空串，`audio_create_stream` 更会**直接抛致命异常崩游戏**（2026-11 已踩，`gml_Script_boss_music_resolve`）。
4. **目录探测不要依赖 `directory_create` 的返回值**（它只在保存区生效，对绝对路径多为空操作）。正确顺序：`directory_exists` → 写探针文件验证可写 → 成功后 `file_delete` 探针。
5. **探测结果必须缓存**到 `global._*`（如 `global._android_mod_root` / `_writable` / `_usable`），并保留 `_force` 参数供玩家中途建好目录后重探；每次刷新都写探针会明显拖慢界面。
6. **`file_find_first` 的 `fa_directory` / `fa_archive` / `fa_readonly` 只在 Windows 有效**，其他平台必须传 `0`，否则永远扫到空列表（安卓表现为「目录里明明有文件却一个都读不到」）。封装成按平台返回的 helper 再调用。
7. **`file_find_first` 无匹配返回空字符串**（不是 −1），循环条件写 `while (f != "")`。
8. **拿不到外部私有目录时必须降级到沙盒相对路径**并在界面给提示，不允许抛异常、不允许白屏。
9. 路径分隔符统一用 `/`；mask 写 `<dir> + "/*"`，不要用 `\\`。
10. **安卓上没有的能力，入口必须改写，不得直接调用**：
    - `get_open_filename` / `get_save_filename` 仅桌面 → 换成「刷新列表」或界面内选择
    - `native_unzip_map_file` / `native_open_folder` / `native_delete_folder` 是 Windows DLL 导出 → 换成纯 GML 实现（递归删除）或复制路径到剪贴板
    - 工程内**无任何 `.so`**，Lua / 7z / 输入法后端全部是 Windows PE → 安卓上一律走「能力降级 + 界面提示」，不得静默失败
11. **Android 11+ 部分机型禁止文件管理器直达 `/Android/data/`**：界面必须同时给「复制路径到剪贴板」和文字引导（含 `manifest.json` 之类的落地要求），不能只画一个路径就当玩家能投放。
12. **新增跨平台路径改造后必须双处登记**：本节末尾表格 + 项目根目录《Android适配改造位置清单.md》。漏登记的下次合并会被整份覆盖掉。

### 已落地登记

| 子目录 / 文件 | 位置 | Windows | Android | 说明 |
|---------------|------|---------|---------|------|
| Mod 根目录 | `scripts/NativeUtil/NativeUtil.gml` `get_mod_root()` | `%LOCALAPPDATA%\FVM_Reborn_makk\mod` | `<外部私有目录>/mod`，不可用降级 `"mod"` | 玩家投放解压好的 Mod 文件夹；探测结果缓存 `global._android_mod_root{,_writable,_usable}` |
| Mod 开关状态 | `scripts/external_mod_system/external_mod_system.gml` `external_mod_state_path()` | `<mod>/mod_state.json` | 沙盒 `mod_state.json` | 外部私有目录未必可写，状态固定落沙盒 |
| 应用外部私有目录基础路径 | `scripts/NativeUtil/NativeUtil.gml` `get_external_files_root()` | `%LOCALAPPDATA%\FVM_Reborn_makk` | 依次试 `EXTERNAL_STORAGE` → `/storage/emulated/0` → `/sdcard` → `/storage/self/primary`，拼 `/Android/data/<包名>/files` | 包名由 `get_android_package()` 提供，必须与 `options_android.yy` 的 domain/company/product 一致 |
| 存档 | `scripts/save_file/save_file.gml` / `scripts/load_file/load_file.gml` | 保存区 `saves/saveN.json` | 保存区 `saves/saveN.json` | 相对路径，GML 零平台分支（已有，供参照） |
| 授权文件 | `scripts/auth_client/auth_client.gml` `auth_file_path()` | 保存区 | 相对路径 `auth.dat` | 落盘一律 `file_text_*` + `json_stringify` |

其他受保护对照：`options/android/options_android.yy` 的 `permission_write_external_storage` 保持 `false`（打开了也没用且会误导），`option_android_target_sdk` / `compile_sdk` 为 `35`。