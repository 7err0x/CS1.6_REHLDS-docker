# E-BOT configuration (Biohazard profile)

This repo ships **[E-BOT 1.10](https://github.com/EfeDursun125/CS-EBOT)** on the **`cs16-biohazard`** image only (Metamod plugin). Upstream defaults live in **`addons/ebot/ebot.cfg`** inside the image; **this repo overrides them** via [`ebot-biohazard.cfg`](ebot-biohazard.cfg), executed from [`../config/server-biohazard.cfg`](../config/server-biohazard.cfg).

After editing any file here, rebuild and recreate:

```bash
docker compose build cs16-biohazard
docker compose --profile biohazard up -d --force-recreate cs16-biohazard
```

The **`cs16-biohazard`** image builds **`ebot.so`** from the git submodule at [`ebot/`](../../ebot/) (not the upstream release binary). Config assets (`ebot.cfg`, waypoint tools, etc.) still come from the [E-BOT 1.10 release zip](https://github.com/EfeDursun125/CS-EBOT). The submodule is linked with **`-static-libstdc++`** so it loads under HLDS’s older `libstdc++`.

Smoke-test: **`./docker/test-ebot.sh`**.

| File | Role |
|------|------|
| [`ebot-biohazard.cfg`](ebot-biohazard.cfg) | Production overrides for Biohazard |
| [`ebot-waypoints-bake.cfg`](ebot-waypoints-bake.cfg) | Overrides for the waypoint-bake profile |
| [`names.cfg`](names.cfg) | Bot name pool (one name per line) |
| [`bh_ebot_schedule-bake.cfg`](bh_ebot_schedule-bake.cfg) | Disables dynamic quota during bake |

Dynamic bot count at runtime: **`bio_ebot_schedule.amxx`** + [`bh_ebot_schedule.cfg`](../../image/zombiemod/extra-assets/addons/amxmodx/configs/bh_ebot_schedule.cfg) (documented in the main [README](../../README.md#dynamic-bot-quota-schedule)).

---

## `ebot-biohazard.cfg` — repo overrides

| Cvar | Value (repo) | Notes |
|------|--------------|-------|
| `ebot_quota` | `0` | Static bot count when schedule plugin is off; schedule plugin overrides when enabled |
| `ebot_keep_slots` | `2` | Human slot reserve |
| `ebot_zp_delay_custom` | `10.0` | Match **`bh_starttime`** in `bh_cvars.cfg` |
| `ebot_difficulty` | `4` | Maximum preset skill (`0` easiest → `4` hardest) |
| `ebot_min_skill` | `100` | Floor when `ebot_difficulty -1` (random per bot) |
| `ebot_max_skill` | `100` | Ceiling when `ebot_difficulty -1` |
| `ebot_zombie_wall_hack` | `1` | Zombie bots sense humans through walls |
| `ebot_dark_mode` | `1` | Human bots use dark-map awareness (pairs with dark `zm_*` maps) |
| `ebot_kill_breakables` | `1` | Bots may attack breakables (lasermines, glass, etc.) |
| `ebot_breakable_health_limit` | `10000.0` | Max HP of a breakable bots will try to destroy |
| `ebot_analyze_auto_start` | `1` | Auto waypoint analyzer on unwaypointed maps (CPU-heavy; pre-bake for production) |
| `ebot_name_tag` | `0` | Plain bot names |
| `ebot_fake_ping` | `0` | Scoreboard ping display |
| `ebot_use_flares` | `1` | Human bots use flares in dark areas (**customflashlight**) |
| `ebot_zombie_count_as_path_cost` | `1` | Humans path around zombie clusters |
| `ebot_use_pathfinding_for_avoid` | `1` | Full A\* flee logic for humans |

---

## All E-BOT server cvars (1.10)

Read-only or informational cvars are marked **(RO)**. Values are **upstream defaults** unless noted in [`ebot-biohazard.cfg`](ebot-biohazard.cfg).

### Population & teams

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_version` | *(RO)* | E-BOT build string reported at load (e.g. `1.10`). |
| `ebot_quota` | `10` | Total E-BOT players on the server (`0`–`32`). **`0`** = no bots; plugin still loads. |
| `ebot_keep_slots` | `1` | Slots reserved for humans (`ebot_quota` + humans + `keep_slots` ≤ `maxplayers`). |
| `ebot_force_team` | `any` | Force new bots onto `ct`, `t`, or `any`. |
| `ebot_stop_bots` | `0` | `1` = freeze all bot AI (pause without kicking). |

### Skill & difficulty

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_difficulty` | `4` | Global skill preset: **`0`** (easiest) → **`4`** (hardest). **`-1`** = random per bot using min/max skill. |
| `ebot_min_skill` | `1` | Minimum per-bot skill (`1`–`100`) when `ebot_difficulty -1`. |
| `ebot_max_skill` | `100` | Maximum per-bot skill (`1`–`100`) when `ebot_difficulty -1`. |

### Names, scoreboard & access

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_name_tag` | `2` | `0` = plain names; `1` = `[E-BOT]` prefix; `2` = prefix + skill in name. |
| `ebot_display_avatar` | `0` | `1` = assign Steam avatars from [`avatars.cfg`](avatars.cfg) (in image). |
| `ebot_fake_ping` | `0` | Non-zero = show plausible ping on scoreboard instead of `0`. |
| `ebot_password_key` | `ebot_pass` | Client `setinfo` key for menu access (`setinfo ebot_pass "…"`). |
| `ebot_password` | `ebot` | Server password for E-BOT menu / waypoint editor commands. **Change on public servers.** |

### Combat & awareness

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_use_grenade_percent` | `60` | Chance human bots throw HE / flash / smoke when AI chooses to. Zombies do not throw. |
| `ebot_force_flashlight` | `0` | `1` = bots always use flashlight when allowed. |
| `ebot_use_flares` | `1` | Human bots deploy flares in dark areas when enemies may be nearby; avoids revealing position while enemies are visible. |
| `ebot_check_enemy_rendering` | `0` | `1` = verify enemy is rendered/visible (invisibility / custom render mods). |
| `ebot_check_enemy_invincibility` | `0` | `1` = skip targets with godmode / invulnerability. |
| `ebot_aim_trace_consider_glass` | `0` | `1` = line-of-sight traces treat glass as solid. |
| `ebot_ignore_enemies` | `0` | `1` = bots do not attack enemies (training / debug). |
| `ebot_zombie_wall_hack` | `0` | `1` = zombie bots can sense humans through walls (large maps / horde modes). |
| `ebot_dark_mode` | `0` | `1` = human bots use full dark-map awareness. Auto-enables if `zp_lightning` is `"a"`. |
| `ebot_zp_delay_custom` | `0.0` | Seconds after round start before bots attack (infection grace). Match Biohazard **`bh_starttime`**. E-BOT also reads **`bh_starttime`**. |

### Breakables & environment

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_kill_breakables` | `0` | `1` = bots actively destroy breakables (`func_breakable`, custom entities, enemy lasermines). Undocumented in upstream `ebot.cfg`; present in 1.10 binary. |
| `ebot_breakable_health_limit` | `3000.0` | Max breakable HP bots will melee/shoot. Ignored when `ebot_kill_breakables 0`. Teammates may assist destroying breakables. |
| `ebot_has_semiclip` | `0` | `1` = pathfinding accounts for semiclip (bots avoid overlapping teammates). |

### Pathfinding & movement

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_zombie_count_as_path_cost` | `1` | `1` = nearby zombies increase path cost so humans route around hordes. `0` = lower CPU. |
| `ebot_use_pathfinding_for_avoid` | `1` | `1` = full A\* flee from zombies; `0` = simpler/cheaper avoid. |
| `ebot_force_shortest_path` | `0` | `1` = faster A\* (shorter paths, weaker AI). Forced `1` if waypoint count > 2048. |
| `ebot_pathfinder_seed_min` | `0.9` | Lower bound for randomizing path costs (variety in routes). |
| `ebot_pathfinder_seed_max` | `1.1` | Upper bound for randomizing path costs. |
| `ebot_disable_path_matrix` | `0` | `1` = disable precomputed path matrix (less RAM, more CPU, weaker AI). |
| `ebot_helicopter_width` | `54.0` | Helicopter landing zone width for helicopter waypoints; tune with `ebot_debug 1`. |
| `ebot_running_on_xash` | `0` | `1` = Xash3D engine compatibility fixes. Leave `0` on ReHLDS/GoldSrc. |

### Waypoint analyzer & download

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_analyze_auto_start` | `1` | `1` = auto-generate waypoints when a map has none (like CZ nav mesh). CPU-heavy on large maps. |
| `ebot_analyze_starter_waypoints` | `1` | `1` = analyzer picks a start waypoint automatically; `0` = you must place one manually. |
| `ebot_analyze_grid_distance` | `40` | Analyzer grid step (units). Higher = sparser waypoints; `128` pairs with post-processing. |
| `ebot_analyze_max_jump_height` | `62` | Max jump height used by analyzer (`65` = engine max at default gravity). |
| `ebot_analyze_post_processing` | `0` | `1` = light cleanup; `2` = more cleanup on auto-generated graphs. Best with `ebot_analyze_grid_distance 128`. |
| `ebot_auto_human_camp_points` | `1` | `1` = add human camp waypoints when missing (mostly on auto-generated graphs). |
| `ebot_download_waypoints` | `0` | `1` = fetch waypoints when map has none. |
| `ebot_download_waypoints_from` | `""` | Base URL or path for waypoint download. |
| `ebot_download_waypoints_format` | `ewp` | File extension for downloaded waypoints. |
| `ebot_analyze_create_goal_waypoints` | *(undocumented)* | Present in 1.10 binary; analyzer option for goal waypoints. |
| `ebot_analyze_distance` | *(undocumented)* | Present in 1.10 binary; analyzer distance parameter (related to `ebot_analyze_grid_distance`). |

### Waypoint editor display

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_show_waypoints` | `0` | `1` = draw waypoints in-game without kicking bots (view-only). |
| `ebot_waypoint_size` | `7` | Rendered waypoint marker size. |
| `ebot_waypoint_r` | `0` | Default waypoint color — red (`0`–`255`). |
| `ebot_waypoint_g` | `255` | Default waypoint color — green. |
| `ebot_waypoint_b` | `0` | Default waypoint color — blue. |

### Debug & internal

| Cvar | Default | Description |
|------|---------|-------------|
| `ebot_debug` | `0` | `1` = verbose bot debug output (goals, paths, helicopter tuning). |
| `ebot_entity_check` | *(undocumented)* | Present in 1.10 binary; custom entity interaction checks. |

---

## Console commands (summary)

Waypoint editing requires `setinfo <ebot_password_key> <ebot_password>` on the client, then binds such as `ebot wp menu`, `ebot wp on` / `off`. Bot management: `ebot_add`, `ebot_add_ct`, `ebot_add_t`, `ebot kickall`, `ebot killbots`, etc. See upstream [CS-EBOT](https://github.com/EfeDursun125/CS-EBOT) and the [E-BOT blog](https://ebots-for-cs.blogspot.com/).

---

## Interaction with Biohazard

- **Grenades:** Human bots can throw (`ebot_use_grenade_percent`). Infected bots do not grenade.
- **Lasermines:** Bots do not place mines; with **`ebot_kill_breakables 1`** they can destroy enemy mines up to **`ebot_breakable_health_limit`**.
- **Flares / darkness:** **`ebot_dark_mode 1`** + **`ebot_use_flares 1`** pair with **customflashlight** and dark `zm_*` maps.
- **Zombie pressure:** **`ebot_zombie_wall_hack 1`** makes zombie bots hunt humans aggressively on large maps.

Pre-baked waypoints: [`data/cs16-ebot-waypoints/`](../../data/cs16-ebot-waypoints/) — see main [README § E-BOT](../../README.md#e-bot-zombie-mod-bots).
