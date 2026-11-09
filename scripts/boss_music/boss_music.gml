/// boss_music —— BOSS 随机音乐
///
/// 曲库分两路（同时存在时随机一视同仁）：
///   ① 玩家自放：%LOCALAPPDATA%\FVM_Reborn_makk\boss_music\*.ogg（只认 .ogg，PC 主用）
///   ② 随包内置：sounds/snd_boss_music_01 ~ snd_boss_music_06
///      编译进 music 音频组，安卓上就是普通声音资源，不依赖 APK assets 直读 ——
///      比「拿 audio_create_stream 读 datafiles 里的 ogg」可靠得多（后者安卓取不到文件）
/// 开关：设置 → 音频设置 → 「BOSS 随机音乐」，存 config.ini 的 settings/boss_music_random
///
/// 设计要点：
///   ① 两路都为空 / 读取失败时【静默回退内置 boss_music】，不影响正常流程
///   ② 玩家曲目每场最多创建 1~2 个流（BOSS 波切歌时才建），房间结束时统一回收；
///      内置曲目是普通 sounds 资源，不建流、不额外占内存
///   ③ 不在切歌那一刻销毁旧流 —— obj_battle_music_controller 的 Other_10 还在拿旧
///      id 调 audio_stop_sound，销毁早了会报「索引不映射到音频资产」

/// 沙盒相对路径：GM 会自动映射到 %LOCALAPPDATA%\<项目名>\boss_music\
/// 用绝对路径喂 file_find_first / audio_create_stream 在沙盒模式下会失败，这是
/// 「开关打开了却没声音」的根因。
#macro kBossMusicRelDir "boss_music"

/// 绝对路径只用于「打开文件夹」这类给玩家看的场景
#macro kBossMusicFolderSuffix "\\FVM_Reborn_makk\\boss_music"

/// @func boss_music_dir()
/// @desc 曲库目录的绝对路径（不带尾反斜杠）
function boss_music_dir() {
	return global.native_util.get_path_in_local_appdata(kBossMusicFolderSuffix);
}

/// @func boss_music_ensure_dir()
/// @desc 目录不存在就建一个，方便玩家第一次进设置就能看到文件夹
function boss_music_ensure_dir() {
	// 安卓沙盒玩家进不去，建出来也是空目录，只会给扫描添乱 —— 直接跳过
	if (os_type == os_android) return kBossMusicRelDir;
	if (!directory_exists(kBossMusicRelDir)) {
		directory_create(kBossMusicRelDir);
	}
	return kBossMusicRelDir;
}

/// @func boss_music_android_cleanup_legacy()
/// @desc 旧方案（首启把内置 ogg 复制进沙盒）留下的 boss_music\*.ogg：安卓上既播不了
///       （路径/编码对不上，audio_create_stream 会抛致命错误），又白占 50 MB。
///       首次调用时静默清一次，之后不再扫这个目录。
function boss_music_android_cleanup_legacy() {
	if (variable_global_exists("boss_music_android_cleaned")) return;
	global.boss_music_android_cleaned = true;
	try {
		if (directory_exists(kBossMusicRelDir)) {
			var _f2 = file_find_first(kBossMusicRelDir + "/*.ogg", fa_readonly | fa_archive);
			while (_f2 != "") {
				file_delete(kBossMusicRelDir + "/" + _f2);
				_f2 = file_find_next();
			}
			file_find_close();
		}
	} catch (_e1) {
		// 清不掉也无所谓 —— 下面根本不扫这个目录
	}
}

/// @func boss_music_builtin_list()
/// @desc 内置曲目的 sounds 资源名清单（顺序 = 随机池顺序，与上游 boss_music_builtin_list 一致）。
///       改歌单＝改这里 + 在 sounds/ 下加同名资源并登记进 yyp
function boss_music_builtin_list() {
	// 随游戏分发的内置曲库。加歌要同时改三处：
	// 1) sounds/snd_boss_music_NN/ 放 ogg + 同名 .yy  2) .yyp 的 resources 补一条  3) 这里补一行
	return [
		"snd_boss_music_01",	// 杨丞琳 - 雨爱
		"snd_boss_music_02",	// 张芸京 - 偏爱
		"snd_boss_music_03",	// 阿YueYue,刘兆宇 - 冬眠
		"snd_boss_music_04",	// 未知歌手 - 七里香
		"snd_boss_music_05",	// 雨爱(猴叫司凤版)-泡泡心
		"snd_boss_music_06"	// 蔡健雅 - 红色高跟鞋
	];
}

/// @func boss_music_scan()
/// @desc 扫描曲库，返回条目数组：
///       string → 玩家目录里的 .ogg（要喂 audio_create_stream）
///       real   → 内置 sounds 资源的资产索引（可直接 audio_play_sound）
function boss_music_scan() {
	var _out = [];

	// 玩家目录只在桌面端扫：安卓沙盒玩家进不去，而且 file_find 拿到的中文名拼回去
	// 再喂 audio_create_stream 会抛「could not find file」致命错误（不是返回 -1）
	if (os_type == os_android) {
		boss_music_android_cleanup_legacy();
	} else {
		// ① 玩家目录：沙盒相对路径（GM 自动映射到 %LOCALAPPDATA%\<项目>\boss_music\）
		var _f = file_find_first(kBossMusicRelDir + "\\*.ogg", fa_readonly | fa_archive);
		while (_f != "") {
			array_push(_out, kBossMusicRelDir + "\\" + _f);
			_f = file_find_next();
		}
		file_find_close();

		// ② 兜底：某些运行时对相对路径不买账，用绝对路径再扫一遍
		if (array_length(_out) == 0) {
			var _abs = boss_music_dir();
			if (directory_exists(_abs)) {
				_f = file_find_first(_abs + "\\*.ogg", fa_readonly | fa_archive);
				while (_f != "") {
					array_push(_out, _abs + "\\" + _f);
					_f = file_find_next();
				}
				file_find_close();
			}
		}
	}

	// ③ 内置曲目：sounds 资源，安卓 / PC 都能直接播
	var _builtin = boss_music_builtin_list();
	var _bn = array_length(_builtin);
	for (var _bi = 0; _bi < _bn; _bi++) {
		var _snd = asset_get_index(_builtin[_bi]);
		if (_snd > -1) array_push(_out, _snd);
	}
	return _out;
}

