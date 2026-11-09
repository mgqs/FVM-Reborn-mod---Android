///
self.state = {
    left: 0,
    top: 0,
    width: 420,
    height: 40,
    text: "",
    placeholder: "搜索名称或作者",
    focused: false,
    cursor_visible: true,
    cursor_timer: 0,
    /// 2026-11-05：光标插入位置（0 = 最前、string_length(text) = 末尾）+ 上一帧 keyboard_string 副本
    caret: 0,
    kb_prev: "",
    /// @type {function}
    on_change: undefined,
    /// @type {function ():Bool}
    should_correspond: function() { return true },
    /// @type {Struct|undefined} 可选配色；undefined = 原来的米色（实验室 / 联机地图两处不变）
    ///   { bg, bg_focus, border, border_focus, text, placeholder }
    theme: undefined,
}

/// @func set_theme(theme) 换配色（不调它 = 原来的米色 + 描边字）
function set_theme(_theme) {
    self.state.theme = _theme
    return self
}

function set_position(_left, _top) {
    self.state.left = _left
    self.state.top = _top
    return self
}

function set_size(_width, _height) {
    self.state.width = _width
    self.state.height = _height
    return self
}

function set_placeholder(_text) {
    self.state.placeholder = _text
    return self
}

function set_on_change(_on_change) {
    self.state.on_change = _on_change
    return self
}

function set_should_correspond(_should_correspond) {
    if (is_undefined(_should_correspond)) {
        throw("SearchBox: should_correspond must be a function")
    }
    self.state.should_correspond = _should_correspond
    return self
}

function get_text() {
    return self.state.text
}

function set_text(_text) {
    self.state.text = string(_text)
    // 2026-11-05：外部改文字时光标跟到末尾，并把 keyboard_string 对齐 —— 否则下一帧的
    //   「新旧串比对」会拿旧串当输入，把刚设进去的文字覆盖回去
    self.state.caret = string_length(self.state.text)
    keyboard_string = self.state.text
    self.state.kb_prev = keyboard_string
    return self
}

function emit_change() {
    if (!is_undefined(self.state.on_change)) {
        self.state.on_change(self.state.text)
    }
}

function focus() {
    if (self.state.focused) {
        return
    }
    self.state.focused = true
    // 2026-10-31：点进去立刻显示光标（不重置的话可能正好落在「灭」的相位，最多 0.5s 看不到竖线）
    self.state.cursor_timer = 0
    self.state.cursor_visible = true
    keyboard_string = self.state.text
    self.state.kb_prev = keyboard_string
    self.state.caret = string_length(self.state.text)
    if (os_type != os_android && variable_global_exists("ime_block") && native_enable_ime != undefined) {
        native_enable_ime(window_handle())
    }
    // Android：点输入框即调起系统软键盘（默认文本键盘，中英标点都能打）
    // 4 个参数缺一不可（GM1020 只认 4 个）；部分机型/定制系统上该调用无效，
    // 所以必须 try/catch——失败也不影响输入流程，玩家仍可粘贴/外接键盘。
    if (os_type == os_android) {
        try {
            keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_sentences, true)
        } catch (_e) {}
    }
}

/// @func searchbox_any_focused(_except)
/// @desc 除了 _except 这个实例之外，是否还有别的输入框已经拿到焦点
///   同一画面可能同时存在多个输入框（情报岛 / 授权 / 商店凭证），
///   点另一个框时两个实例的 Step 都会跑：先 focus 再 blur 会把刚弹出来的键盘又收掉
function searchbox_any_focused(_except) {
    var _found = false
    with (SearchBox) {
        if (id != _except && state.focused) {
            _found = true
        }
    }
    return _found
}

function blur() {
    if (!self.state.focused) {
        return
    }
    self.state.focused = false
    if (os_type != os_android && variable_global_exists("ime_block") && global.ime_block && native_disable_ime != undefined) {
        native_disable_ime(window_handle())
    }
    // Android：失去焦点（点空白 / Esc / 界面切走）时收起软键盘，避免键盘一直压着画面
    //   但如果玩家是点了「另一个」输入框，键盘马上会被对方重新调起来，这里就别关了
    if (os_type == os_android) {
        if (!searchbox_any_focused(id)) {
            try { keyboard_virtual_hide() } catch (_e) {}
        }
    }
}

function contains_point(_mx, _my) {
    return point_in_rectangle(
        _mx, _my,
        self.state.left, self.state.top,
        self.state.left + self.state.width,
        self.state.top + self.state.height)
}

/// @func insert_at_caret(text) 在光标处插入文字（2026-11-05）
function insert_at_caret(_t) {
    _t = string(_t)
    if (_t == "") return
    var _c = clamp(self.state.caret, 0, string_length(self.state.text))
    self.state.text = string_copy(self.state.text, 1, _c) + _t + string_delete(self.state.text, 1, _c)
    self.state.caret = _c + string_length(_t)
}

