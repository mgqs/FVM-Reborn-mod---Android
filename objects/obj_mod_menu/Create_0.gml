mod_root = global.native_util.get_mod_root();
// Android/media/<包名>/files 这层中间目录往往不存在，directory_create 一次只能建一级，
// 所以统一走逐级创建；降级到沙盒相对路径 "mod" 时也照样能建出来。
if (!directory_exists(mod_root)) global.native_util.android_mkdirs(mod_root);
state_path = external_mod_state_path();
scroll_offset = 0;
row_height = 58;
list_top = y - 192;
list_bottom = y + 205;
mods = [];
status_text = "";
import_close_when_done = false;
if (is_struct(global.external_mod_import_job) && !instance_exists(global.external_mod_import_job.owner)) {
    global.external_mod_import_job.owner = id;
}
notify_result = function(message) {
    status_text = message;
    // 安卓上 show_message 是模态阻塞，会卡住主循环，必须用 async 版。
    show_message_async(message);
};
return_depth = depth + 10;
close_panel = function() {
    if (instance_exists(obj_player_info_ui)) obj_player_info_ui.menu_type = 2;
    var settings = instance_create_depth(x, y, return_depth, obj_config_menu);
    settings.button_select = 3;
    instance_destroy();
};
dragging_scroll = false;
drag_scroll_offset = 0;

state_read_failed = false;
state_default_enabled = true;
load_state = function() {
    var state = external_mod_state_load(state_path);
    state_read_failed = !state.safe;
    state_default_enabled = state.default_enabled;
    if (state.notice != "") status_text = state.notice;
    return state.entries;
};

save_state = function() {
    // 「不可见 / 加载失败」的占位条目绝不能写进状态文件：它们带着 enabled=false，
    // 下次启动会被当成玩家的真实选择读回来，把本来能用的 Mod 静默关掉。
    var _clean = [];
    for (var _i = 0; _i < array_length(mods); _i++) {
        if (variable_struct_exists(mods[_i], "missing") && mods[_i].missing) continue;
        if (variable_struct_exists(mods[_i], "failed") && mods[_i].failed) continue;
        array_push(_clean, { folder: mods[_i].folder, enabled: mods[_i].enabled });
    }
    if (external_mod_state_save(state_path, _clean)) {
        state_read_failed = false;
        state_default_enabled = true;
        global.external_mods = mods;
        return true;
    }
    status_text = "无法保存 Mod 状态，请检查目录权限";
    return false;
};

manifest_name = function(folder_path, fallback) {
    var root;
    try { root = external_mod_root(folder_path); } catch (_missing_manifest) { return fallback; }
    var p = root + "/manifest.json";
    if (!file_exists(p)) p = root + "/card.json";
    if (!file_exists(p)) return fallback;
    var raw;
    try { raw = external_mod_read(p); } catch (_read_error) { return fallback; }
    try {
        var parsed = json_parse(raw);
        if (is_struct(parsed)) {
            if (variable_struct_exists(parsed, "name")) return string(parsed.name);
            if (variable_struct_exists(parsed, "id")) return string(parsed.id);
        }
    } catch (_error) {}
    return fallback;
};

// 扫描 mod_root 下的包目录。必须先收进数组再返回：调用方随后还会做 manifest 解析，
// 而 file_find_* 只有一个全局迭代器，边遍历边解析会让列表错位。
scan_root = function(_dir, _flags) {
    var _out = [];
    var _f = file_find_first(_dir + "/*", _flags);
    while (_f != "") {
        if (_f != "." && _f != ".." && directory_exists(_dir + "/" + _f)) array_push(_out, _f);
        _f = file_find_next();
    }
    file_find_close();
    return _out;
};

