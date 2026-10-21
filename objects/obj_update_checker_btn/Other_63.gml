// Async - Dialog 事件：处理更新检查的询问弹窗返回
var _type = async_load[? "type"];
if (_type == "show_question" && async_load[? "status"] == true) {
    url_open(update_url);
}