/// @func boss_music_label(_item)
/// @desc 条目显示名（写 global.boss_music_last_path、排查用）
function boss_music_label(_item) {
	if (is_string(_item)) return filename_name(_item);
	var _names = boss_music_builtin_list();
	var _n = array_length(_names);
	for (var _i = 0; _i < _n; _i++) {
		if (asset_get_index(_names[_i]) == _item) return _names[_i];
	}
	return "(内置曲目)";
}

/// @func boss_music_count()
/// @desc 曲库曲目数。设置界面每帧都会调，所以带 3 秒缓存，避免逐帧扫目录
function boss_music_count() {
	var _now = current_time;
	if (variable_global_exists("boss_music_count_ms")
		&& _now - global.boss_music_count_ms < 3000) {
		return global.boss_music_count_cache;
	}
	var _n = array_length(boss_music_scan());
	global.boss_music_count_cache = _n;
	global.boss_music_count_ms = _now;
	return _n;
}

/// @func boss_music_track(_s)
/// @desc 登记一个已创建的流，房间结束时统一销毁
function boss_music_track(_s) {
	if (!variable_global_exists("boss_music_streams")) {
		global.boss_music_streams = [];
	}
	array_push(global.boss_music_streams, _s);
}

/// @func boss_music_is_stream(_snd)
/// @desc 判断某个 sound 索引是不是 boss_music 模块用 audio_create_stream 创建的流。
///       内置曲目是 sounds 资源（在 music 音频组里，吃 audio_group_set_gain），
///       玩家曲目是流（属于 audiogroup_default，不吃组音量，要单独套 global.music_volume）。
/// @param {Real} _snd
/// @return {Bool}
function boss_music_is_stream(_snd) {
	if (!variable_global_exists("boss_music_streams")) return false;
	var _a = global.boss_music_streams;
	for (var i = 0; i < array_length(_a); i++) {
		if (_a[i] == _snd) return true;
	}
	return false;
}

/// @func boss_music_stream_free_all()
/// @desc 停止并销毁本场战斗创建的所有流（obj_battle_music_controller 的 Room End 调用）
function boss_music_stream_free_all() {
	if (!variable_global_exists("boss_music_streams")) return;
	var _a = global.boss_music_streams;
	var _n = array_length(_a);
	for (var _i = 0; _i < _n; _i++) {
		var _s = _a[_i];
		if (_s != -1 && audio_exists(_s)) {
			if (audio_is_playing(_s)) audio_stop_sound(_s);
			audio_destroy_stream(_s);
		}
	}
	global.boss_music_streams = [];
}

/// @func boss_music_try_stream(_path)
/// @desc 安全建流：文件不存在直接返 -1；某些平台找不到文件时抛的是致命异常而不是 -1，
///       这里一并吃掉，保证一场 BOSS 战不会因为一首坏歌崩掉
function boss_music_try_stream(_path) {
	if (!file_exists(_path)) return -1;
	try {
		return audio_create_stream(_path);
	} catch (_e2) {
		return -1;
	}
}

/// @func boss_music_resolve(_fallback)
/// @desc 取一首 BOSS 音乐。开关关闭 / 曲库为空 / 加载失败时返回 _fallback。
///       返回值既可能是流索引也可能是 sounds 资源索引，audio_play_sound 都接受。
/// @param {Real} _fallback 内置 boss_music 的资产索引
/// @return {Real} 可直接交给 audio_play_sound 的声音索引
function boss_music_resolve(_fallback) {
	var _on = false;
	if (variable_global_exists("boss_music_random")) _on = global.boss_music_random;
	if (!_on) return _fallback;

	var _list = boss_music_scan();
	var _n = array_length(_list);
	if (_n == 0) return _fallback;

	// 随机起点，最多试 8 首 —— 单首损坏/路径不可达时换下一首，别整场哑掉
	var _start = irandom(_n - 1);
	var _tries = min(_n, 8);
	for (var _t = 0; _t < _tries; _t++) {
		var _item = _list[(_start + _t) mod _n];

		// 内置曲目：普通 sounds 资源，不需要建流
		if (!is_string(_item)) {
			if (_item < 0 || !audio_exists(_item)) continue;
			global.boss_music_last_path = boss_music_label(_item);
			return _item;
		}

		// 玩家曲目：建流播放（文件不存在 / 建流抛错都只是换下一首，绝不冒泡）
		var _path = _item;
		var _loaded = boss_music_try_stream(_path);

		// 兜底：相对路径失败时换绝对路径再试一次
		if (_loaded == -1) {
			var _abs2 = boss_music_dir() + "\\" + filename_name(_path);
			_loaded = boss_music_try_stream(_abs2);
			if (_loaded != -1) _path = _abs2;
		}
		if (_loaded == -1) continue;

		boss_music_track(_loaded);
		global.boss_music_last_path = _path;
		return _loaded;
	}
	return _fallback;
}
