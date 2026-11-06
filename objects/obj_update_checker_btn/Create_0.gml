// 你的本地游戏版本，注意不要带 "v" 前缀，纯数字比较更稳健
local_version = global.game_version; 

// GitHub API 地址 (请替换为你的仓库地址)
github_api_url = "https://api.github.com/repos/Spring-SG/FVM-Reborn/releases/latest";

// 用于存储HTTP请求的ID
update_request_id = -1;

// 更新询问弹窗确认后要打开的下载链接（由 Async-Dialog 事件读取）
update_url = "";

image_xscale = 0.7
image_yscale = 0.7
image_speed = 0
