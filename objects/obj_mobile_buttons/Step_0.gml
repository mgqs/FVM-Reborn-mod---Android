// 移动端「缓释」消费端：开启后「点卡槽但还没放下」这段窗口里把帧率压到 30，放下 / 取消后还原
//
// 判据与海克斯「时间」词条（scripts/hex_batch3/hex_batch3.gml:2013-2036）同口径：
// 必须「卡槽真的被选中且还活着」——只看 global.selected_slot != noone，会在卡槽被销毁后
// 永远为真，那就成了一整局卡在 30 帧。
if (os_type != os_android) exit;

var _enabled = variable_global_exists("mobile_slowmo_enabled") && global.mobile_slowmo_enabled;
var _in_battle = instance_exists(obj_battle);
var _paused = variable_global_exists("is_paused") && global.is_paused;

// 海克斯「时间」/「速度锁」两个词条独占帧率（hex_batch3 每帧按自己的口径写 speed），
// 同时接管会每帧互相覆盖（120 / 30 交替），此时让给海克斯。
var _hex_owns_speed = false;
if (hex_enabled() && variable_global_exists("hex_state") && is_struct(global.hex_state)) {
    var _hs = global.hex_state;
    if (variable_struct_exists(_hs, "b3_time_slow") && _hs.b3_time_slow) _hex_owns_speed = true;
    if (variable_struct_exists(_hs, "b3_speed_lock") && _hs.b3_speed_lock) _hex_owns_speed = true;
}

var _dragging = false;
if (_enabled && _in_battle && !_paused && !_hex_owns_speed) {
    if (variable_global_exists("selected_slot") && global.selected_slot != noone) {
        var _sel = global.selected_slot;
        if (instance_exists(_sel)) {
            _dragging = (variable_instance_exists(_sel, "is_selected") && _sel.is_selected);
            // 情报岛 / 海克斯选词条面板盖着时卡槽 Step 直接 exit，选中状态会冻结在面板后面，
            // 这时继续压帧只会让面板滚动变卡
            if (_dragging && (instance_exists(obj_info_island_bg) || hex_picker_is_open())) _dragging = false;
        }
    }
}

if (_dragging) {
    var _now = game_get_speed(gamespeed_fps);
    if (_now != 30) {
        slow_prev_fps = _now;
        game_set_speed(30, gamespeed_fps);
    }
    slow_active = true;
} else if (slow_active) {
    // 只还原自己压下去的那一次：外部（房间结束 / 海克斯）已经改过就不插手
    if (game_get_speed(gamespeed_fps) == 30) {
        var _restore = (slow_prev_fps > 30) ? slow_prev_fps : 60;
        game_set_speed(_restore, gamespeed_fps);
    }
    slow_prev_fps = 0;
    slow_active = false;
}
