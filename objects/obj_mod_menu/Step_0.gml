var import_job = global.external_mod_import_job;
if (is_struct(import_job) && !import_job.done && import_job.owner != id) {
    if (point_in_rectangle(mouse_x, mouse_y, x + 405, y - 305, x + 465, y - 270) && mouse_check_button_pressed(mb_left)) close_panel();
    exit;
}
if (is_struct(import_job) && import_job.owner == id) {
    if (import_job.done) {
        if (import_job.phase == "complete") {
            mods = import_job.next_entries;
            state_read_failed = false;
            state_default_enabled = true;
            if (external_mod_field(import_job, "operation", "import") == "import") refresh_mods(false);
            else scroll_offset = clamp(scroll_offset, 0, max(0, array_length(mods) * row_height - (list_bottom - list_top)));
        }
        global.external_mod_import_job = undefined;
        if (import_close_when_done) { close_panel(); exit; }
        if (import_job.phase == "cancelled") status_text = import_job.message;
        else if (import_job.phase == "complete" && external_mod_field(import_job, "operation", "import") != "import" && !external_mod_field(import_job, "warning", false)) status_text = import_job.message;
        else notify_result(import_job.message);
    } else {
        if (mouse_check_button_pressed(mb_left)) {
            if (point_in_rectangle(mouse_x, mouse_y, x + 405, y - 305, x + 465, y - 270)) {
                import_close_when_done = true;
                external_mod_import_cancel();
            } else if (point_in_rectangle(mouse_x, mouse_y, x - 78, y + 83, x + 78, y + 123)) {
                external_mod_import_cancel();
            }
        }
        exit;
    }
}

if (mouse_wheel_up()) scroll_offset = max(0, scroll_offset - row_height);
if (mouse_wheel_down()) scroll_offset = min(max(0, array_length(mods) * row_height - (list_bottom - list_top)), scroll_offset + row_height);

var content_height = list_bottom - list_top;
var total_height = max(content_height, array_length(mods) * row_height);
var thumb_height = max(35, content_height * content_height / total_height);
var thumb_max_y = list_bottom - thumb_height;
if (mouse_check_button_pressed(mb_left) && point_in_rectangle(mouse_x, mouse_y, x + 430, list_top, x + 440, list_bottom)) {
    dragging_scroll = true;
    drag_scroll_offset = mouse_y - (list_top + (content_height - thumb_height) * (scroll_offset / max(1, total_height - content_height)));
}
if (!mouse_check_button(mb_left)) dragging_scroll = false;
if (dragging_scroll) {
    var thumb_y = clamp(mouse_y - drag_scroll_offset, list_top, thumb_max_y);
    scroll_offset = ((thumb_y - list_top) / max(1, thumb_max_y - list_top)) * max(0, total_height - content_height);
}

if (point_in_rectangle(mouse_x, mouse_y, x + 405, y - 305, x + 465, y - 270) && mouse_check_button_pressed(mb_left)) {
    close_panel();
    exit;
}

if (point_in_rectangle(mouse_x, mouse_y, x - 420, y - 305, x - 245, y - 270) && mouse_check_button_pressed(mb_left)) {
    // 安卓没有 get_open_filename（桌面专属）也没有 native_unzip_map_file（Windows DLL），
    // 所以导入按钮在安卓上改成「刷新列表」：玩家把解压好的 Mod 文件夹直接放进 mod_root 再点这里。
    if (os_type == os_android) {
        refresh_mods();
        audio_play_sound(snd_button, 0, 0);
        var _lines = global.native_util.get_mod_root_hint_lines();
        var _msg = "已重新扫描 Mod 目录，共 " + string(array_length(mods)) + " 个包。\n"
            + "把解压后的 Mod 文件夹（含 manifest.json 或 card.json）放到：\n";
        for (var _i = 0; _i < array_length(_lines); _i++) _msg += _lines[_i] + "\n";
        notify_result(_msg + "投放后点「刷新列表」并重启游戏。");
        exit;
    }
    var selected = get_open_filename("Mod package|*.fvmmod;*.zip|All files|*.*", "");
    if (selected != "") {
        try { external_mod_import_start(selected, self); }
        catch (import_error) { notify_result(external_mod_error_text(import_error)); }
    }
    exit;
}

