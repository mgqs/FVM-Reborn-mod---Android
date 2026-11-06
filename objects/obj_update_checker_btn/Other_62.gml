var event_id = async_load[? "id"];
var status = async_load[? "http_status"]; // HTTP状态码，如200
var gms_stat = async_load[? "status"]; //GM状态码
var result = async_load[? "result"]; // 返回的内容（JSON字符串）

// 检查是否是我们的更新请求
if (event_id == update_request_id) {
	
    if (gms_stat == 0 && (string_length(result) > 0)) {
        // 解析 JSON
        // GMS2 2.3+ 使用 json_parse 返回一个 struct
        var json_data = json_parse(result);
		
		if json_data == -1{
			show_notice("网络连接失败，错误码：" + string(status),60)
			exit
		}
		
		if !struct_exists(json_data,"tag_name"){
			show_notice("网络连接失败，错误码：" + string(status),60)
			exit
		}
        
        if (json_data != undefined) {
            // 获取 tag_name (例如 "v1.0.1")
            var remote_tag = json_data.tag_name;
            
            // 去掉可能存在的 "v" 前缀，以便统一比较
            var remote_version = string_replace_all(remote_tag, "v", "");
            var html_url = json_data.html_url; // 获取Release页面链接
            
            //show_debug_message("本地版本: " + local_version);
            //show_debug_message("最新版本: " + remote_version);
            
            // 使用我们编写的脚本比对
            if (version_greater(remote_version, local_version)) {
                var msg = "发现新版本: " + remote_tag + "\n当前版本: v" + local_version + 
                          "\n\n是否前往下载页面？";
                
                // Android 等平台改用异步弹窗，结果在 Async-Dialog 事件中处理
                update_url = html_url;
                show_question_async(msg);
            } else {
                show_notice("当前已是最新版本。",60);
                // 可选：显示一个小提示
                // show_message_async("当前已是最新版本。");
            }
        } else {
            //show_debug_message("JSON解析失败，请检查API返回格式。");
        }
        
    } else {
		show_notice("网络连接失败，错误码：" + string(status),60)
        //show_debug_message("更新检查失败，HTTP状态码: " + string(status));
        // 如果是404，可能是仓库地址错了或者没有Release
    }
}
