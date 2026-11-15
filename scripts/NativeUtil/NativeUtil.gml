/// 

function NativeUtil() constructor {

    /// Portable form for parsing paths; use file_path before filesystem I/O.
    static normalize_path = function(_path) {
        return string_replace_all(string(_path), "\\", "/")
    }

    /// Windows GML sandbox checks require canonical backslashes in absolute paths.
    static file_path = function(_path) {
        if (os_type == os_windows) return string_replace_all(string(_path), "/", "\\")
        return self.normalize_path(_path)
    }

    /// Join trusted components and normalize the complete filesystem path.
    static join_path = function(_root, _child) {
        var _joined = self.normalize_path(_root)
        if (_joined != "" && !string_ends_with(_joined, "/")) _joined += "/"
        return self.file_path(_joined + string(_child))
    }

    /// @param {String} _path 
    /// @returns {String}
    static get_path_in_local_appdata = function(_path) {
        var _relative = self.normalize_path(_path)
        while (string_starts_with(_relative, "/")) {
            _relative = string_delete(_relative, 1, 1)
        }
        if (os_type == os_windows) {
            return self.join_path(environment_get_variable("LOCALAPPDATA"), _relative)
        }

        // Native operations must use the same location as relative GML save paths.
        var _root = "FVM_Reborn_makk"
        if (_relative == _root || string_starts_with(_relative, _root + "/")) {
            var _save_dir = self.normalize_path(game_save_id)
            if (!string_ends_with(_save_dir, "/")) _save_dir += "/"
            return _save_dir + string_delete(_relative, 1, string_length(_root) + 1)
        }
        // Legacy save migration still needs access to the old game's sibling directory.
        var _base = environment_get_variable("HOME") + "/Library/Application Support/"
        return _base + _relative
    }

    /// @param {String} _rel GML 沙盒相对路径
    /// @returns {String} native 可用的绝对路径
    static to_native_absolute = function(_rel) {
        _rel = self.normalize_path(_rel)
        if (string_starts_with(_rel, "/") || (string_length(_rel) >= 2 && string_char_at(_rel, 2) == ":")) {
            return self.file_path(_rel)
        }
        return self.get_path_in_local_appdata("FVM_Reborn_makk/" + _rel)
    }

    /// @func get_android_package()
    /// @desc 安卓包名，必须与 options/android/options_android.yy 的
    ///       package_domain + "." + package_company + "." + package_product 完全一致。
    /// @returns {String}
    static get_android_package = function() {
        return "com.company.game"
    }

    /// @func android_storage_base()
    /// @desc 安卓用户存储根，取第一个真实存在的挂载点（不带尾斜杠）。
    /// @returns {String}
    static android_storage_base = function() {
        var _candidates = []
        var _env = environment_get_variable("EXTERNAL_STORAGE")
        if (is_string(_env) && _env != "") array_push(_candidates, _env)
        array_push(_candidates, "/storage/emulated/0")
        array_push(_candidates, "/sdcard")
        array_push(_candidates, "/storage/self/primary")
        for (var _i = 0; _i < array_length(_candidates); _i++) {
            var _base = string_replace_all(_candidates[_i], "\\", "/")
            while (string_length(_base) > 1 && string_char_at(_base, string_length(_base)) == "/") {
                _base = string_copy(_base, 1, string_length(_base) - 1)
            }
            try {
                if (directory_exists(_base)) return _base
            } catch (_e) {}
        }
        // 一个都探不到也给出标准路径，让上层稳定降级到沙盒目录。
        return "/storage/emulated/0"
    }

    /// @func android_mkdirs(_dir)
    /// @desc 逐级建目录。directory_create 一次只能建一级，而 Android/media/<包名>/files
    ///       这些中间层往往不存在，直接建末级会失败。
    /// @returns {Bool} 末级目录最终是否存在
    static android_mkdirs = function(_dir) {
        var _path = string_replace_all(string(_dir), "\\", "/")
        if (directory_exists(_path)) return true
        // 拆段重建：从根（"/"）开始逐段拼，遇到缺的就建。
        var _parts = string_split(_path, "/")
        var _built = string_starts_with(_path, "/") ? "/" : ""
        for (var _i = 0; _i < array_length(_parts); _i++) {
            var _seg = _parts[_i]
            if (_seg == "") continue
            if (_built != "" && !string_ends_with(_built, "/")) _built += "/"
            _built += _seg
            if (!directory_exists(_built)) {
                try { directory_create(_built) } catch (_e) {}
            }
        }
        return directory_exists(_path)
    }

    /// @func android_last_segment(_path)
    /// @desc 取路径最后一段（分隔符 / 与 \ 都认）。
    ///       **安卓/iOS 的 file_find_* 返回的是完整路径，不是名字**，而 Windows 只返回名字，
    ///       所以拿条目当路径用之前必须先过这一层，不能直接 目录 + "/" + 条目。
    /// @returns {String}
    static android_last_segment = function(_path) {
        if (!is_string(_path) || _path == "") return ""
        var _p = string_replace_all(_path, "\\", "/")
        while (string_length(_p) > 1 && string_copy(_p, string_length(_p), 1) == "/") {
            _p = string_copy(_p, 1, string_length(_p) - 1)
        }
        var _cut = 0
        for (var _i = string_length(_p); _i >= 1; _i--) {
            if (string_char_at(_p, _i) == "/") { _cut = _i; break }
        }
        if (_cut == 0) return _p
        return string_copy(_p, _cut + 1, string_length(_p) - _cut)
    }

    /// @func android_list_dir(_dir, _dirs_only)
    /// @desc 目录枚举的唯一入口：返回 [{name, path, is_dir}]。
    ///       name = 最后一段（可直接当包名用），path = 可直接读的绝对/拼接路径。
    ///       掩码跑两遍再按名字去重：fa_directory 在非 Windows 无效（列不出东西），
    ///       而 Windows 的掩码 0 只带普通文件，单跑任一遍都会漏一侧。
    /// @returns {Array<Struct>}
    static android_list_dir = function(_dir, _dirs_only = false) {
        var _out = []
        if (!is_string(_dir) || _dir == "") return _out
        var _base = string_replace_all(_dir, "\\", "/")
        while (string_length(_base) > 1 && string_copy(_base, string_length(_base), 1) == "/") {
            _base = string_copy(_base, 1, string_length(_base) - 1)
        }
        var _seen = {}
        var _masks = [fa_directory, 0]
        for (var _m = 0; _m < array_length(_masks); _m++) {
            var _entry = ""
            try {
                _entry = file_find_first(_base + "/*", _masks[_m])
                while (_entry != "") {
                    var _absolute = string_pos("/", _entry) > 0 || string_pos("\\", _entry) > 0
                    var _name = _absolute ? self.android_last_segment(_entry) : _entry
                    var _path = _absolute ? string_replace_all(_entry, "\\", "/") : _base + "/" + _name
                    var _is_dir = false
                    try { _is_dir = directory_exists(_path) } catch (_e1) { _is_dir = false }
                    if (_name != "" && _name != "." && _name != ".." && !variable_struct_exists(_seen, _name)) {
                        if (!_dirs_only || _is_dir) {
                            _seen[$ _name] = true
                            array_push(_out, {name: _name, path: _path, is_dir: _is_dir})
                        }
                    }
                    _entry = file_find_next()
                }
            } catch (_e2) {
                // 该掩码不支持就当没跑过；下一遍继续。
            }
            try { file_find_close() } catch (_e3) {}
        }
        return _out
    }

    /// @func android_list_subdirs(_dir)
    /// @desc 只取子目录名，最常用的一层包装（加载器、Mod 管理器、递归都走它）。
    /// @returns {Array<String>}
    static android_list_subdirs = function(_dir) {
        var _names = []
        var _entries = self.android_list_dir(_dir, true)
        for (var _i = 0; _i < array_length(_entries); _i++) array_push(_names, _entries[_i].name)
        return _names
    }

    /// @func android_write_nomedia(_dir, _depth)
    /// @desc 在目录（及往下 _depth 层子目录）写空 .nomedia，让 MediaProvider 不再入库。
    ///       只影响媒体扫描，不影响 GML 读文件：sprite_add 照读。
    ///       枚举走 android_list_subdirs（安卓 file_find_* 返回完整路径，自己拼必错）。
    /// @returns {Real} 写入或已存在的标记数
    static android_write_nomedia = function(_dir, _depth = 2) {
        if (os_type != os_android) return 0
        if (!is_string(_dir) || _dir == "") return 0
        var _path = string_replace_all(_dir, "\\", "/")
        var _tail = self.android_last_segment(_path)
        if (_tail == "" || _tail == "mod") return 0
        try { if (!directory_exists(_path)) return 0 } catch (_e) { return 0 }
        var _written = 0
        try {
            var _marker = _path + "/.nomedia"
            if (!file_exists(_marker)) {
                var _handle = file_text_open_write(_marker)
                if (_handle != -1) {
                    file_text_write_string(_handle, "")
                    file_text_close(_handle)
                }
            }
            if (file_exists(_marker)) _written++
        } catch (_e2) {}
        if (_depth <= 0) return _written
        var _names = self.android_list_subdirs(_path)
        for (var _i = 0; _i < array_length(_names); _i++) {
            if (string_copy(_names[_i], 1, 1) == ".") continue
            _written += self.android_write_nomedia(_path + "/" + _names[_i], _depth - 1)
        }
        return _written
    }

    /// @func android_dir_usable(_dir)
    /// @desc 目录能否真的用：先逐级建出来，再列一次，最后写探针文件（写失败只记录，不影响判定）。
    ///       返回 true 表示目录存在且能被 GML 看到 —— 只看 directory_exists 不够，
    ///       分区存储下不存在的绝对路径 directory_exists 也可能返回 true。
    /// @returns {Bool}
    static android_dir_usable = function(_dir) {
        var _readable = false
        var _writable = false
        try {
            self.android_mkdirs(_dir)
            var _f = file_find_first(_dir + "/*", 0)
            if (_f != "") _readable = true
            file_find_close()
            if (!_readable && directory_exists(_dir)) _readable = true
            var _probe = _dir + "/.probe"
            var _handle = file_text_open_write(_probe)
            if (_handle != -1) {
                file_text_write_string(_handle, "1")
                file_text_close(_handle)
                _writable = file_exists(_probe)
                if (_writable) file_delete(_probe)
            }
        } catch (_e) {
            return false
        }
        global._android_last_dir_writable = _writable
        return _readable
    }

    /// @func android_dir_readable(_dir)
    /// @desc 只在「目录已存在」的前提下判断能否读到，**不建目录**。
    ///       用于旧落点回退探测：没装过 Mod 的机器不该被凭空建出 /Android/data/<包名>/files/mod。
    /// @returns {Bool}
    static android_dir_readable = function(_dir) {
        try {
            if (!directory_exists(_dir)) return false
            if (array_length(self.android_list_dir(_dir, false)) > 0) return true
        } catch (_e) {
            return false
        }
        // 空目录也算存在（目录本身能被我看到）。
        try { return directory_exists(_dir) } catch (_e) { return false }
    }

    /// @func android_dir_entry_count(_dir)
    /// @desc 目录下第一层条目数（用来判断新目录是不是空壳）。走 android_list_dir，
    ///       安卓上 file_find_* 返回完整路径也不会数错。
    /// @returns {Real}
    static android_dir_entry_count = function(_dir) {
        try {
            return array_length(self.android_list_dir(_dir, false))
        } catch (_e) {
            return 0
        }
    }

    /// @func android_legacy_files_root()
    /// @desc 旧落点 Android/data/<包名>/files。Android 11+ 文件管理器看不到，但 adb 仍能投放，
    ///       老安装上的 Mod 也在这里，保留一路回退避免升级后 Mod「消失」。
    /// @returns {String}
    static android_legacy_files_root = function() {
        return self.android_storage_base() + "/Android/data/" + self.get_android_package() + "/files"
    }

    /// @func android_copy_tree(_src, _dst)
    /// @desc 纯 GML 递归复制目录（安卓没有 shutil / cp，也没有 Windows 的 7z DLL）。
    ///       复制成功返回 true，任一环节失败返回 false 并由调用方决定是否回滚。
    ///       **枚举必须一次性收进数组**：file_find_* 只有一个全局迭代器，
    ///       边枚举边递归会让外层的 file_find_next 走到内层的列表上，结果漏文件。
    /// @returns {Bool}
    static android_copy_tree = function(_src, _dst) {
        try {
            if (!directory_exists(_src)) return false
            if (!self.android_mkdirs(_dst)) return false
            var _entries = self.android_list_dir(_src, false)
            for (var _i = 0; _i < array_length(_entries); _i++) {
                var _from = _entries[_i].path
                var _to = _dst + "/" + _entries[_i].name
                if (_entries[_i].is_dir) {
                    if (!self.android_copy_tree(_from, _to)) return false
                } else {
                    // 先用内置 file_copy（全平台可用）；它没有返回值，用 file_exists 复核。
                    try { file_copy(_from, _to) } catch (_e1) {}
                    if (!file_exists(_to)) {
                        // 失败再退回 buffer 整块搬：buffer_load 读全部字节，buffer_save 原样写回。
                        // 不要用 file_bin_* 逐字节循环（大 PNG 会慢到卡住主循环），
                        // 也不要用 buffer_read(…, buffer_binary) —— 没有这个数据类型常量。
                        var _buf = -1
                        try {
                            _buf = buffer_load(_from)
                            if (_buf == -1) return false
                            buffer_save(_buf, _to)
                            buffer_delete(_buf)
                        } catch (_copy_error) {
                            if (_buf != -1) try { buffer_delete(_buf) } catch (_e3) {}
                            return false
                        }
                        if (!file_exists(_to)) return false
                    }
                }
            }
            return true
        } catch (_e) {
            try { file_find_close() } catch (_e2) {}
            return false
        }
    }

    /// @func android_migrate_legacy_mods()
    /// @desc 把旧落点 Android/data/<包名>/files/mod 里已有的 Mod 复制到新落点
    ///       Android/media/<包名>/files/mod，只在「新目录为空、旧目录有货」时执行。
    ///       旧目录里的原包**不删**（万一复制不完整还能手动救），也不需要额外的标记文件：
    ///       复制成功后新目录就不空了，下次启动自然不会重复搬。
    /// @returns {Real} 成功搬过去的条目数
    static android_migrate_legacy_mods = function() {
        if (os_type != os_android) return 0
        var _primary = self.android_storage_base() + "/Android/media/" + self.get_android_package() + "/files/mod"
        var _legacy = self.android_legacy_files_root() + "/mod"
        if (!self.android_dir_readable(_legacy)) return 0
        var _legacy_count = self.android_dir_entry_count(_legacy)
        if (_legacy_count <= 0) return 0
        // 新目录已有包就不搬（可能是玩家自己放的更新版本，覆盖会丢数据）。
        if (self.android_dir_readable(_primary) && self.android_dir_entry_count(_primary) > 0) return 0
        if (!self.android_mkdirs(_primary)) return 0
        var _moved = 0
        var _entries = self.android_list_dir(_legacy, false)
        for (var _i = 0; _i < array_length(_entries); _i++) {
            var _name = _entries[_i].name
            var _from = _entries[_i].path
            var _to = _primary + "/" + _name
            if (directory_exists(_to) || file_exists(_to)) continue
            if (_entries[_i].is_dir) {
                if (self.android_copy_tree(_from, _to)) _moved++
            } else {
                // file_copy 没有返回值，只能 copy 完再看目标在不在。
                try { file_copy(_from, _to) } catch (_e) {}
                if (file_exists(_to)) _moved++
            }
        }
        show_debug_message("[NativeUtil] 已从旧目录迁移 " + string(_moved) + " 个 Mod 到 " + _primary)
        return _moved
    }

    /// @func get_external_files_root()
    /// @desc 应用外部私有目录。安卓优先 Android/media/<包名>/files —— 免权限，且文件管理器/MTP
    ///       能直接看到（系统只屏蔽 /Android/data）；该目录建不出来时回退旧路径 Android/data/<包名>/files。
    ///       桌面端返回 %LOCALAPPDATA%\FVM_Reborn_makk（与旧行为一致）。
    /// @returns {String}
    static get_external_files_root = function() {
        if (os_type == os_android) {
            var _media = self.android_storage_base() + "/Android/media/" + self.get_android_package() + "/files"
            if (self.android_dir_usable(_media)) return _media
            return self.android_legacy_files_root()
        }
        return self.get_path_in_local_appdata("\\FVM_Reborn_makk")
    }

    /// @param {String} _path 
    /// @returns {String}
    static transfer_path_to_windows = function(_path) {
        // Kept for existing callers; return a path valid on the current platform.
        return self.file_path(_path)
    }

    /// @param {Real} _code 
    /// @param {String} _msg 
    static show_error = function(_code, _msg) {
        show_message_async(_msg + "code: " + string(_code))
    }

    /// @func get_mod_root()
    /// @desc 外部 Mod 根目录。Windows 保持 %LOCALAPPDATA%\FVM_Reborn_makk\mod 不变；
    ///       安卓优选 Android/media/<包名>/files/mod（免权限 + 文件管理器可见）。
    ///       新目录为空而旧目录 Android/data/<包名>/files/mod 有货时，先调
    ///       android_migrate_legacy_mods() 把旧包复制进新目录（老安装的 Mod 不能因升级凭空消失），
    ///       复制失败才继续用旧目录；两处都拿不到才降级到沙盒相对路径 "mod"（用户看不到，但功能不崩）。
    /// @param {Bool} _force 重新探测一次（玩家中途才把 Mod 目录建出来时用）
    /// @returns {String}
    static get_mod_root = function(_force = false) {
        if (os_type != os_android) {
            return self.get_path_in_local_appdata("\\FVM_Reborn_makk\\mod")
        }
        if (!_force && variable_global_exists("_android_mod_root")) return global._android_mod_root

        var _primary = self.android_storage_base() + "/Android/media/" + self.get_android_package() + "/files/mod"
        var _legacy = self.android_legacy_files_root() + "/mod"

        // 老安装升级上来时，旧目录里的 Mod 自动复制到新落点，让工程之后只认一个目录。
        // 只在「新目录空 + 旧目录有货」时触发；复制失败也不影响后续探测（下面还有旧目录回退）。
        global._android_mod_migrated = self.android_migrate_legacy_mods()

        // 首选目录：建出来 + 列一次 + 写探针（这是玩家要投放的地方，必须保证可写）。
        var _primary_ok = self.android_dir_usable(_primary)
        var _primary_writable = variable_global_exists("_android_last_dir_writable") && global._android_last_dir_writable
        var _primary_count = _primary_ok ? self.android_dir_entry_count(_primary) : 0

        // 旧落点只「看」不「建」：没装过 Mod 的机器不该被凭空造出 /Android/data/<包名>/files/mod。
        // 但它必须每次都数一遍——两处都有包时要能在界面上告诉玩家「旧目录里还有几个没加载」，
        // 否则老 Mod 会在新目录出现第一个包之后静默消失。
        var _legacy_ok = self.android_dir_readable(_legacy)
        var _legacy_count = _legacy_ok ? self.android_dir_entry_count(_legacy) : 0
        var _legacy_writable = false

        var _root = ""
        var _readable = false
        var _writable = false
        var _source = ""
        if (_primary_count > 0) {
            // 新目录里已经有包：以它为准，玩家的投放目标就是它。
            _root = _primary; _readable = true; _writable = _primary_writable; _source = "media"
        } else if (_legacy_count > 0) {
            // 新目录空但旧目录有货：老 Mod 继续能用，升级后不断档。
            // 只有真的选中旧目录时才去写探针（这是唯一会碰旧目录写入的路径）。
            self.android_dir_usable(_legacy)
            _legacy_writable = variable_global_exists("_android_last_dir_writable") && global._android_last_dir_writable
            _root = _legacy; _readable = true; _writable = _legacy_writable; _source = "data(legacy)"
        } else if (_primary_ok) {
            _root = _primary; _readable = true; _writable = _primary_writable; _source = "media(empty)"
        } else if (_legacy_ok) {
            // 只有在首选目录彻底不可用时才会走到这里；此时才允许探测旧目录可写性。
            _root = _legacy; _readable = true; _source = "data(legacy,empty)"
            self.android_dir_usable(_legacy)
            _writable = variable_global_exists("_android_last_dir_writable") && global._android_last_dir_writable
        }

        global._android_mod_root_writable = _writable
        global._android_mod_root_usable = _readable
        global._android_mod_root_primary = _primary
        global._android_mod_root_legacy = _legacy
        global._android_mod_root_legacy_count = _legacy_count
        global._android_mod_root_primary_count = _primary_count

        // 相册降噪第一层：给 files 根、首选目录与各包目录写 .nomedia（每会话一次）。
        // 交给 android_write_nomedia 的深度 2：files/*、files/mod/*、mod/<包>/*。
        // 真正的保障在 external_mod_path 那层的隐藏资产目录（见 external_mod_hide_assets），
        // 这里只是顺手压掉其它散落文件的索引。
        if (!variable_global_exists("_android_nomedia_done")) {
            var _files_root = self.android_storage_base() + "/Android/media/" + self.get_android_package() + "/files"
            var _marks = self.android_write_nomedia(_files_root, 2)
            if (_root != "" && string_pos("/", _root) > 0) _marks += self.android_write_nomedia(_root, 2)
            global._android_nomedia_count = _marks
            if (_marks > 0) global._android_nomedia_done = true
            try { show_debug_message("[NativeUtil] .nomedia=" + string(_marks)) } catch (_e0) {}
        }
        // 拿得到就用外部目录；完全拿不到才降级到沙盒相对路径，保证不崩。
        global._android_mod_root = _readable ? _root : "mod"
        show_debug_message("[NativeUtil] android mod root = " + string(global._android_mod_root)
            + " (source=" + _source + ", readable=" + string(_readable) + ", writable=" + string(_writable)
            + ", primary_count=" + string(_primary_count) + ", legacy_count=" + string(_legacy_count)
            + ", migrated=" + string(global._android_mod_migrated) + ")")
        // 两处都有包时点名提醒：新目录优先生效，旧目录里的包不会自动加载。
        // 但如果本次已经把旧目录的包复制过来了，就只剩「旧包还在占空间」这一条，不再提示未加载。
        if (_primary_count > 0 && _legacy_count > 0 && global._android_mod_migrated <= 0) {
            show_debug_message("[NativeUtil] 旧目录仍有 " + string(_legacy_count) + " 个 Mod 未加载（新目录优先）：" + _legacy)
        }
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
    /// @desc 当前 Mod 目录用户能否直接用文件管理器/USB 看到。
    ///       Android/media/<包名>/files 可见；Android/data/<包名>/files 在 Android 11+ 被系统屏蔽，
    ///       只能 adb push / MTP 投放，所以这里要把两者区分开，不能只看「是不是绝对路径」。
    /// @returns {Bool}
    static mod_root_is_user_visible = function() {
        if (os_type != os_android) return true
        var _root = self.get_mod_root()
        if (_root == "mod") return false
        // string_pos 找不到时返回 0，所以 >0 才是「命中旧落点」。
        return string_pos("/Android/data/", _root) <= 0
    }

    /// @func get_mod_root_legacy_hint()
    /// @desc 旧落点（Android/data/<包名>/files/mod）的完整路径，用于「你的 Mod 还在旧目录里」这类提示。
    ///       安卓 11+ 文件管理器看不到这条路径，所以提示里要同时给出新目录，别让玩家白找。
    /// @returns {String}
    static get_mod_root_legacy_hint = function() {
        if (os_type != os_android) return self.get_mod_root()
        if (variable_global_exists("_android_mod_root_legacy") && global._android_mod_root_legacy != "") {
            return global._android_mod_root_legacy
        }
        return self.android_legacy_files_root() + "/mod"
    }

    /// @func get_mod_root_hint()
    /// @desc 给玩家看的目录提示文本（单行版；多行版见 get_mod_root_hint_lines）。
    /// @returns {String}
    static get_mod_root_hint = function() {
        var _root = self.get_mod_root()
        if (self.mod_root_is_user_visible()) return _root
        if (os_type == os_android && _root != "mod") {
            return "Mod 目录（部分文件管理器看不到，建议用 adb 投放）：" + _root
        }
        return "应用私有目录（安卓请把解压后的 Mod 文件夹放到 " + self.get_external_files_root() + "/mod 后重启）"
    }

    /// @func get_mod_root_hint_lines()
    /// @desc 给玩家看的完整投放说明（多行数组）：当前生效目录 + 推荐投放位置 + 旧目录残留提醒。
    ///       界面上逐行 draw_text 即可，不要在这里做折行。
    /// @returns {Array<String>}
    static get_mod_root_hint_lines = function() {
        var _root = self.get_mod_root()
        if (os_type != os_android) return ["Mod 目录：" + _root]
        var _primary = variable_global_exists("_android_mod_root_primary")
            ? global._android_mod_root_primary
            : self.android_storage_base() + "/Android/media/" + self.get_android_package() + "/files/mod"
        var _lines = ["当前生效目录：" + _root]
        if (_root == _primary) {
            array_push(_lines, "（新位置，文件管理器/MTP 能直接看到）")
        } else if (_root == "mod") {
            array_push(_lines, "外部目录不可用，已降级到游戏内部存档，请用 adb 投放")
        } else {
            array_push(_lines, "（旧位置，部分文件管理器看不到，可能要用 adb 投放）")
        }
        array_push(_lines, "推荐投放位置：" + _primary)
        // 旧目录还有残留时点名说明，避免玩家以为 Mod 丢了、或者以为要手动搬。
        if (_root == _primary && variable_global_exists("_android_mod_root_legacy_count")
            && global._android_mod_root_legacy_count > 0) {
            var _migrated = variable_global_exists("_android_mod_migrated") ? global._android_mod_migrated : 0
            if (_migrated > 0) {
                array_push(_lines, "旧目录里的 " + string(_migrated) + " 个 Mod 已复制到新位置（原包可手动删除）")
            } else {
                array_push(_lines, "注意：旧目录还有 " + string(global._android_mod_root_legacy_count)
                    + " 个 Mod 未复制过来，需要时请手动搬进上面的目录")
            }
        }
        return _lines
    }

}
