// 移动端虚拟按键（左下角：Esc 全局 / Shift 对局内 / 缓释对局内）
persistent = true;

// 按钮尺寸与间距（GUI 像素）
btn_size = 96;
btn_gap = 12;
btn_margin = 24;

// 模拟按键脉冲计时（用于维持一帧按下状态后释放）
esc_pulse = 0;
shift_pulse = 0;

// 按下视觉反馈计时
esc_flash = 0;
shift_flash = 0;
slow_flash = 0;

// 缓释按钮：开启后「点卡槽但还没放下」期间把帧率压到 30，放下 / 取消后还原
slow_active = false;   // 本实例当前是否正把帧率压在 30（只有自己压的才自己还原）
slow_prev_fps = 0;     // 压帧前记录的真实帧率，还原时按它回去（不硬写 60）
