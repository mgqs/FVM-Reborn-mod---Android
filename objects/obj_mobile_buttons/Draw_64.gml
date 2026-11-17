// 移动端虚拟按键绘制（左下角）—— 仅 Android 显示
if (os_type != os_android) exit;

var _w = display_get_gui_width();
var _h = display_get_gui_height();
var _x = btn_margin;
var _esc_y = _h - btn_margin - btn_size;
var _shift_y = _esc_y - btn_size - btn_gap;
var _slow_y = _shift_y - btn_size - btn_gap;
var _btn_w = btn_size * 1.5;
var _in_battle = instance_exists(obj_battle);
var _slow_on = variable_global_exists("mobile_slowmo_enabled") && global.mobile_slowmo_enabled;

// 绘制单个圆角按钮（_on = 开关类按钮的「已开启」底色）
var _draw_button = function(_bx, _by, _label, _active, _pressed, _button_width, _on) {
    // 背景
    draw_set_alpha(1);
    if (_pressed) draw_set_color(make_color_rgb(0, 170, 255));
    else if (_on) draw_set_color(make_color_rgb(0, 96, 150));
    else if (_active) draw_set_color(make_color_rgb(45, 45, 45));
    else draw_set_color(make_color_rgb(20, 20, 20));
    draw_roundrect(_bx, _by, _bx + _button_width, _by + btn_size, false);

    // 边框
    draw_set_color(c_white);
    draw_set_alpha(_active ? 0.9 : 0.35);
    draw_roundrect(_bx, _by, _bx + _button_width, _by + btn_size, true);

    // 文字
    draw_set_font(font_yuan);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_alpha((_active || _on) ? 1 : 0.4);
    draw_set_color((_active || _on) ? c_white : c_gray);
    draw_text(_bx + _button_width / 2, _by + btn_size / 2, _label);

    draw_set_alpha(1);
    draw_set_color(c_white);
};

// Esc（下）全局生效；Shift（中）/ 缓释（上）仅对局内生效
_draw_button(_x, _esc_y, "Esc", true, esc_flash > 0, _btn_w, false);
if (_in_battle) {
    _draw_button(_x, _shift_y, "Shift", true, shift_flash > 0, _btn_w, false);
    // 按钮文字直接显示开关状态；开启中且有卡正在手上（slow_active）时按钮常亮亮蓝，给出「正在缓释」的反馈
    var _slow_label = _slow_on ? "缓释:开" : "缓释:关";
    _draw_button(_x, _slow_y, _slow_label, true, slow_flash > 0 || slow_active, _btn_w, _slow_on);
}
