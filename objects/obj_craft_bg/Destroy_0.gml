instance_destroy(obj_closecraft_btn)
instance_destroy(obj_craft_select_btn)
instance_destroy(obj_craft_confirm_btn)
obj_player_info_ui.menu_type = 0
obj_world_map_button.world_map = 0
// card_surface 可能还没建（Create 里是 -1，Draw_76 / Draw 才创建），
// 而且 CleanUp 还会再跑一次释放 —— 这里判存在并置 -1，避免双重 surface_free。
if (surface_exists(card_surface)) {
	surface_free(card_surface)
	card_surface = -1
}

panel_anim_free(id)
