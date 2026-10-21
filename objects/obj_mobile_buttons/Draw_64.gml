// 移动端虚拟按键绘制（左下角）—— 仅 Android 显示
if (os_type != os_android) exit;

var _w = display_get_gui_width();
var _h = display_get_gui_height();
var _x = btn_margin;
var _esc_y = _h - btn_margin - btn_size;
var _shift_y = _esc_y - btn_size - btn_gap;
var _btn_w = btn_size * 1.5;
var _in_battle = instance_exists(obj_battle);

// 绘制单个圆角按钮
var _draw_button = function(_bx, _by, _label, _active, _pressed) {
    // 背景
    draw_set_alpha(1);
    if (_pressed) draw_set_color(make_color_rgb(0, 170, 255));
    else if (_active) draw_set_color(make_color_rgb(45, 45, 45));
    else draw_set_color(make_color_rgb(20, 20, 20));
    draw_roundrect(_bx, _by, _bx + _btn_w, _by + btn_size, false);

    // 边框
    draw_set_color(c_white);
    draw_set_alpha(_active ? 0.9 : 0.35);
    draw_roundrect(_bx, _by, _bx + _btn_w, _by + btn_size, true);

    // 文字
    draw_set_font(font_yuan);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_alpha(_active ? 1 : 0.4);
    draw_set_color(_active ? c_white : c_gray);
    draw_text(_bx + _btn_w / 2, _by + btn_size / 2, _label);

    draw_set_alpha(1);
    draw_set_color(c_white);
};

// Esc（下）全局生效；Shift（上）仅对局内生效
_draw_button(_x, _esc_y, "Esc", true, esc_flash > 0);
if (_in_battle) _draw_button(_x, _shift_y, "Shift", true, shift_flash > 0);
