# BOSS 随机音乐

> 设置 → 音频设置 → 第三行「BOSS 随机音乐」。
> 开关打开后，**进入精英波时从曲库里随机挑一首**，一直播到通关（BOSS 波也不换），不再固定播关卡的 `elite_music`。

---

## 1. 曲库放哪

```
%LOCALAPPDATA%\FVM_Reborn_makk\boss_music\
```

也就是 `C:\Users\<你>\AppData\Local\FVM_Reborn_makk\boss_music\`。

**只认 `.ogg`**。放 mp3/flac 进去不认，原因在下一节。

第一次打开设置页时会自动创建这个文件夹。

### 内置曲库（随游戏分发）

游戏自带 6 首，全部是**普通 `sounds` 资源**（`music` 音频组，编译进包），直接 `audio_play_sound` 播放，不依赖 `audio_create_stream` 读文件 —— 安卓上同样可靠：

| # | 资源名 | 曲目 | 大小 |
|---|---|---|---|
| 1 | `snd_boss_music_01` | 杨丞琳 - 雨爱 | 6.1 MB |
| 2 | `snd_boss_music_02` | 张芸京 - 偏爱 | 4.7 MB |
| 3 | `snd_boss_music_03` | 阿YueYue,刘兆宇 - 冬眠 | 3.9 MB |
| 4 | `snd_boss_music_04` | 未知歌手 - 七里香 | 6.7 MB |
| 5 | `snd_boss_music_05` | 雨爱(猴叫司凤版)-泡泡心 | 3.3 MB |
| 6 | `snd_boss_music_06` | 蔡健雅 - 红色高跟鞋 | 4.5 MB |

合计 **29.2 MB**（进 APK / 安装包）。新设备装上就能用，不需要往曲库里放任何东西。

**两级扫描**：`boss_music_scan()` 先扫玩家目录（`boss_music\*.ogg`，返回路径**字符串**），再追加 6 个内置 `sounds` 资源的资产索引（**数值**）；两者进同一个随机池。`boss_music_resolve()` 按条目类型分别处理：字符串 → `audio_create_stream` 建流，数值 → 直接当声音资源返回。

**要加一首内置歌**，得改三处：

1. `sounds/snd_boss_music_07/` 下放 `snd_boss_music_07.ogg` + 同名 `.yy`（照抄 `snd_boss_music_01.yy`，
   只改 `name` / `%Name` / `soundFile` / `duration` / `sampleRate`，`audioGroupId` 保持 `music`、
   `parent` 保持 `folders/声音/Battle BGM.yy`）
2. `.yyp` 的 `resources` 加一条 `{"id":{"name":"snd_boss_music_07","path":"sounds/snd_boss_music_07/snd_boss_music_07.yy",},},`
3. `scripts/boss_music/boss_music.gml` 的 `boss_music_builtin_list()` 里加 `"snd_boss_music_07"`

**为什么内置曲目不做成 IncludedFiles**：`audio_create_stream` 只吃沙盒里的真实文件；安卓上 included files 打在 APK 的 assets 里，`file_exists` 都返回 false，读不到 → 内置曲库等于没有。转成 `sounds` 资源后由音频组统一打包，任何平台都必能播，也不需要在设备上再复制一份（旧方案「首启把 ogg 复制进沙盒」因此废弃）。

**玩家目录仍然只认 `.ogg`**：桌面端 `file_find_first` 扫相对路径 `boss_music\*.ogg`，扫不到再用绝对路径兜底，建流失败就换下一首（最多试 8 首），全失败再回退关卡自带音乐。

---

## 2. 为什么只能 .ogg

GM 加载外部音频只有一个入口：

```gml
audio_create_stream(path)   // 仅支持 .ogg
```

mp3 / flac / wav 没有对应的运行时 API（`audio_create_stream` 会返回 -1）。所以曲库必须转成 ogg。

---

## 3. 怎么把网易云的歌变成 ogg

### 最省事：拖放转换

用 `tools\音频转OGG-命令行.bat`：把 mp3 / flac / wav / m4a / aac / wma / ape 直接拖到它图标上松手，
同目录生成同名 `.ogg`（重名自动加 `_2 _3`）。双击、不带文件，则转换 bat 所在目录的全部音频。
窗口会停在结果页，显示每首的耗时、体积变化和失败原因。

命令行版可以指定输出目录与质量：

```bat
powershell -ExecutionPolicy Bypass -File tools\音频转OGG.ps1 "歌.mp3" -OutDir "D:\music" -Quality 8
```

- `-Quality` 0~10，默认 6（约 192 kbps，4 分钟约 5~6 MB）；8 约 256 kbps。
- `-Overwrite` 覆盖同名文件；`-NoPause` 不等待回车（脚本调用时用）。
- 自动找 GameMaker 自带的 ffmpeg（`C:\ProgramData\GameMakerStudio2*\Cache\runtimes\*\bin\ffmpeg\windows\ffmpeg.exe`），
  找不到才回退 PATH；也可以把 `ffmpeg.exe` 直接放在脚本旁边。
- 转换时固定带 `-vn`（丢掉内嵌封面）—— 不丢的话 ogg 容器要找 theora 编码器，GM 自带的 ffmpeg 没编进去，会直接失败。


### 步骤一：在客户端里下载

网易云音乐 → 找歌单「喜欢FVMBOSS曲库」→ 全选 → 下载。
你这台机器下载目录设的是 `D:\CloudMusic`（目前是空的）。

### 步骤二：一键转码

项目根目录跑：

```powershell
# 先看会转什么（不写文件）
& "C:\Users\18203\.dsh\dsh-runtimes\dsh-plugin-desktop-primary-runtime\dependencies\python\python.exe" tools\boss_music_import.py "D:\CloudMusic"

