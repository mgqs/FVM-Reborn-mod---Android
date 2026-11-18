image_speed = 0;
// 安卓：顺转活动入口图标放大到 96×96（2026-11-18 用户口径）
//   sprite 只有 56×47，触屏上偏难点中；这里按轴各自缩放铺满 96×96，
//   Mouse_4 的点击判定走 bbox（sprite_width/height 会跟着 image_xscale/yscale 变），
//   所以放大图标的同时点击区域一起变大，位置 (1010,32) 不变（与龙渊入口 950,56 横向不重叠）。
if (os_type == os_android) {
	image_xscale = 96 / sprite_get_width(sprite_index);
	image_yscale = 96 / sprite_get_height(sprite_index);
} else {
	image_xscale = 1;
	image_yscale = 1;
}
