以下文件/目录属于本项目的 Android 适配「受保护基础层」：此后 任何会话、任何修改、合并、重构或调试，一律不得改动其中既有的 Android 适配逻辑 （`os_type == os_android` 条件分支、剪贴板存档导入导出、`show_question_async` 异步弹窗、`obj_mobile_buttons` 虚拟按键、横屏锁定等）；若确需调整，必须先征得用户明确同意。完整位置索引见项目根目录《Android适配改造位置清单.md》。

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
- 面板动效 surface 收尾 / 自愈受保护组（2026-10-28 修「Unbalanced surface stack」后入库；源端合成屋强化页仍缺收尾，同步覆盖会重新引入，必须保留）：
  - `objects/obj_craft_bg/Draw_0.gml` 文件末尾 `panel_anim_end_parts(id, craft_parts, 260);` —— 强化页（`craft_top_tab == 0`）分支的唯一收尾，与转职/进化/融合三页同口径；删掉即每开动效必报错
  - `scripts/GuiStack/GuiStack.gml` —— `panel_anim_step()` 开头 `if (pnl_recording) { surface_reset_target(); pnl_recording = false }` 自愈块，以及各 `panel_anim_end_*` reset 后置 `pnl_recording = false`
  - `objects/obj_craft_bg/Destroy_0.gml` 、 `CleanUp_0.gml` —— `surface_free(card_surface)` 判存在并置 `-1`，避免 Destroy 与 CleanUp 双重释放
  - `objects/obj_package_bg/Draw_0.gml` —— 四处 `surface_reset_target()` 必须与 `surface_set_target()` 同条件 `surface_exists` 保护，否则 surface 缺失时会弹掉上层动效目标（如 `pnl_surf`）
- `objects/obj_edit_menu_button/Mouse_4.gml` 、`objects/obj_edit_menu/Create_0.gml` （存档导入导出/删除）
- `objects/obj_game_init/Create_0.gml` （启动 os 守卫 + 创建虚拟按键）
- `objects/obj_file_manager/Step_0.gml` 、`Other_3.gml` （IME/鼠标限频守卫）
- `objects/SearchBox/Create_0.gml` （IME 守卫）
- `objects/LaboratoryGUI/Create_0.gml` 、`objects/obj_mod_menu/Create_0.gml` 、`Step_0.gml` （目录操作守卫）
- `objects/obj_update_checker_btn/` （show_question_async 异步弹窗）
- `scripts/MapDownloadManager/MapDownloadManager.gml` 、`scripts/external_mod_system/external_mod_system.gml` （地图下载 / Mod Lua 守卫）
- `scripts/NativeUtil/NativeUtil.gml`
- `options/android/options_android.yy` （横屏锁定）
- `FVM_Reborn_makk.yyp`