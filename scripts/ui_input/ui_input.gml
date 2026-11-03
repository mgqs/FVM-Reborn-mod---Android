/// ui_input —— 输入层统一判定（平台差异收敛在这里，不要在各面板各写一遍）

/// @func ui_back_click_pressed()
/// @desc 取消/返回用的「右键点击」判定。
///   Windows：与原来的 mouse_check_button_pressed(mb_right) 完全等价。
///   Android：**一律返回 false**。原因见 .trae/rules/android设置.md「移动端右键取消」条：
///   移动端双指同按 / 快速连点会被引擎映射成 mb_right，
///   导致选卡界面误弹退出确认窗、卡槽误取消选择、预览窗误关闭、万皮龙误取消前摇。
///   移动端的返回只走虚拟 Esc 键（obj_mobile_buttons）。
/// @returns {Bool}
function ui_back_click_pressed() {
    if (os_type == os_android) return false;
    return mouse_check_button_pressed(mb_right);
}
