/// 索敌索引（行桶）已于 2026-11-17 **整体移除**，见 MISTAKES C29。
///   桶里存的是「本 step 首次建桶那一刻」的实例 id，建桶之后同一 step 里死掉 / 被对象池
///   收走的敌人与卡片仍留在数组里；`instance_exists` 对「同帧刚销毁」的实例不可靠，
///   随后读 `id.字段` 或 `with (id)` 就被 GM 当成对象索引解析，抛
///   "Unable to find any instance for object index '<id>'"（报错行号恒为 -1，
///   看着像崩在函数入口，极易误判成参数问题）。
///   现在敌人侧与卡片侧一律 `with (对象)` 让引擎枚举活实例，从构造上不存在悬空 id。
///   调用方自己的范围 / 类型 / 血量 / 优先级规则照旧保留。
///
/// 下面三个入口是池回收、事件、卡片摆放路径上的旧调用点（共 13 处，跨 8 个文件），
/// 行桶没了以后它们没有任何事可做；改签名要连累一圈调用点，故保留为空实现。
/// 下一次同步上游若上游已删，跟着删即可。

/// 保留：`obj_battle/Create_0` 与 `obj_mod_manager/Step_1`（Begin Step）仍会调用。
function combat_targets_begin_step() {
}

/// 保留：`obj_pool` 的回收 / 真销毁 / 清池、卡片与敌人的 Create/Destroy、
/// `src_hook_function` 的生成口仍会调用。行桶移除后无需做任何事。
function combat_targets_invalidate(_object) {
}

/// 判活（宽口径，只排「销毁 / 对象索引 / 池占位」三种）：
/// 行桶与跨帧缓存里存的是「实例 id」，随时可能是刚被别的子弹打死的实例。
/// GM 会把过期 id 当对象索引解析，`with (过期 id)` 直接抛
/// "Unable to find instance for object index"（且行号报 -1，看上去像崩在函数入口）。
/// instance_exists 对对象索引恒为 true → 必须和 object_exists 一起判才排得干净
/// （写法同 precise_bbox_collision 的 bullet_sap_type_list）。
function combat_target_alive(_inst) {
    if (!instance_exists(_inst)) return false;
    if (object_exists(_inst)) return false;
    // 🔴 2026-11-16：**对象池回收后的敌人 id 依然存在**。
    //   obj_pool_release 用 instance_change(obj_pool_holder) 把死掉的老鼠换成占位对象丢到
    //   (-100000,-100000)，id 不销毁、grid_row / target_type / hp 这些变量全都留着 ——
    //   上面两条判据都会放行，于是索敌会选中「尸体」，跨帧缓存里也一直存着它，
    //   下一次对它取属性 / with 就报 "Unable to find instance for object index"。
    //   obj_ronghehuopen_ice_ctrl 早就按这个口径处理过（见其 Step_2 注释），这里统一。
    if (_inst.object_index == obj_pool_holder) return false;
    return true;
}

/// 卡片摆放 / 传送 / 击退改写 grid_row 时都会过这里（坐标换算也算「直接改行」）。
/// 行桶移除后它只是一个直接返回新行号的入口（原先的副作用是「按行失效缓存」，
/// 已无缓存可失效）。保留是为了不动 `card_created` / `hex_hooks` / `obj_cat_box`
/// 等 13 处调用点。
function combat_targets_row_value(_inst, _row) {
    return _row;
}

/// True when _inst is still a live instance of _base (or one of its children).
/// Pooled reuse is the reason object_index must be re-checked: a recycled slot
/// keeps the same instance id but its object_index is now obj_pool_holder.
function combat_targets_is_live(_inst, _base) {
    static _ok = {};
    // 调用方传进来的可能是 undefined / 结构体 / 数组 / ds 句柄（字段没初始化），
    // instance_exists 对前几类会直接抛错，所以先卡类型。
    // ⚠️ 绝对不能用 is_real() 来卡：新版运行时实例是 `ref instance`，
    // is_real(实例) 恒为 false（同 gacha_random_card 里 ds_map 句柄的坑），
    // 这会把所有活实例判死 → 行缓存被清空 → 小怪无视全部卡片、只走路不啃。
    if (is_undefined(_inst)) return false;
    if (is_struct(_inst) || is_array(_inst) || is_string(_inst) || is_bool(_inst)) return false;
    if (_inst == noone) return false;
    if (!instance_exists(_inst)) return false;
    // instance_exists(对象索引) 只要该对象还有任意实例就为真，而真正的实例 id
    // 恒 >= 100000；不排掉对象索引，下一行 _inst.object_index 会直接报错。
    if (object_exists(_inst)) return false;
    var _o = _inst.object_index;
    if (_o == _base) return true;
    var _key = string(_o) + "|" + string(_base);
    if (!variable_struct_exists(_ok, _key)) {
        _ok[$ _key] = object_is_ancestor(_o, _base);
    }
    return _ok[$ _key];
}

/// Drop-in replacement for `with (_stored_id)`: returns the id when it is still a
/// live member of _base, otherwise noone — and `with (noone)` is a no-op, so a
/// target that died earlier in the same step can never raise
/// "Unable to find instance for object index ...".
function combat_live_or_noone(_inst, _base) {
    return combat_targets_is_live(_inst, _base) ? _inst : noone;
}

