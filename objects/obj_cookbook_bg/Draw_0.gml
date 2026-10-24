panel_anim_step(id)
if (!instance_exists(id)) { exit }
draw_set_alpha(0.5 * ui_anim_alpha(id));
// 绘制半透明遮罩
draw_rectangle_color(0, 0, room_width, room_height, c_black, c_black, c_black, c_black, false);
draw_set_alpha(1);
panel_anim_begin(id)
draw_self()
// 双指滑动：遍历所有触点索引（Android 触点索引不保证 0/1 连续）
var _two_n = 0
var _two_y1 = 0, _two_y2 = 0, _two_x1 = 0, _two_x2 = 0
for (var _d = 0; _d < 10; _d++) {
	if (!device_mouse_check_button(_d, mb_left)) continue
	_two_n++
	if (_two_n == 1) { _two_x1 = device_mouse_x(_d); _two_y1 = device_mouse_y(_d) }
	else if (_two_n == 2) { _two_x2 = device_mouse_x(_d); _two_y2 = device_mouse_y(_d) }
}
if (_two_n >= 2) {
	var _two_mx = (_two_x1 + _two_x2) * 0.5
	var _two_my = (_two_y1 + _two_y2) * 0.5
	if (point_in_rectangle(_two_mx, _two_my, x - 700, y - 500, x + 700, y + 500)) {
		if (two_touch_scroll_active) y_offset = clamp(y_offset - (_two_my - two_touch_scroll_y) / 101, 0, max(0, array_length(current_cookbook_list) - 6))
		two_touch_scroll_y = _two_my
		two_touch_scroll_active = true
	} else two_touch_scroll_active = false
} else two_touch_scroll_active = false

if button_select < 0{
	draw_set_font(font_yuan)
	draw_set_colour(c_black)
	draw_set_halign(fa_left)
	draw_set_valign(fa_middle)
	draw_text(x+230,y-260,"未选择食谱类型")
	draw_text(x+240,y-163,"点击左侧选项卡以选择食谱类型")
	draw_text(x+230,y+33,"未选择食谱类型")
	draw_text(x+240,y+128,"点击左侧选项卡以选择食谱类型")
	}
else{
	var cookbook_rank_list = global.save_data.equipped_cookbook[button_select]
	var cookbook_material = ["copper_cookbook_fragment","silver_cookbook_fragment","gold_cookbook_fragment"]
	var max_cookbook_slot = clamp(get_material_amount(cookbook_material[button_select]),0,2)
	draw_set_font(font_yuan)
	draw_set_colour(c_black)
	draw_set_halign(fa_left)
	draw_set_valign(fa_middle)
	if max_cookbook_slot <= 0{
		draw_text(x+230,y-260,"食谱槽位未解锁")
		var cm_data = get_material_info(cookbook_material[button_select])
		draw_text(x+240,y-163,$"获取1个{cm_data.name}以解锁此槽位")
	}
	else{
		if array_length(cookbook_rank_list) >= 1{
			var cdata = get_cookbook_data(cookbook_rank_list[0])
			draw_text(x+230,y-285,cdata.title)
			draw_text(x+230,y-235,cdata.tiny_desc)
			draw_set_valign(fa_top)
			draw_text(x+230,y-176,cdata.desc)
			draw_sprite_ext(spr_cookbook_icon,cdata.icon,x+150,y-260,1.8,1.8,0,c_white,1)
		}
		else{
			draw_text(x+230,y-260,"未装配食谱")
			draw_text(x+240,y-163,"在左侧食谱列表中装配食谱")
		}
	}
	if max_cookbook_slot <= 1{
		draw_text(x+230,y+33,"食谱槽位未解锁")
		var cm_data = get_material_info(cookbook_material[button_select])
		draw_text(x+240,y+128,$"获取2个{cm_data.name}以解锁此槽位")
	}
	else{
		if array_length(cookbook_rank_list) >= 2{
			var cdata = get_cookbook_data(cookbook_rank_list[1])
			draw_set_valign(fa_middle)
			draw_text(x+230,y+8,cdata.title)
			draw_text(x+230,y+58,cdata.tiny_desc)
			draw_set_valign(fa_top)
			draw_text(x+230,y+115,cdata.desc)
			draw_sprite_ext(spr_cookbook_icon,cdata.icon,x+150,y+33,1.8,1.8,0,c_white,1)
		}
		else{
			draw_set_valign(fa_middle)
			draw_text(x+230,y+33,"未装配食谱")
			draw_text(x+240,y+128,"在左侧食谱列表中装配食谱")
		}
	}
}
panel_anim_end_slide(id, 260)
