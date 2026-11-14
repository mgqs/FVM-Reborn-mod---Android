if (global.is_paused)
{
    image_speed = 0;
    exit;
}

image_speed = 1;
y += move_speed;

if (y >= target_y)
{
    if (combat_targets_is_live(target_instance, obj_enemy_parent))
    {
        hitted_enemy = target_instance;
        with (combat_live_or_noone(target_instance, obj_enemy_parent))
        {
            audio_play_sound(snd_ice_god, 0, 0);
            damage_amount = other.damage;
            damage_type = other.damage_type;
            event_user(0);

            if (ice_timer <= 600)
                ice_timer = 600;

            hit_enemy = true;
        }
    }

    instance_destroy();
}
