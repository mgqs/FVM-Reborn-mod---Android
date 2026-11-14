/// 

function NativeUtil() constructor {

    
    /// @param {String} _path 
    /// @returns {String}
    static get_path_in_local_appdata = function(_path) {
        var _user_profile = environment_get_variable("LOCALAPPDATA")
        return self.transfer_path_to_windows(_user_profile + _path)
    }

    /// @param {String} _rel GML 沙盒相对路径
    /// @returns {String} native 可用的绝对路径
    static to_native_absolute = function(_rel) {
        _rel = string_replace_all(string(_rel), "/", "\\")
        while (string_starts_with(_rel, "\\")) {
            _rel = string_delete(_rel, 1, 1)
        }
        if (string_pos(":", _rel) > 0) {
            return self.transfer_path_to_windows(_rel)
        }
        return self.get_path_in_local_appdata("\\FVM_Reborn_makk\\" + _rel)
    }

    /// @func get_android_package()
    /// @desc 安卓包名，必须与 options/android/options_android.yy 的
    ///       package_domain + "." + package_company + "." + package_product 完全一致。
    /// @returns {String}
    static get_android_package = function() {
        return "com.company.game"
    }

    /// @func get_external_files_root()
    /// @desc 应用外部私有目录。安卓上零权限可读写，用户能用 USB/MTP 或文件管理器直接投放文件；
    ///       桌面端返回 %LOCALAPPDATA%\FVM_Reborn_makk（与旧行为一致）。
    /// @returns {String}
    static get_external_files_root = function() {
        if (os_type == os_android) {
            // EXTERNAL_STORAGE 只有老系统才有；新系统取不到时按常见挂载点依次试，
            // 取第一个真实存在的（/storage/emulated/0 是绝大多数机型的用户存储）。
            var _candidates = []
            var _env = environment_get_variable("EXTERNAL_STORAGE")
            if (is_string(_env) && _env != "") array_push(_candidates, _env)
            array_push(_candidates, "/storage/emulated/0")
            array_push(_candidates, "/sdcard")
            array_push(_candidates, "/storage/self/primary")
            var _pkg_dir = "/Android/data/" + self.get_android_package() + "/files"
            for (var _i = 0; _i < array_length(_candidates); _i++) {
                var _base = _candidates[_i]
                while (string_length(_base) > 1 && string_char_at(_base, string_length(_base)) == "/") {
                    _base = string_copy(_base, 1, string_length(_base) - 1)
                }
                try {
                    if (directory_exists(_base)) return _base + _pkg_dir
                } catch (_e) {}
            }
            // 一个都探不到也给出标准路径，让上层稳定降级到沙盒目录。
            return "/storage/emulated/0" + _pkg_dir
        }
        return self.get_path_in_local_appdata("\\FVM_Reborn_makk")
    }

    /// @param {String} _path 
    /// @returns {String}
    static transfer_path_to_windows = function(_path) {
        return string_replace(_path, "/", "\\")
    }

    /// @param {Real} _code 
    /// @param {String} _msg 
    static show_error = function(_code, _msg) {
        show_message_async(_msg + "code: " + string(_code))
    }

    /// @func get_mod_root()
    /// @desc 外部 Mod 根目录。Windows 保持 %LOCALAPPDATA%\FVM_Reborn_makk\mod 不变；
    ///       安卓优先用应用外部私有目录（零权限，用户可用 USB/MTP 直接投放），
    ///       该目录不可写时降级到沙盒相对路径 "mod"（用户看不到，但功能不崩）。
    /// @param {Bool} _force 重新探测一次（玩家中途才把 Mod 目录建出来时用）
    /// @returns {String}
    static get_mod_root = function(_force = false) {
        if (os_type != os_android) {
            return self.get_path_in_local_appdata("\\FVM_Reborn_makk\\mod")
        }
        if (!_force && variable_global_exists("_android_mod_root")) return global._android_mod_root
        var _root = self.get_external_files_root() + "/mod"
        var _readable = false
        var _writable = false
        try {
            // directory_create 只在保存区生效，对绝对路径可能是空操作；先尝试建，再分别验证读写。
            if (!directory_exists(_root)) directory_create(_root)
            // 读能力：能列目录（哪怕只列出玩家投放的子目录）就说明绝对路径没被沙盒拦。
            var _first = file_find_first(_root + "/*", 0)
            if (_first != "") _readable = true
            file_find_close()
            // 写能力：写探针文件，成功后立刻删掉。
            var _probe = _root + "/.probe"
            var _f = file_text_open_write(_probe)
            if (_f != -1) {
                file_text_write_string(_f, "1")
                file_text_close(_f)
                _writable = file_exists(_probe)
                if (_writable) {
                    _readable = true
                    file_delete(_probe)
                }
            }
            // 两者都失败但目录本身存在（空目录、只读挂载）：仍然按可用处理，至少能提示玩家。
            if (!_readable && directory_exists(_root)) _readable = true
        } catch (_e) {
            _readable = false
            _writable = false
        }
        global._android_mod_root_writable = _writable
        global._android_mod_root_usable = _readable
        // 拿得到就用外部私有目录；完全拿不到才降级到沙盒相对路径，保证不崩。
        global._android_mod_root = _readable ? _root : "mod"
        show_debug_message("[NativeUtil] android mod root = " + string(global._android_mod_root)
            + " (readable=" + string(_readable) + ", writable=" + string(_writable) + ")")
        return global._android_mod_root
    }

    /// @func android_mod_root_usable()
    /// @desc 安卓外部私有目录是否真的可访问（false 表示已降级到沙盒，玩家投放的文件扫不到）。
    /// @returns {Bool}
    static android_mod_root_usable = function() {
        if (os_type != os_android) return true
        self.get_mod_root()
        return variable_global_exists("_android_mod_root_usable") && global._android_mod_root_usable
    }

    /// @func mod_root_is_writable()
    /// @desc 当前 Mod 根目录能否写入（安卓外部私有目录被系统拒绝时可能只读）。
    /// @returns {Bool}
    static mod_root_is_writable = function() {
        if (os_type != os_android) return true
        self.get_mod_root()
        return variable_global_exists("_android_mod_root_writable") && global._android_mod_root_writable
    }

    /// @func mod_root_is_user_visible()
    /// @desc 当前 Mod 目录用户能否直接用文件管理器/USB 看到（安卓外部私有目录为 true）。
    /// @returns {Bool}
    static mod_root_is_user_visible = function() {
        if (os_type != os_android) return true
        return string_pos(":", self.get_mod_root()) > 0 || string_starts_with(self.get_mod_root(), "/")
    }

    /// @func get_mod_root_hint()
    /// @desc 给玩家看的目录提示文本。
    /// @returns {String}
    static get_mod_root_hint = function() {
        var _root = self.get_mod_root()
        if (self.mod_root_is_user_visible()) return _root
        return "应用私有目录（安卓请把解压后的 Mod 文件夹放到 " + self.get_external_files_root() + "/mod 后重启）"
    }

}