# 确认无误，真转
& "C:\Users\18203\.dsh\dsh-runtimes\dsh-plugin-desktop-primary-runtime\dependencies\python\python.exe" tools\boss_music_import.py "D:\CloudMusic" --apply
```

脚本会自动：

- 递归扫源目录里所有 `.mp3 / .flac / .m4a / .wav / .aac / .wma / .ape`
- 从 GameMaker runtime 里找自带的 `ffmpeg.exe`（不用你另装）
- 转成 `libvorbis` ogg（默认 `-q:a 6` ≈ 128 kbps），输出到曲库目录
- 重名自动加 `_2`、`_3`

音质想更好就加 `--quality 8`（文件大约翻倍）。

### VIP 歌下成 `.ncm` 怎么办（重要）

网易云默认把 VIP/付费曲目下载成 **`.ncm` 加密格式**，放在 `VipSongsDownload` 子目录。
这类文件**不能**直接转，也不能直接被播放器读。

本项目实测：`tools/ncm_decrypt.py` 能正确解出文件头（`CTENFDAM`）、RC4 key（AES 解出后前 17 字节为 `neteasecloudmusic`）与封面图边界，但解出的音频段没有 MP3 帧结构 —— 说明这批 VIP 文件的音频层与公开的 ncmdump 格式不同，**本地解不开**。

**但可以绕过去**：直接从公开音乐 API 取原始音频，不需要 ncm。

```powershell
# 只看会抓什么
& "C:\Users\18203\.dsh\dsh-runtimes\dsh-plugin-desktop-primary-runtime\dependencies\python\python.exe" tools\fetch_vip_songs.py

