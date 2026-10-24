// 移动端虚拟按键输入处理（Begin Step，确保先于其它对象 Step 模拟按键）
if (os_type != os_android) exit;

// 释放上一帧的模拟按键，保证 keyboard_check_pressed 能再次触发
if (esc_pulse > 0) {
    esc_pulse--;
    if (esc_pulse <= 0) keyboard_key_release(vk_escape);
}
if (shift_pulse > 0) {
    shift_pulse--;
    if (shift_pulse <= 0) keyboard_key_release(vk_shift);
}
if (esc_flash > 0) esc_flash--;
if (shift_flash > 0) shift_flash--;

var _w = display_get_gui_width();
var _h = display_get_gui_height();
var _x = btn_margin;
var _esc_y = _h - btn_margin - btn_size;
var _shift_y = _esc_y - btn_size - btn_gap;
var _btn_w = btn_size * 1.5;
var _in_battle = instance_exists(obj_battle);

for (var i = 0; i < 5; i++) {
    if (!device_mouse_check_button_pressed(i, mb_left)) continue;
    var _mx = device_mouse_x_to_gui(i);
    var _my = device_mouse_y_to_gui(i);

    // Esc（下）：全局生效
    if (_mx >= _x && _mx <= _x + _btn_w && _my >= _esc_y && _my <= _esc_y + btn_size) {
        keyboard_key_press(vk_escape);
        esc_pulse = 1;
        esc_flash = 10;
        continue;
    }
    // Shift（上）：仅对局内生效
    if (_in_battle && _mx >= _x && _mx <= _x + _btn_w && _my >= _shift_y && _my <= _shift_y + btn_size) {
        keyboard_key_press(vk_shift);
        shift_pulse = 1;
        shift_flash = 10;
    }
}