/// 这些查询刻意**不加血量判定**：老卡的动画允许对着将死的敌人起手，行为必须保留。
/// 🔴 2026-11-17（同 MISTAKES C29）：敌人查询**不再读行桶**，改成引擎枚举活实例。
///   行桶是「本 step 首次建桶那一刻」的 id 快照；建桶之后同一 step 里死掉 / 被池回收的
///   敌人还留在数组里，`instance_exists` 对「同帧刚销毁」的实例并不可靠（判活仍为真），
///   紧接着的 `id.字段` 或 `with (id)` 就抛
///   "Unable to find any instance for object index '<id>'"（报错行号一律 -1，
///   看着像崩在函数入口）。跨帧缓存 combat_row_target 同理，一起删掉 ——
///   引擎枚举 `with (obj_enemy_parent)` 只会给出活实例，从构造上不存在悬空 id。
///   语义与重构前一致：多行卡按行由近到远（第一行优先），行内保持原生 with 顺序。
function combat_enemy_in_rows(_card, _first_row, _last_row, _first_col, _last_col, _type) {
    if (!instance_exists(_card)) return false;
    for (var _row = _first_row; _row <= _last_row; _row++) {
        with (obj_enemy_parent) {
            if (grid_row == _row && grid_col >= _first_col && grid_col <= _last_col
                && can_target_on(_type, target_type)) {
                return true;
            }
        }
    }
    return false;
}

/// 同行最近目标（投手类卡用）。同样直扫活实例，理由见上。
function combat_enemy_nearest_in_row(_card, _type) {
    if (!instance_exists(_card)) return noone;
    var _row = _card.grid_row;
    var _col = _card.grid_col;
    var _last_col = global.grid_cols + 1;
    var _best = noone;
    var _distance = 10000;
    with (obj_enemy_parent) {
        if (grid_row == _row && grid_col >= _col && grid_col <= _last_col
            && can_target_on(_type, target_type)) {
            var _delta = grid_col - _col;
            // 严格小于：同距离时保留原生 with 顺序（先登记的胜出），与重构前一致。
            if (_delta < _distance) {
                _distance = _delta;
                _best = id;
            }
        }
    }
    return _best;
}

/// 敌人在本行找可啃的卡（啃食状态机用）。同样直扫活实例，理由见上。
/// 定序语义必须原样保住：
///   · 只认本行、只认「身前」(`attack_range` 正负两种朝向)；
///   · `eat_order` 分四档，**同档内后登记的覆盖先登记的** → 依赖原生 `with` 顺序，
///     所以这里用一次 `with (obj_card_parent)`，与原先建桶时的顺序完全一致；
///   · 龙渊高跷鼠只啃四种指定面包；矮卡（dwarf）只能被巨鼠啃；梯子宿主不吃。
/// @func combat_plant_eat_priority(_plant_type, _plant_id)
/// @desc 这张卡在「老鼠啃食优先级」里的档位（-1 = 不会被啃）
///   常规只看 eat_order（shield / shield_outer / normal / lilypad，按 plant_type 命中）；
///   例外：**不占格但原版能被啃**的卡（蜜糖陷阱 / 仙笛马）——它们 plant_type = gridless
///   进不了 eat_order，靠事实表 card_special_flags 的 `eatable` 按 normal 档参与。
function combat_plant_eat_priority(_plant_type, _plant_id) {
    var _p = ds_list_find_index(global.eat_order, _plant_type);
    if (_p < 0 && card_has_flag(_plant_id, "eatable"))
        _p = ds_list_find_index(global.eat_order, "normal");
    return _p;
}

function combat_enemy_find_plant(_enemy) {
    if (!instance_exists(_enemy)) return noone;
    var _order = [noone, noone, noone, noone];
    var _ladder_hosts = [];
    if (_enemy.can_use_ladder) with (obj_ladder) array_push(_ladder_hosts, host_plant);
    with (obj_card_parent) {
        if (grid_row != _enemy.grid_row) continue;
        if (_enemy.mouse_id == "longyuan_gaoqiao" && plant_id != "chocolate_bread"
            && plant_id != "pineapple_explosive_bread" && plant_id != "mianbao"
            && plant_id != "lightning_baguette") continue;
        var _dx = x - _enemy.x;
        var _in_front = _enemy.attack_range > 0 ? (_dx < 0 && _dx > -_enemy.attack_range)
            : (_dx > 0 && _dx < -_enemy.attack_range);
        if (!_in_front || (feature_type == "dwarf" && !_enemy.giant_type)
            || array_contains(_ladder_hosts, id)) continue;
        var _priority = combat_plant_eat_priority(plant_type, plant_id);
        if (_priority >= 0 && _priority < 4) _order[_priority] = id;
    }
    for (var _i = 0; _i < 4; _i++) if (_order[_i] != noone) return _order[_i];
    return noone;
}

/// @func combat_enemy_body_y(_enemy)
/// @desc 敌人「身体中部」的 y 坐标。敌人精灵原点在脚底，所以按精灵高度往上抬。
///   卡片的瞄准方向、命中特效定位都取这个值，别各写一个固定偏移
///   （固定偏移在贴身 / 不同体型的老鼠身上会算歪）。
function combat_enemy_body_y(_enemy) {
    if (!instance_exists(_enemy)) return 0;
    var _h = 0;
    if (_enemy.sprite_index != -1 && _enemy.sprite_index != undefined)
        _h = sprite_get_height(_enemy.sprite_index) * abs(_enemy.image_yscale);
    if (_h <= 0) return _enemy.y - 37;                  // 拿不到精灵时退回旧口径
    return _enemy.y - clamp(_h * 0.45, 24, 90);
}
