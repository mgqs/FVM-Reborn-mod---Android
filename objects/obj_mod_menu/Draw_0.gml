draw_set_font(font_yuan);
draw_set_alpha(0.78);
draw_set_color(c_black);
draw_rectangle(0, 0, room_width, room_height, false);
draw_set_alpha(1);
draw_set_color(#17314C);
draw_roundrect(x - 470, y - 335, x + 470, y + 335, false);
draw_set_color(#9DCFEC);
draw_roundrect(x - 450, y - 250, x + 450, y + 250, false);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(c_white);
draw_text(x, y - 320, "Mod管理");
draw_set_color(#D9F3FF);
draw_roundrect(x - 420, y - 305, x - 245, y - 270, false);
draw_roundrect(x - 230, y - 305, x - 35, y - 270, false);
draw_roundrect(x + 405, y - 305, x + 465, y - 270, false);
draw_set_color(#17314C);
draw_text(x - 332, y - 287, os_type == os_android ? "刷新列表" : "导入Mod");
draw_text(x - 132, y - 287, os_type == os_android ? "复制目录" : "打开目录");
draw_text(x + 435, y - 287, "关闭");

draw_set_halign(fa_left);
draw_set_color(#17314C);
draw_text(x - 420, y - 232, "Mod名称");
draw_text(x + 255, y - 232, "状态");
// 当前扫描的是哪个目录必须画出来：安卓上「Mod 生效了但列表空」十次有九次是
// 界面盯着的目录和加载器读的目录不是同一个，路径留在屏幕上玩家才能自己核对。
draw_set_color(#4A6E86);
var _root_label = "目录：" + mod_root;
var _root_max = 800;
if (string_width(_root_label) > _root_max) {
    while (string_length(_root_label) > 0 && string_width(_root_label + "…") > _root_max) {
        _root_label = string_delete(_root_label, string_length(_root_label), 1);
    }
    _root_label += "…";
}
draw_text(x - 420, y - 210, _root_label);
draw_set_color(#17314C);
for (var i = 0; i < array_length(mods); i++) {
    var row_y = list_top + i * row_height - scroll_offset + 26;
    if (row_y - 25 < list_top || row_y + 25 > list_bottom) continue;
    draw_set_color(i mod 2 == 0 ? #BEE5F4 : #ACD5E6);
    draw_rectangle(x - 430, row_y - 25, x + 430, row_y + 25, false);
    draw_set_color(#17314C);
    var display_name = mods[i].name;
    while (string_length(display_name) > 0 && string_width(display_name) > 620) {
        display_name = string_delete(display_name, string_length(display_name), 1);
    }
    if (display_name != mods[i].name) display_name += "…";
    draw_text(x - 410, row_y - 10, display_name);
    var _is_missing = variable_struct_exists(mods[i], "missing") && mods[i].missing;
    var _is_failed = variable_struct_exists(mods[i], "failed") && mods[i].failed;
    if (_is_missing) {
        // 这一行来自状态记录，但当前 Mod 目录里找不到对应文件夹。
        var _legacy_only = variable_struct_exists(mods[i], "legacy_only") && mods[i].legacy_only;
        draw_set_color(_legacy_only ? #B45309 : #A52929);
        draw_text(x - 410, row_y + 13, _legacy_only
            ? "还在旧目录（Android/data）里，需要搬到新目录"
            : "扫描不到这个文件夹，可能被移动到别处");
    } else if (_is_failed) {
        draw_set_color(#A52929);
        draw_text(x - 410, row_y + 13, "加载失败（点击条目查看原因）");
    } else {
        var load_status = mods[i].enabled ? "已开启，重启后生效" : "已关闭，重启后生效";
        if (mods[i].enabled && variable_global_exists("external_mod_errors") && variable_struct_exists(global.external_mod_errors, mods[i].folder)) {
            draw_set_color(#A52929);
        }
        draw_text(x - 410, row_y + 13, load_status);
    }
    var _dim = _is_missing || _is_failed;
    // 三元只能一层：嵌套写法在不同 GM 版本上会静默算错，这里拆成顺序赋值。
    var _btn_color = #9CA3AF;
    var _btn_text = "关闭";
    if (!_dim) {
        _btn_color = mods[i].enabled ? #6BCB77 : #9CA3AF;
        _btn_text = mods[i].enabled ? "开启" : "关闭";
    } else {
        _btn_text = "—";
    }
    draw_set_color(_btn_color);
    draw_roundrect(x + 245, row_y - 17, x + 325, row_y + 17, false);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_text(x + 285, row_y, _btn_text);
    draw_set_color(#E58B8B);
    draw_roundrect(x + 335, row_y - 17, x + 415, row_y + 17, false);
    draw_set_color(c_white);
    draw_text(x + 375, row_y, "删除");
    draw_set_halign(fa_left);
}

var content_height = list_bottom - list_top;
var total_height = max(content_height, array_length(mods) * row_height);
var track_x = x + 430;
draw_set_color(#7BA7B8);
draw_rectangle(track_x, list_top, track_x + 10, list_bottom, false);
var thumb_height = max(35, content_height * content_height / total_height);
var thumb_y = list_top + (content_height - thumb_height) * (scroll_offset / max(1, total_height - content_height));
draw_set_color(#17314C);
draw_rectangle(track_x, thumb_y, track_x + 10, thumb_y + thumb_height, false);
draw_set_color(#17314C);
draw_set_halign(fa_center);
if (array_length(mods) == 0) {
    draw_text(x, y - 60, "还没有安装 Mod");
    // 安卓玩家看不到应用私有目录，必须把「往哪儿放」直接画在界面上。
    if (os_type == os_android) {
        draw_set_color(#17314C);
        if (global.native_util.android_mod_root_usable()) {
            var _hint_lines = global.native_util.get_mod_root_hint_lines();
            draw_text(x, y - 20, "把解压后的 Mod 文件夹（含 manifest.json）放到：");
            var _max_width = 880;
            var _line_h = 30;
            var _hint_top = y + 16;
            for (var _h = 0; _h < array_length(_hint_lines); _h++) {
                // 绝对路径可能超出面板宽度，按像素宽度截断，别画到面板外面去。
                var _line = _hint_lines[_h];
                if (string_width(_line) > _max_width) {
                    while (string_length(_line) > 0 && string_width(_line + "…") > _max_width) {
                        _line = string_delete(_line, string_length(_line), 1);
                    }
                    _line += "…";
                }
                draw_text(x, _hint_top + _h * _line_h, _line);
            }
            draw_text(x, _hint_top + array_length(_hint_lines) * _line_h + 14, "用 USB/文件管理器投放后，回来点「刷新列表」");
        } else {
            draw_text(x, y + 20, "无法访问外部目录，暂不支持从文件管理器投放 Mod");
            draw_text(x, y + 52, "（外部存储被系统限制）");
        }
    }
}
if (status_text != "") {
    draw_set_valign(fa_top);
    var footer_text = string_replace_all(status_text, "\n", " ");
    while (string_length(footer_text) > 0 && string_width(footer_text) > 880) {
        footer_text = string_delete(footer_text, string_length(footer_text), 1);
    }
    if (footer_text != string_replace_all(status_text, "\n", " ")) footer_text += "…";
    draw_text(x, y + 270, footer_text);
}
draw_set_halign(fa_left);
draw_set_valign(fa_top);
