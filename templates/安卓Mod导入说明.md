# 安卓 Mod 导入步骤

## 0. 先说结论：安卓上 Mod 是「文件夹」，不是压缩包

游戏在安卓上没有 `get_open_filename`（桌面专属），也没法调用 Windows 的
`native_unzip_map_file`（`FvmNativeSupport.dll` 只有 Windows 版）。
所以 `obj_mod_menu` 的「导入」按钮在安卓被替换成了**「刷新列表」**
（`objects/obj_mod_menu/Step_0.gml:55-67`）：

- 安卓：`mod_root` 已经被改成 **Android/media**（`scripts/NativeUtil/NativeUtil.gml:277`）

  ```text
  /storage/emulated/0/Android/media/com.company.game/files/mod/
  ```

  这个目录**不需要存储权限，系统文件管理器能直接看见**（`Android/data` 那套被 Android 11+ 屏蔽）。

- 你要做的是：把**解压后的 Mod 文件夹**整个丢进 `mod/` 下面，让路径变成

  ```text
  /storage/emulated/0/Android/media/com.company.game/files/mod/<你的包名>/manifest.json
  ```

  也就是 `mod` 的直接子目录里必须有 `manifest.json`（或裸 `card.json`）。

包里允许有一层外目录（`external_mod_root()`，`scripts/external_mod_system/external_mod_system.gml:219-236`），
但**`mod/` 下只能有一层**，太深会报「包内需要 manifest.json 或 card.json」。

---

## 2. 包的目录结构（照抄这个就不会错）

```text
mod/
└── demo_card/                 ← 文件夹名随便起，建议和 Mod 同名
    ├── manifest.json          ← 必须有
    ├── card.json              ← 卡片定义（manifest.cards 里指向它）
    ├── logic.lua              ← 可选；安卓没 Lua 后端会自动忽略
    └── images/
        ├── icon.png           ← 卡面图标（必须存在，.png）
        ├── card_01.png        ← idle 动画帧
        └── card_02.png
```

---

## 3. 打开 / 关闭 / 删除

- Mod 管理器里每行右侧有开关，改的是**状态文件**，不删文件；
  安卓上状态文件落在应用沙盒里的 `mod_state.json`（`external_mod_state_path()`，`external_mod_system.gml:17-20`）。
- 新投放的包默认**开启**（v2.7.3 起改成 `!state_read_failed`）。
- 删掉文件夹 = 卸载该 Mod；同 ID 的卡片进度会保留在存档里，同 ID 重装后恢复。
- 改了包内容 → 回 Mod 管理器点「刷新列表」再看，**行为要生效必须重启游戏**（卡注册在 `room_init` 阶段跑完）。

---

## 4. 常见问题对照

| 现象 | 原因 | 处理 |
|---|---|---|
| 列表里完全没这个包 | 放错目录（比如还在 `Android/data/...`）或有多层嵌套 | 点 Mod 管理器顶部那行「目录：…」核对；列表里橙色行写「还在旧目录」就是放到了 `Android/data` |
| 列表里有，但写「加载失败」 | 校验没过 | 点这一行会弹出具体原因；也可本地跑 `validate_mod.py` |
| 卡片生效了但列表是空的 | 旧版本 bug（界面和加载器不同源），v2.7.3 已修 | 更新到 v2.7.3+ |
| 有卡但放下去不出子弹 | **安卓整条出弹链走不通**，见下一节 | 只能显示/放置，出弹要 Windows 端 |