# 真抓 + 转码
& "C:\Users\18203\.dsh\dsh-runtimes\dsh-plugin-desktop-primary-runtime\dependencies\python\python.exe" tools\fetch_vip_songs.py --apply
```

脚本读 `D:\CloudMusic\VipSongsDownload` 里 `.ncm` 的**文件名**当歌名（`歌手 - 歌名`），
去 GD Studio 音乐 API 搜同款、拿 320kbps 直链、下载、再用 ffmpeg 转成 ogg 放进曲库。
文件名不需要和曲库里一致，脚本会自动跳过已存在的。

> `--br 192` 可以省流量；偶尔遇到 503，重跑一次即可（脚本对每首会重试 3 次）。

网易云那边如果还想自己下，就在 **设置 → 下载设置 → 下载格式** 选 **MP3**（不要选「高品质/无损」），重新下载出来就是明文。

### 如果歌还在网易云的 `.uc` 缓存里

`%LOCALAPPDATA%\Netease\CloudMusic\Cache\Cache\*.uc` 是另一套加密缓存，同样不能直接转。

---

## 4. 实际行为

| 情况 | 结果 |
|---|---|
| 开关关 | 全程播关卡自带音乐（`pre_music` → `elite_music` → `boss_music`），与改动前完全一致 |
| 开关开 + 曲库有歌 | **进入精英波时**随机抽一首，一直播到通关（BOSS 波也不换）；同一场只抽一次 |
| 开关开 + 玩家曲库为空 | 只用内置 6 首，仍能随机 |
| 开关开 + 安卓 | 沙盒目录不扫（玩家也塞不进去），池子就是内置 6 首；内置走 `sounds` 资源，必能播 |
| 开关开 + 内置也缺失 | 静默回退关卡自带的 `elite_music`，不报错、不弹窗 |
| 开关开 + 玩家曲目损坏 | `file_exists` 判否 / 建流抛异常 → 自动换下一首（最多试 8 首），全失败再回退 |
| 没有精英段的关卡 | `elite_wave` 为 0（魔塔系），退化为「从最后一波开始」 |
| BOSS 波 | **不单独换音乐**，继续播精英波抽到的那首，直到通关 |

随机范围包含刚播过的那首（不记忆历史），连续两场撞歌是正常的。

**音量跟随**：玩家曲目是 `audio_create_stream` 建的流，属于 `audiogroup_default`，不吃 `music` 组的
`audio_group_set_gain`。所以 `obj_battle_music_controller/Step_0.gml` 用 `boss_music_is_stream()`
判断后对流单独套一次 `global.music_volume`，拖音乐音量条、点静音按钮都实时生效。

内置 6 首是 `sounds` 资源，本身就在 `music` 组里，走组音量 —— 安卓上全靠这条，不需要单独套，
避免二次衰减。

### 开关长什么样

用的是 `obj_setting_toggle` —— 和「游戏设置」页里抽卡版 / 欧皇版 / 随机礼盒 / 海克斯那四个勾选**完全同一个控件**
（`spr_option_setting_toggle`，64×64，5 帧开合动画，点击有回弹）。

位置在音频设置页第三行：`[✓] BOSS 随机音乐 ............ N 首`。
悬停会提示曲库路径。

勾选状态写进 `config.ini` 的 `[settings] boss_music_random`，退出重进、切页回来都保持勾选。

### 为什么第一版没生效（已修）

两个独立问题：

1. **开关被建到了「画面设置」页**：`draw_audio_page()` 才是音频页，第一版误写进 `draw_settings_page()`，
   所以音频页只看得到标签、看不见勾选框。
2. **文件访问用了绝对路径**：`file_find_first` / `audio_create_stream` 在 GM 沙盒模式下只认
   相对游戏存档目录的路径，喂 `C:\Users\...\boss_music\*.ogg` 会扫到 0 个文件 →
   `boss_music_resolve()` 一直返回 fallback → 听起来"开了没反应"。
3. **勾选状态没回填**：`obj_setting_toggle` 的 `Create` 事件比 `config_key` 赋值更早执行，
   它内部 `if (config_key == "boss_music_random") state = global.boss_music_random` 永远命中不到 →
   每次进音频页开关都是关闭的。现在 `draw_audio_page()` 创建后手动补一行
   `_boss_tog.state = global.boss_music_random`（其它页的开关本来就是这么写的）。

现在 `boss_music_scan()` 先用 `boss_music\*.ogg` 相对路径扫，扫不到再用绝对路径兜底；
`audio_create_stream` 加载失败也会换绝对路径重试一次。

### 安卓端踩的两个坑（已修）

1. **`audio_create_stream` 找不到文件时抛的是致命异常，不是返回 -1**：安卓上扫到沙盒里那份名字对不上的
   ogg（早期「首启复制进沙盒」方案留下的）→ `boss_music_resolve` 直接崩，弹
   `ERROR in action number 1 ... audio_create_stream: could not find file 'boss_music\...ogg'`，
   整场战斗中断。
   现在所有建流都走 `boss_music_try_stream()`：先 `file_exists`，再 `try { audio_create_stream() } catch (_e) { -1 }`，
   坏歌只是被跳过。
2. **安卓沙盒玩家根本塞不进歌**，扫它没有意义。`boss_music_scan()` 在 `os_type == os_android` 时
   **只返回内置 6 首**，并且首次调用会用 `boss_music_android_cleanup_legacy()` 静默删掉旧方案留下的
   `boss_music\*.ogg`（那 50 MB 在这个方案下已无用）。`boss_music_ensure_dir()` 在安卓也不再建目录。

---

## 5. 实现位置

| 文件 | 作用 |
|---|---|
| `scripts/boss_music/boss_music.gml` | 扫描曲库、随机选取、流的生命周期管理 |
| `scripts/boss_music/boss_music.yy` | 资源描述 |
| `sounds/snd_boss_music_01 … _06` | 内置 6 首（`music` 音频组，共 29.2 MB） |
| `objects/obj_battle/Step_2.gml`（精英波分支） | 精英波起 `new_battle_music = boss_music_resolve(global.level_data.elite_music)`，`music_picked` 保证每场只抽一次 |
| `objects/obj_battle_music_controller/Other_5.gml` | 房间结束时销毁本次创建的流 |
| `boss_music_is_stream()`（同脚本） | 判断某索引是不是本模块建的流（决定要不要单独套音量） |
| `objects/obj_game_init/Create_0.gml:187` | 从 `config.ini` 读 `boss_music_random` |
| `objects/obj_setting_toggle/Create_0.gml` | 开关初始状态 |
| `objects/obj_setting_toggle/Mouse_4.gml` | 点击后写 `global.boss_music_random` + 落 ini |
| `objects/obj_config_menu/Step_0.gml:78-81` | 音频页创建开关（y+61 第三行） |
| `objects/obj_config_menu/Draw_0.gml` | 「BOSS 随机音乐」标签 + 曲库曲目数 |
| `tools/boss_music_import.py` | 本地音乐 → ogg 转码工具 |
| `tools/fetch_vip_songs.py` | 从公开音乐 API 抓 VIP 曲目 → ogg（绕过 ncm） |
| `tools/ncm_decrypt.py` | ncm 结构解析（备用；本地解不开 VIP 曲目，注释里有卡点分析） |

### 为什么流不在切歌那一刻销毁

`obj_battle_music_controller` 的 `Other_10` 逻辑是：

```gml
audio_stop_sound(battle_music)   // 旧 id
battle_music = new_battle_music
audio_play_sound(battle_music, 0, true)
```

如果 `boss_music_resolve()` 在返回新流之前就把旧流 `audio_destroy_stream` 了，
上面第一行会拿一个已销毁的索引去 `audio_stop_sound` → 报「索引不映射到音频资产」。

所以流只在 `Other_5`（Room End）统一回收，一场战斗最多累积 1~2 个，内存可忽略。

---

## 6. 退回

**只关功能**：设置里把开关关掉即可，代码照常跑。

**完全移除**：

```powershell
Copy-Item '.workbuddy\backup\boss_music_20261108\*' -Destination . -Force   # 不推荐，路径是打平的
```

更干净的方式：

```powershell
git checkout -- objects/obj_game_init/Create_0.gml objects/obj_setting_toggle objects/obj_config_menu objects/obj_battle/Step_2.gml objects/obj_battle_music_controller FVM_Reborn_makk.yyp
Remove-Item 'scripts\boss_music' -Recurse -Force
Remove-Item 'sounds\snd_boss_music_*' -Recurse -Force
```

备份在 `.workbuddy\backup\boss_music_20261108\`（文件名带路径前缀，形如 `objects_obj_battle_Step_2.gml`）。
