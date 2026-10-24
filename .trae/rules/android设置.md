以下文件/目录属于本项目的 Android 适配「受保护基础层」：此后 任何会话、任何修改、合并、重构或调试，一律不得改动其中既有的 Android 适配逻辑 （`os_type == os_android` 条件分支、剪贴板存档导入导出、`show_question_async` 异步弹窗、`obj_mobile_buttons` 虚拟按键、横屏锁定等）；若确需调整，必须先征得用户明确同意。完整位置索引见项目根目录《Android适配改造位置清单.md》。

受保护清单：

- `objects/obj_mobile_buttons/` （虚拟按键 Esc/Shift）
- `objects/obj_battle/Step_0.gml` （仅限其中移动端 Shift 加速接线段：`global.mobile_shift_pressed` 锁存标志的消费与清除，约 L233-243；该文件其余游戏逻辑不受保护，同步覆盖后必须重新嫁接此段）
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