/// @func set_caret_from_mouse(mx) 点击时按字符宽度找最近的字缝（2026-11-05）
function set_caret_from_mouse(_mx) {
    var _t = self.state.text
    var _n = string_length(_t)
    var _rel = _mx - (self.state.left + 12)
    if (_rel <= 0 || _n == 0) {
        self.state.caret = 0
        return
    }
    draw_set_font(font_yuan)
    var _i = 0
    var _w0 = 0
    while (_i < _n) {
        var _w1 = string_width(string_copy(_t, 1, _i + 1))
        if (_rel < (_w0 + _w1) * 0.5) break
        _w0 = _w1
        _i += 1
    }
    self.state.caret = _i
}

function on_create() {
}

function on_step() {
    if (!visible) {
        exit
    }
    if (!self.state.should_correspond()) {
        if (self.state.focused) {
            blur()
        }
        exit
    }

    if (mouse_check_button_pressed(mb_left)) {
        var _mx = device_mouse_x_to_gui(0)
        var _my = device_mouse_y_to_gui(0)
        if (contains_point(_mx, _my)) {
            focus()
            set_caret_from_mouse(_mx)      // 2026-11-05：点哪就把光标放到哪
        } else if (self.state.focused) {
            blur()
        }
    }

    if (!self.state.focused) {
        exit
    }

    if (keyboard_check_pressed(vk_escape)) {
        blur()
        exit
    }

    var _prev = self.state.text

    // ── 2026-11-05：支持「光标插在中间」（原来整串取 keyboard_string，只能在末尾加、末尾删）──
    //   自己维护 text + caret：每帧把 keyboard_string 和上一帧副本比对，只把「新增的那一段」
    //   插到光标处；随后回写 keyboard_string = text，让下一帧的比对基准永远是本框的文字。
    if (os_type == os_android) {
        // ── 2026-11-08 安卓：软键盘（系统输入法）自己维护文本缓冲，本框**只读不写** ──
        //   旧代码每帧都执行 keyboard_string = text 回写，等于每帧给输入法 setText 一次：
        //   组合态被打断（拼音一个字母都上不了屏），部分机型干脆把所有字符吞掉。
        //   现在把 keyboard_string 当唯一缓冲：只拿它和上一帧副本比对，吸收「变的那段」。
        var _akb = keyboard_string
        var _apk = self.state.kb_prev

        if (_akb != _apk) {
            var _len_kb = string_length(_akb)
            var _len_pk = string_length(_apk)
            if (_len_kb > _len_pk && string_pos(_apk, _akb) == 1) {
                // 正常打字 / 中文上屏：多出来的那段插到光标处
                insert_at_caret(string_delete(_akb, 1, _len_pk))
                self.state.kb_prev = _akb
            } else if (_len_kb < _len_pk && string_pos(_akb, _apk) == 1) {
                if (_akb == "" && self.state.text != "") {
                    // 输入法把缓冲清空了（刚弹键盘 / 机型差异）：重新播种，别误判成退格
                    keyboard_string = self.state.text
                    self.state.kb_prev = keyboard_string
                } else {
                    // 原生退格：缓冲末尾被删 → 改成「删光标前一个字」
                    if (self.state.caret > 0) {
                        self.state.text = string_delete(self.state.text, self.state.caret, 1)
                        self.state.caret -= 1
                    }
                    self.state.kb_prev = _akb
                }
            } else {
                // 兜底（组合态等判定不了的变化）：整串接管，光标跟到末尾
                self.state.text = _akb
                self.state.caret = string_length(_akb)
                self.state.kb_prev = _akb
            }
        } else if (keyboard_check_pressed(vk_backspace)) {
            // 退格：有的输入法只发按键、不改 keyboard_string
            if (self.state.caret > 0) {
                self.state.text = string_delete(self.state.text, self.state.caret, 1)
                self.state.caret -= 1
            }
        }
    } else if (keyboard_check(vk_control) && keyboard_check_pressed(ord("V"))) {
        insert_at_caret(clipboard_get_text())
    } else {
        var _kb = keyboard_string
        var _pk = self.state.kb_prev
        if (_kb != _pk) {
            if (string_length(_kb) > string_length(_pk) && string_pos(_pk, _kb) == 1) {
                // 正常打字 / 中文输入法上屏：多出来的那段插到光标处
                insert_at_caret(string_delete(_kb, 1, string_length(_pk)))
            } else if (string_length(_kb) < string_length(_pk) && string_pos(_kb, _pk) == 1) {
                // 原生退格：GM 已把键盘串末尾删掉 → 改成「删光标前一个字」
                if (self.state.caret > 0) {
                    self.state.text = string_delete(self.state.text, self.state.caret, 1)
                    self.state.caret -= 1
                }
            } else {
                // 兜底（输入法组合态等判定不了的变化）：整串接管，光标跟到末尾
                self.state.text = _kb
                self.state.caret = string_length(_kb)
            }
        }
    }

    // 方向键 / Home / End / Delete（移动后立刻显示光标，别正好落在「灭」的相位）
    var _prev_caret = self.state.caret
    if (keyboard_check_pressed(vk_left))  self.state.caret = max(0, self.state.caret - 1)
    if (keyboard_check_pressed(vk_right)) self.state.caret = min(string_length(self.state.text), self.state.caret + 1)
    if (keyboard_check_pressed(vk_home))  self.state.caret = 0
    if (keyboard_check_pressed(vk_end))   self.state.caret = string_length(self.state.text)
    if (keyboard_check_pressed(vk_delete) && self.state.caret < string_length(self.state.text)) {
        self.state.text = string_delete(self.state.text, self.state.caret + 1, 1)
    }

    if (string_length(self.state.text) > 64) {
        self.state.text = string_copy(self.state.text, 1, 64)
    }
    self.state.caret = clamp(self.state.caret, 0, string_length(self.state.text))
    // 桌面才回写：安卓回写等于每帧给输入法 setText 一次，会把组合态冲掉（见上面的分支注释）
    if (os_type != os_android) {
        keyboard_string = self.state.text
        self.state.kb_prev = keyboard_string
    }

    if (self.state.text != _prev || self.state.caret != _prev_caret) {
        self.state.cursor_timer = 0
        self.state.cursor_visible = true
    }

    if (self.state.text != _prev) {
        emit_change()
    }

    self.state.cursor_timer += 1
    if (self.state.cursor_timer >= 30) {
        self.state.cursor_timer = 0
        self.state.cursor_visible = !self.state.cursor_visible
    }
}

