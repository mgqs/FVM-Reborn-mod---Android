global.audio.play(snd_button,0,0)
if btn_type == "cancel"{
	panel_anim_close(obj_edit_menu)
	obj_player_info_ui.menu_type = 0
}
else if btn_type == "save"{
	with obj_edit_menu{
		event_user(0)
	}
	global.save_data.player.name = global.player_name
	panel_anim_close(obj_edit_menu)
	obj_player_info_ui.menu_type = 0
}
else if btn_type == "open_save_folder"{
	if (os_type == os_android) {
		// Android：改为删除当前存档，删除后重置为开局存档
		reset_file(global.save_slot)
		global.player_name = global.save_data.player.name
		show_message_async("存档已删除")
	} else {
		directory_create("saves")
		var _target = global.native_util.get_path_in_local_appdata("\\FVM_Reborn_makk\\saves")
		var ret = native_open_folder(_target)
		if (ret != 0) {
			global.native_util.show_error(ret, "打开存档文件夹失败")
		}
	}
}
else if btn_type == "export_save_backup" {
	if (os_type == os_android) {
		// Android：将当前存档 JSON 写入剪贴板
		clipboard_set_text(json_stringify(global.save_data))
		show_message_async("存档已导出到剪贴板")
	} else {
		var _saves_target = global.native_util.get_path_in_local_appdata("\\FVM_Reborn_makk\\saves")
		var ret = native_start_backup(_saves_target)
		if (ret != 0 && ret != -3) {
			global.native_util.show_error(ret, "导出存档备份失败")
		} else {
			show_message_async("存档已导出")
		}
	}
}
else if btn_type == "import_save_backup" {
	if (os_type == os_android) {
		// Android：从剪贴板读取存档 JSON 并写入当前槽位
		var _clip = clipboard_get_text()
		if (_clip == "") {
			show_message_async("剪贴板为空，导入失败")
		} else {
			try {
				var _data = json_parse(_clip)
				if (!is_struct(_data) || !variable_struct_exists(_data, "player")) {
					show_message_async("剪贴板内容不是有效存档")
				} else {
					global.save_data = _data
					save_file(global.save_slot)
					load_file(global.save_slot)
					show_message_async("导入存档成功")
				}
			} catch (_e) {
				show_message_async("导入存档失败：内容无效")
			}
		}
	} else {
		var _saves_target = global.native_util.get_path_in_local_appdata("\\FVM_Reborn_makk\\saves")
		var _backup_target = global.native_util.get_path_in_local_appdata("\\FVM_Reborn_makk\\backups")
		var ret = native_restore_backup(_saves_target, _backup_target)
		if (ret != 0 && ret != -3) {
			global.native_util.show_error(ret, "导入存档备份失败")
		} else {
			load_file(global.save_slot)
			show_message_async("导入存档成功")
		}
	}
}