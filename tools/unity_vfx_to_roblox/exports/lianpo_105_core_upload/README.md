# LianPo Core Upload Set

This folder contains the first batch of Unity textures worth uploading to Roblox for hero `105`.

## Selected assets
1. `Dilie_CPxs_kx_004.png`
   - ground crack / slam decal
   - use for `lianpo_ground_crack`, `lianpo_slam_explosion`, `lianpo_w_release`
2. `Circle_a_0015.tga`
   - ring pulse texture
   - use for `lianpo_ring_outer`, `lianpo_ring_mid`, `lianpo_ring_inner`
3. `glow_CPgt_zy_203.png`
   - strong glow sprite
   - use for `lianpo_charge_wave`, `lianpo_slam_explosion`
4. `Gongben_trail_GW_03.png`
   - directional streak / trail
   - use for `lianpo_charge_wave`, `lianpo_charge_dust`
5. `Glow_CPyc_fsw_011.png`
   - small burst flash
   - use for `lianpo_w_release`, `lianpo_slam_explosion`
6. `shitou_van_05.png`
   - stone debris accent
   - optional for `lianpo_slam_explosion`
7. `lianpo_Cpmj_yl_04.png`
   - warm hero-specific aura detail
   - use for `lianpo_charge_aura`, `super_armor_aura`

## Why only these
This is the minimum high-value set for a mobile-first first pass. The rest can wait until these are tested in Studio and on phone.

## Next step
Upload these 7 textures first, then fill the returned asset ids into `src/shared/VFXAssetTable.luau`.
