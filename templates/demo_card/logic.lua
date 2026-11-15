-- 安卓没有 Lua 后端（FvmNativeSupport.dll 只有 Windows 版），
-- 这个文件在安卓会被忽略：卡片照常注册，Lua 回调不执行。
-- 留在这里是为了这个包在 Windows 上也能用。

function on_create(ctx)
    return {}
end

function on_step(ctx)
    return {}
end
