/// Row buckets only narrow candidates. Callers retain their own range, type,
/// health and priority rules; homing and ray-based attacks are not row queries.
/// Arrays/structs are GC-managed: this index does not own DS handles.
function combat_targets_state() {
    static state = {step: 0, enemies: {step: -1, count: -1, rows: {}, dirty: true},
        cards: {step: -1, count: -1, rows: {}, dirty: true}};
    return state;
}

function combat_targets_begin_step() {
    combat_targets_state().step++;
}

function combat_targets_invalidate(_object) {
    var _state = combat_targets_state();
    if (_object == obj_enemy_parent || object_is_ancestor(_object, obj_enemy_parent)) _state.enemies.dirty = true;
    if (_object == obj_card_parent || object_is_ancestor(_object, obj_card_parent)) _state.cards.dirty = true;
}

/// Use for direct logical row changes, including teleports/knockback. Coordinate
/// conversion also calls this before its result is assigned to grid_row.
function combat_targets_row_value(_inst, _row) {
    if (is_struct(_inst)) return _row;
    if (instance_exists(_inst) && (!variable_instance_exists(_inst, "grid_row") || _inst.grid_row != _row)) {
        combat_targets_invalidate(_inst.object_index);
    }
    return _row;
}

/// True when _inst is still a live instance of _base (or one of its children).
/// Pooled reuse is the reason object_index must be re-checked: a recycled slot
/// keeps the same instance id but its object_index is now obj_pool_holder.
function combat_targets_is_live(_inst, _base) {
    static _ok = {};
    // 调用方传进来的可能是 undefined / 结构体 / ds 句柄（字段没初始化），
    // instance_exists 对这些会直接抛错，所以先卡类型：实例 id 与对象索引都是实数。
    if (!is_real(_inst)) return false;
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

/// Drops entries which stopped being live members of _base and returns the new
/// array, or undefined when nothing changed. The common case allocates nothing:
/// a single live-only pass decides, and a second pass rebuilds only if needed.
function combat_targets_prune(_list, _base) {
    var _n = array_length(_list);
    var _dead = -1;
    for (var _i = 0; _i < _n; _i++) {
        if (!combat_targets_is_live(_list[_i], _base)) { _dead = _i; break; }
    }
    if (_dead < 0) return undefined;
    var _kept = [];
    for (var _j = 0; _j < _n; _j++) {
        if (combat_targets_is_live(_list[_j], _base)) array_push(_kept, _list[_j]);
    }
    return _kept;
}

function combat_targets_row(_object, _row) {
    var _state = combat_targets_state();
    var _cache = (_object == obj_enemy_parent) ? _state.enemies : _state.cards;
    var _count = instance_number(_object);
    if (_cache.dirty || _cache.step != _state.step || _cache.count != _count) {
        var _rows = {};
        // Keep native with-order, including across child objects. Equal-distance
        // targeting and the enemy's last-card-per-layer rule depend on it.
        with (_object) {
            var _key = string(grid_row);
            if (!variable_struct_exists(_rows, _key)) _rows[$ _key] = [];
            array_push(_rows[$ _key], id);
        }
        _cache.rows = _rows;
        _cache.count = _count;
        _cache.step = _state.step;
        _cache.dirty = false;
    }
    var _key = string(_row);
    return variable_struct_exists(_cache.rows, _key) ? _cache.rows[$ _key] : [];
}

/// Rebuilds one row bucket without dead ids. Queries call this only after they
/// actually hit a stale entry, so the common path never pays an extra pass.
/// A still-count-equal cache can hold dead ids because a pool release paired
/// with an acquire leaves instance_number() untouched.
function combat_targets_row_compact(_object, _row) {
    var _state = combat_targets_state();
    var _cache = (_object == obj_enemy_parent) ? _state.enemies : _state.cards;
    var _key = string(_row);
    if (!variable_struct_exists(_cache.rows, _key)) return;
    var _kept = combat_targets_prune(_cache.rows[$ _key], _object);
    if (!is_undefined(_kept)) _cache.rows[$ _key] = _kept;
}

/// These queries deliberately do not add an hp check: legacy cards which can
/// start their animation against dying enemies must retain that behaviour.
function combat_enemy_in_rows(_card, _first_row, _last_row, _first_col, _last_col, _type) {
    // Boolean queries need any valid target, not the first instance. Revalidate
    // the previous one live before rebuilding/scanning a row on the next frame.
    // Never `with` a stored id: after a pool release the id still resolves to a
    // recycled holder, and a fully destroyed one raises "Unable to find instance".
    // Read the fields directly once combat_targets_is_live has vetted the object.
    if (variable_instance_exists(_card, "combat_row_target")) {
        var _prev = _card.combat_row_target;
        if (combat_targets_is_live(_prev, obj_enemy_parent)
            && _prev.grid_row >= _first_row && _prev.grid_row <= _last_row
            && _prev.grid_col >= _first_col && _prev.grid_col <= _last_col
            && can_target_on(_type, _prev.target_type)) return true;
    }
    for (var _row = _first_row; _row <= _last_row; _row++) {
        var _candidates = combat_targets_row(obj_enemy_parent, _row);
        var _stale = false;
        for (var _i = 0; _i < array_length(_candidates); _i++) {
            var _e = _candidates[_i];
            if (!combat_targets_is_live(_e, obj_enemy_parent)) { _stale = true; continue; }
            if (_e.grid_row == _row && _e.grid_col >= _first_col && _e.grid_col <= _last_col
                && can_target_on(_type, _e.target_type)) {
                _card.combat_row_target = _e;
                if (_stale) combat_targets_row_compact(obj_enemy_parent, _row);
                return true;
            }
        }
        if (_stale) combat_targets_row_compact(obj_enemy_parent, _row);
    }
    _card.combat_row_target = noone;
    return false;
}

function combat_enemy_nearest_in_row(_card, _type) {
    var _row = _card.grid_row;
    var _col = _card.grid_col;
    var _last_col = global.grid_cols + 1;
    var _candidates = combat_targets_row(obj_enemy_parent, _row);
    var _best = noone;
    var _distance = 10000;
    var _stale = false;
    for (var _i = 0; _i < array_length(_candidates); _i++) {
        var _e = _candidates[_i];
        if (!combat_targets_is_live(_e, obj_enemy_parent)) { _stale = true; continue; }
        if (_e.grid_row != _row || _e.grid_col < _col || _e.grid_col > _last_col
            || !can_target_on(_type, _e.target_type)) continue;
        var _delta = _e.grid_col - _col;
        if (_delta < _distance) { _distance = _delta; _best = _e; }
    }
    // 命中死 id 才整理这一行，正常帧一次都不多扫。
    if (_stale) combat_targets_row_compact(obj_enemy_parent, _row);
    return _best;
}

function combat_enemy_find_plant(_enemy) {
    var _candidates = combat_targets_row(obj_card_parent, _enemy.grid_row);
    var _order = [noone, noone, noone, noone];
    var _ladder_hosts = [];
    if (_enemy.can_use_ladder) with (obj_ladder) array_push(_ladder_hosts, host_plant);
    var _stale = false;
    for (var _i = 0; _i < array_length(_candidates); _i++) {
        var _plant = _candidates[_i];
        if (!combat_targets_is_live(_plant, obj_card_parent)) { _stale = true; continue; }
        if (_plant.grid_row != _enemy.grid_row) continue;
        if (_enemy.mouse_id == "longyuan_gaoqiao" && _plant.plant_id != "chocolate_bread"
            && _plant.plant_id != "pineapple_explosive_bread" && _plant.plant_id != "mianbao"
            && _plant.plant_id != "lightning_baguette") continue;
        var _dx = _plant.x - _enemy.x;
        var _in_front = _enemy.attack_range > 0 ? (_dx < 0 && _dx > -_enemy.attack_range)
            : (_dx > 0 && _dx < -_enemy.attack_range);
        if (!_in_front || (_plant.feature_type == "dwarf" && !_enemy.giant_type)
            || array_contains(_ladder_hosts, _plant)) continue;
        var _priority = ds_list_find_index(global.eat_order, _plant.plant_type);
        if (_priority >= 0 && _priority < 4) _order[_priority] = _plant;
    }
    if (_stale) combat_targets_row_compact(obj_card_parent, _enemy.grid_row);
    for (var _i = 0; _i < 4; _i++) if (_order[_i] != noone) return _order[_i];
    return noone;
}