function on_draw() {
    if (!visible) {
        exit
    }
    var _s = self.state

    // ── 可选配色（商店凭证页那种深蓝底）：没设 theme 就走下面的原版米色 ──
    if (!is_undefined(_s.theme)) {
        var _th = _s.theme
        draw_set_alpha(1)
        draw_set_color(_s.focused ? _th.bg_focus : _th.bg)
        draw_roundrect(_s.left, _s.top, _s.left + _s.width, _s.top + _s.height, false)
        draw_set_color(_s.focused ? _th.border_focus : _th.border)
        draw_roundrect(_s.left, _s.top, _s.left + _s.width, _s.top + _s.height, true)

        draw_set_font(font_yuan)
        draw_set_halign(fa_left)
        draw_set_valign(fa_middle)
        // 光标位置：文字末端（空文本时 string_width("") = 0，正好落在左内边距 left+14）
        //   2026-11-05：改成「光标之前那段文字的宽度」，支持插在中间
        var _caret_x = _s.left + 14 + string_width(string_copy(_s.text, 1, _s.caret))
        if (_s.text == "") {
            // 空且已聚焦时只留光标，别让占位字和竖线叠在一起
            if (!_s.focused) {
                draw_set_color(_th.placeholder)
                draw_text(_s.left + 12, _s.top + _s.height * 0.5, _s.placeholder)
            }
        } else {
            draw_set_color(_th.text)
            draw_text(_s.left + 12, _s.top + _s.height * 0.5, _s.text)
        }
        // 2026-10-31：光标移到 if/else 外面 —— 空输入框聚焦时也要有闪烁竖线（原来只写在 else 里，空框一根线都没有）
        if (_s.focused && _s.cursor_visible) {
            draw_set_color(_th.text)
            draw_line(_caret_x, _s.top + 8, _caret_x, _s.top + _s.height - 8)
        }
        draw_set_halign(fa_left)
        draw_set_valign(fa_top)
        draw_set_color(c_white)
        exit
    }

    draw_set_alpha(0.72)
    draw_set_color(_s.focused ? make_color_rgb(250, 246, 230) : make_color_rgb(236, 228, 208))
    draw_roundrect(_s.left, _s.top, _s.left + _s.width, _s.top + _s.height, false)
    draw_set_alpha(1)
    draw_set_color(_s.focused ? make_color_rgb(120, 82, 40) : make_color_rgb(90, 72, 48))
    draw_roundrect(_s.left, _s.top, _s.left + _s.width, _s.top + _s.height, true)

    var _label = _s.text
    var _color_name = "font_hei_outline_4dir_black"
    var _caret_x2 = _s.left + 14 + string_width(string_copy(_label, 1, _s.caret))   // 空文本时 = 左内边距
    if (_label == "") {
        // 空且已聚焦时只留光标，占位字不画（否则竖线会压在第 1 个字上）
        if (!_s.focused) {
            scribble(_s.placeholder)
                .align(fa_left, fa_middle)
                .starting_format(_color_name)
                .blend(c_gray, 1)
                .draw(_s.left + 12, _s.top + _s.height * 0.5)
        }
    } else {
        scribble(_label)
            .align(fa_left, fa_middle)
            .starting_format(_color_name)
            .draw(_s.left + 12, _s.top + _s.height * 0.5)
    }
    // 2026-10-31：同深色分支，光标提到 if/else 外面，空输入框也闪
    if (_s.focused && _s.cursor_visible) {
        draw_set_color(c_black)
        draw_line(_caret_x2, _s.top + 8, _caret_x2, _s.top + _s.height - 8)
    }
}

on_create()