if (point_in_rectangle(mouse_x, mouse_y, x - 230, y - 305, x - 35, y - 270) && mouse_check_button_pressed(mb_left)) {
    // 安卓没有文件管理器可开；把路径复制到剪贴板，玩家粘到系统文件管理器里就能进目录。
    if (os_type == os_android) {
        clipboard_set_text(mod_root);
        status_text = "Mod 目录已复制到剪贴板：" + mod_root;
        audio_play_sound(snd_button, 0, 0);
    } else {
        var open_code = native_open_folder(mod_root);
        if (open_code != 0) status_text = "打开目录失败，错误码：" + string(open_code);
    }
}

for (var i = 0; i < array_length(mods); i++) {
    var row_y = list_top + i * row_height - scroll_offset + 26;
    if (row_y - 25 < list_top || row_y + 25 > list_bottom) continue;
    var _row_missing = variable_struct_exists(mods[i], "missing") && mods[i].missing;
    var _row_failed = variable_struct_exists(mods[i], "failed") && mods[i].failed;
    if (point_in_rectangle(mouse_x, mouse_y, x - 430, row_y - 25, x + 235, row_y + 25) && mouse_check_button_pressed(mb_left)) {
        if (variable_global_exists("external_mod_errors") && variable_struct_exists(global.external_mod_errors, mods[i].folder)) {
            notify_result("Mod 运行或加载时发现问题：" + mods[i].name + "\n" + global.external_mod_errors[$ mods[i].folder] + "\n修正文件后请重新启动游戏。");
        } else if (_row_missing) {
            var _legacy_only = variable_struct_exists(mods[i], "legacy_only") && mods[i].legacy_only;
            if (_legacy_only) {
                notify_result("这个 Mod 还在旧目录里：\n" + global.native_util.get_mod_root_legacy_hint()
                    + "\n\n把它整个文件夹移到下面的新目录，然后点「刷新列表」：\n" + mod_root);
            } else {
                notify_result("这个包的状态记录还在，但当前 Mod 目录里找不到文件夹：\n" + mod_root + "/" + mods[i].folder
                    + "\n\n如果刚才把文件夹移到别处，请放回上面的路径后点「刷新列表」。");
            }
        }
        exit;
    }
    // 「不可见 / 加载失败」的占位行不允许切换开关或删除：操作目标根本不存在，
    // 真要清理请玩家去文件管理器删，别让这里给出「删除失败」这种误导性反馈。
    if (_row_missing || _row_failed) continue;
    if (point_in_rectangle(mouse_x, mouse_y, x + 245, row_y - 17, x + 325, row_y + 17) && mouse_check_button_pressed(mb_left)) {
        // 安卓没有原生后台任务，开关只能直接翻并落盘；冲突检测仍走纯 GML 版本。
        if (os_type == os_android) {
            if (!mods[i].enabled) {
                try {
                    var _probe_pack = external_mod_validate(global.native_util.join_path(mod_root, mods[i].folder));
                    external_mod_check_enabled_conflicts(_probe_pack, mods, mod_root, mods[i].folder);
                }
                catch (_enable_error) {
                    notify_result("无法开启：" + external_mod_error_text(_enable_error));
                    exit;
                }
            }
            mods[i].enabled = !mods[i].enabled;
            if (!save_state()) mods[i].enabled = !mods[i].enabled;
            else status_text = (mods[i].enabled ? "已开启：" : "已关闭：") + mods[i].name + "，重启游戏后生效";
        } else {
            try { external_mod_manage_start(mods[i].enabled ? "disable" : "enable", self, i); }
            catch (manage_error) { notify_result(external_mod_error_text(manage_error)); }
        }
        audio_play_sound(snd_button, 0, 0);
    }
    if (point_in_rectangle(mouse_x, mouse_y, x + 335, row_y - 17, x + 415, row_y + 17) && mouse_check_button_pressed(mb_left)) {
        // 安卓没有原生后台任务（FvmNativeSupport 只有 Windows/macOS 版），走纯 GML 递归删除。
        if (os_type == os_android) {
            var delete_code = external_mod_delete_folder(mod_root + "/" + mods[i].folder);
            if (delete_code == 0) {
                status_text = "已删除：" + mods[i].name + "，重启后生效；保留卡片进度";
                refresh_mods();
            } else {
                status_text = "删除失败，错误码：" + string(delete_code);
            }
        } else {
            try { external_mod_manage_start("delete", self, i); }
            catch (manage_error) { notify_result(external_mod_error_text(manage_error)); }
        }
        audio_play_sound(snd_button, 0, 0);
        break;
    }
}