scan_mod_folders = function() {
    if (!directory_exists(mod_root)) return [];
    var _folders = scan_root(mod_root, external_mod_find_flags());
    // 安卓上 flags=0 是否会把子目录带出来，取决于运行时对分区存储的实现。
    // 空结果时再按 fa_directory 试一遍，两个都空才算真的没有包 ——
    // 否则「包在里面但列表为空」会退化成一个查不出来的黑箱。
    if (array_length(_folders) == 0) {
        var _alt = scan_root(mod_root, fa_directory);
        if (array_length(_alt) > 0) _folders = _alt;
    }
    return _folders;
};

refresh_mods = function(persist_state = true) {
    if (is_struct(global.external_mod_import_job) && !global.external_mod_import_job.done) persist_state = false;
    var previous = mods;
    mods = [];
    // 安卓：启动时若新目录还是空的、或外部目录整体不可用，会落到旧目录 / 沙盒 "mod"。
    // 玩家把文件夹投放进 Android/media 之后点「刷新列表」，这里必须重新探测一次，
    // 否则会一直盯着旧落点看不到新投放的包。
    if (os_type == os_android) {
        var _preferred = variable_global_exists("_android_mod_root_primary") ? global._android_mod_root_primary : "";
        if (_preferred != "" && mod_root != _preferred) {
            global.native_util.get_mod_root(true);
            var _probe_root = global.native_util.get_mod_root();
            if (_probe_root != mod_root) {
                mod_root = _probe_root;
                state_path = external_mod_state_path();
            }
        }
    }
    var folders = scan_mod_folders();
    // 安卓上「扫描为空」有两种可能：玩家还没投放，或者 mod_root 落到了空壳目录。
    // 后者必须再探一次首选目录，否则卡片已经能生效（加载器读的是同一个 get_mod_root），
    // 界面上却一个包都列不出来——这就是「Mod 生效了但管理器里没有」的直接原因。
    if (os_type == os_android && array_length(folders) == 0) {
        global.native_util.get_mod_root(true);
        var _retry_root = global.native_util.get_mod_root();
        if (_retry_root != mod_root) {
            mod_root = _retry_root;
            state_path = external_mod_state_path();
        }
        folders = scan_mod_folders();
    }
    var folder = "";
    for (var f = 0; f < array_length(folders); f++) {
            folder = folders[f];
            // 新扫到的包默认开启（老状态文件里有记录就沿用记录的开关）。
            // 原来这里取 state_default_enabled，而它在状态文件存在时是 false ——
            // 结果就是安卓手动投放的新包一进列表就是「已关闭」，点了开启还要重启两次。
            var enabled = !state_read_failed;
            for (var j = 0; j < array_length(previous); j++) {
                if (previous[j].folder == folder) {
                    enabled = previous[j].enabled;
                    break;
                }
            }
            // 加载阶段报错的包一律显示关闭，别让玩家以为它在正常工作。
            if (variable_global_exists("external_mod_errors") && variable_struct_exists(global.external_mod_errors, folder)) enabled = false;
            array_push(mods, { folder: folder, name: manifest_name(mod_root + "/" + folder, folder), enabled: enabled });
    }
    // 以加载器的结果为准补齐：external_mod_load_all() 在 room_init 阶段就把包枚举并注册好了。
    // 只要它成功加载过，这里就必须出现在列表里 —— 这条路径直接决定「卡片已经生效、管理器里却没有」
    // 这个症状还会不会复现。加载器的 root 与界面 root 可能不同源（迁移、降级、缓存），
    // 所以名字解析失败时退回文件夹名，绝不允许因为解析失败而整行消失。
    if (variable_global_exists("external_mod_loaded")) {
        var _loaded = variable_struct_get_names(global.external_mod_loaded);
        for (var _l = 0; _l < array_length(_loaded); _l++) {
            var _lf = _loaded[_l];
            var _seen = false;
            for (var _m = 0; _m < array_length(mods); _m++) {
                if (mods[_m].folder == _lf) { _seen = true; break; }
            }
            if (_seen) continue;
            var _le = true;
            for (var _lj = 0; _lj < array_length(previous); _lj++) {
                if (previous[_lj].folder == _lf) { _le = previous[_lj].enabled; break; }
            }
            array_push(mods, {
                folder: _lf,
                name: manifest_name(mod_root + "/" + _lf, _lf),
                enabled: _le
            });
        }
    }
    if (variable_global_exists("external_mod_errors")) {
        var _bad = variable_struct_get_names(global.external_mod_errors);
        for (var _b = 0; _b < array_length(_bad); _b++) {
            var _bf = _bad[_b];
            var _seen_b = false;
            for (var _n = 0; _n < array_length(mods); _n++) {
                if (mods[_n].folder == _bf) { _seen_b = true; break; }
            }
            if (_seen_b) continue;
            // 加载失败的包也要列出来（保持关闭），否则玩家只看到「少了一个」，
            // 却不知道是校验没过；点条目能看到具体原因。
            array_push(mods, {
                folder: _bf,
                name: manifest_name(mod_root + "/" + _bf, _bf),
                enabled: false,
                failed: true
            });
        }
    }
    // 兜底：状态文件里记过、这次却没扫到。分两种，都要显示出来，因为它们在界面上
    // 和「一个 Mod 都没装」长得一模一样，玩家只会以为 Mod 没被识别：
    //   · 文件夹在旧落点（Android/data）里 → 标「在旧目录」，提示搬过来；
    //   · 文件夹在当前目录里但枚举没返回 → 标「扫描不到」，属于运行时枚举异常。
    // 磁盘上已经彻底不在的直接丢弃，不留幽灵行。
    var _legacy_root = variable_global_exists("_android_mod_root_legacy") ? global._android_mod_root_legacy : "";
    for (var _p = 0; _p < array_length(previous); _p++) {
        var _pf = previous[_p].folder;
        if (!is_string(_pf) || _pf == "") continue;
        var _seen_p = false;
        for (var _q = 0; _q < array_length(mods); _q++) {
            if (mods[_q].folder == _pf) { _seen_p = true; break; }
        }
        if (_seen_p) continue;
        var _in_root = directory_exists(mod_root + "/" + _pf);
        var _in_legacy = _legacy_root != "" && _legacy_root != mod_root && directory_exists(_legacy_root + "/" + _pf);
        if (!_in_root && !_in_legacy) continue;
        array_push(mods, {
            folder: _pf,
            name: manifest_name((_in_root ? mod_root : _legacy_root) + "/" + _pf, _pf),
            enabled: false,
            missing: true,
            legacy_only: _in_legacy && !_in_root
        });
    }
    array_sort(mods, function(a, b) {
        return a.folder == b.folder ? 0 : (a.folder < b.folder ? -1 : 1);
    });
    // 扫描结果为空时不要回写状态：那会把已有的 enabled 记录整份清空，
    // 下次启动 default_enabled 变成 false，Mod 会被静默禁用。
    if (persist_state && !state_read_failed && (array_length(mods) > 0 || array_length(previous) == 0)) save_state();
    show_debug_message("[Mod menu] root=" + mod_root + " folders=" + string(array_length(folders))
        + " listed=" + string(array_length(mods))
        + " loaded=" + string(variable_global_exists("external_mod_loaded") ? array_length(variable_struct_get_names(global.external_mod_loaded)) : 0));
    scroll_offset = clamp(scroll_offset, 0, max(0, array_length(mods) * row_height - (list_bottom - list_top)));
};

mods = load_state();
refresh_mods();
// 安卓的 Mod 目录若被系统拒绝写入，开关状态存不进 Mod 目录（状态已固定写沙盒），这里只提示不阻断。
if (os_type == os_android && !global.native_util.mod_root_is_writable()) {
    status_text = "Mod 目录只读，Mod 开关状态会存到游戏内部存档；投放 Mod 后点「刷新列表」。";
}
if (variable_global_exists("external_mod_errors")) {
    var failed_folders = variable_struct_get_names(global.external_mod_errors);
    if (array_length(failed_folders) > 0) {
        status_text = "有 Mod 加载失败，点击对应条目查看原因";
    }
}
