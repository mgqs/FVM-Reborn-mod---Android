// CleanUp 与 Destroy 都会跑到这里（instance_destroy → Destroy 当帧执行，CleanUp 收尾再执行一次），
// 所以必须判存在 + 置 -1，否则同一个 surface 会被 free 两次（第二次可能释放到别人复用的 surface）。
if (variable_instance_exists(id, "card_surface") && surface_exists(card_surface)) {
	surface_free(card_surface)
	card_surface = -1
}
