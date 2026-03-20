--[[
    SkillEventTable.luau
    鎶€鑳戒簨浠舵椂闂磋酱閰嶇疆琛紙鏍稿績锛侊級
    
    鉁?鎵€鏈夋妧鑳戒互鐜嬭€呰崳鑰€瀹樻柟鏁版嵁涓哄噯
    
    瀵归綈鍘熷垯锛?
    - 鍔ㄧ敾"鍑烘墜甯? = SpawnBullet.startTime
    - 鍔ㄧ敾"鎵撳嚮甯? = HitDetect.startTime
    - 鍛戒腑鐗规晥 = HitDetect.onHit 涓殑 PlayVFX
    - 鏂芥硶鐗规晥 = 涓庨€昏緫浜嬩欢鍚?startTime 鐨?PlayVFX
]]

local ET = require(script.Parent.EventTypes).Types

local SkillEventTable = {}

--============================================================
-- 鍚庣究 (169_HouYi) - 灏勬墜
--============================================================

-- Q - 澶氶噸绠煝锛堢灛鍙戣嚜韬獴uff锛屽己鍖栨櫘鏀?绉掞級
SkillEventTable.houyi_q = {
    totalDuration = 0.5,
    events = {
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "houyi_buff_cast", speed = 1.5 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "houyi_q_cast_flash", attachToSelf = true } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "multi_arrow_aura", attachToSelf = true, duration = 5 } },
        { startTime = 0.03, type = ET.ApplyBuff, params = { buffType = "AttackBuff", duration = 5, value = 1, toSelf = true, subType = "MultiArrow" } },
    },
}

-- W - 钀芥棩浣欐櫀锛堟寚瀹氫綅缃瓵OE锛氬鍦堝噺閫?0%+鍐呭湀棰濆50%浼ゅ+50%鍑忛€燂級
SkillEventTable.houyi_w = {
    totalDuration = 1.5,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.ForbidAbility, duration = 0.5, params = { forbidMove = true, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.8, params = { animId = "houyi_shoot_up", speed = 1.0 } },
        { startTime = 0.25, type = ET.PlayVFX, params = { templateId = "arrow_fire", attachToSelf = false, duration = 0.5 } },
        { startTime = 0.50, type = ET.PlayVFX, params = { templateId = "houyi_w_skyfall_trail", useTargetPosition = true, duration = 0.3 } },
        { startTime = 0.75, type = ET.PlayVFX, params = { templateId = "sunfall_outer", useTargetPosition = true, duration = 0.8 } },
        { startTime = 0.75, type = ET.PlayVFX, params = { templateId = "sunfall_inner", useTargetPosition = true, duration = 0.8 } },
        { startTime = 0.75, type = ET.CameraShake, duration = 0.3, params = { intensity = 0.3 } },
        -- 澶栧湀鍛戒腑锛氬噺閫?0%鎸佺画2绉?
        { startTime = 0.75, type = ET.HitDetect, duration = 0.3, params = {
            shape = "Sphere", radius = 3, maxTargets = 32, interval = 0, useTargetPosition = true,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 300, damageType = "Magic", adRatio = 0.50 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 2, value = 0.3 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_fire" } },
        }},
        -- 鍐呭湀鍛戒腑锛氶澶?0%浼ゅ + 50%鍑忛€?
        { startTime = 0.75, type = ET.HitDetect, duration = 0.3, params = {
            shape = "Sphere", radius = 1.5, maxTargets = 32, interval = 0,
            useTargetPosition = true, hitTag = "inner",
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 150, damageType = "Magic" } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 2, value = 0.5 } },
        }},
    },
}

-- E - 鐏兼棩涔嬬煝锛堝叏鍥炬柟鍚戝脊閬擄紝鍛戒腑棣栦釜鑻遍泟鐪╂檿0.5~3.5绉?婧呭皠鍑忛€?0%锛?
SkillEventTable.houyi_e = {
    totalDuration = 1.2,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.ForbidAbility, duration = 0.7, params = { forbidMove = true, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.PlayAnim, duration = 1.0, params = { animId = "houyi_charge_shoot", speed = 1.0 } },
        -- 鍙戝皠鐏劙绠脊閬?
        { startTime = 0.30, type = ET.SpawnBullet, params = {
            bulletId = "houyi_e_arrow", speed = 60, maxDist = 200,
            size = Vector3.new(3, 3, 3), isPiercing = false,  -- 鍛戒腑棣栦釜鑻遍泟鍚庡仠姝?
            isUltArrow = true,  -- 鏍囪涓虹伡鏃ヤ箣鐭紝鐢ㄤ簬璺濈鐪╂檿璁＄畻
        }},
        { startTime = 0.30, type = ET.PlayVFX, params = { templateId = "arrow_giant_fire", attachToBullet = true, bulletId = "houyi_e_arrow" } },
        { startTime = 0.30, type = ET.MoveBullet, duration = 5, params = { bulletId = "houyi_e_arrow", speed = 60, maxDist = 200 } },
        -- 鍛戒腑妫€娴嬶細鍛戒腑棣栦釜鑻遍泟锛屾寜椋炶璺濈璁＄畻鐪╂檿
        { startTime = 0.30, type = ET.HitDetect, duration = 5, params = {
            shape = "Box", size = Vector3.new(3, 3, 3),
            attachToBullet = true, bulletId = "houyi_e_arrow",
            maxTargets = 1, interval = 0,
            destroyBulletOnHit = true,
            -- 璺濈鐪╂檿锛氶琛岃窛绂昏秺杩滐紝鐪╂檿瓒婇暱(0.5~3.5绉?
            distanceStunMin = 0.5,
            distanceStunMax = 3.5,
            distanceStunRange = 200,  -- 鏈€澶ц绠楄窛绂?
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 700, damageType = "Physical", adRatio = 0.90 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Stun", duration = 0.5, useDistanceStun = true } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_fire" } },
            { startTime = 0, type = ET.CameraShake, duration = 0.5, params = { intensity = 0.6 } },
        }},
        -- 婧呭皠妫€娴嬶紙鍛戒腑鐐瑰懆鍥村噺閫?0%鎸佺画1绉掞級
        { startTime = 0.30, type = ET.HitDetect, duration = 5, params = {
            shape = "Sphere", radius = 4,
            useBulletStopPosition = true, bulletId = "houyi_e_arrow",
            maxTargets = 32, interval = 0,
            hitTag = "splash",
            waitForBulletStop = true,  -- 绛夊脊閬撳仠涓嬪悗鎵嶆娴?
        }, onHit = {
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 1, value = 0.9 } },
        }},
    },
}

-- R - 琚姩路鎯╂垝灏勫嚮锛堟櫘鏀诲彔鍔犳敾閫燂紝婊?灞傚皠3绠級
SkillEventTable.houyi_r = {
    totalDuration = 0,
    isPassive = true,
    passiveType = "onBasicAttackHit",
    events = {},
    onTrigger = {
        -- 鍙犲姞鏀婚€熷嵃璁帮細姣忓眰+4%鏀婚€燂紝鏈€澶?灞?
        { startTime = 0, type = ET.AddMark, params = { markId = "houyi_passive", amount = 1, duration = 3, maxStack = 3 } },
        { startTime = 0, type = ET.PlayVFX, params = { templateId = "houyi_passive_mark", attachToSelf = true, duration = 3 } },
    },
    -- 婊″眰瑙﹀彂鏁堟灉锛氳繘鍏ユ儵鎴掑皠鍑荤姸鎬侊紙3绠?30%浼ゅ锛?
    onMaxStack = {
        { startTime = 0, type = ET.ApplyBuff, params = { 
            buffType = "AttackBuff", duration = 3, value = 1, toSelf = true, 
            subType = "PunishShot", extraArrows = 2, totalDamageRatio = 1.30,
        }},
        { startTime = 0, type = ET.PlayVFX, params = { templateId = "houyi_punish_aura", attachToSelf = true, duration = 3 } },
    },
}

--============================================================
-- 寤夐 (105_LianPo) - 鍧﹀厠/鎴樺＋
-- 琚姩锛氬媷澹箣榄?鈥?鎶€鑳介噴鏀炬椂闇镐綋锛堢敱 SkillSystem 鑷姩澶勭悊锛?
--============================================================

-- Q - 鐖嗚鍐叉挒锛堟柟鍚戝啿閿?鍑婚0.5绉掞級
SkillEventTable.lianpo_q = {
    totalDuration = 1.1,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.ForbidAbility, duration = 0.6, params = { forbidMove = true, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.SuperArmor, duration = 0.6 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.6, params = { animId = "lianpo_charge", speed = 1.0 } },
        { startTime = 0.00, type = ET.MoveActor, duration = 0.4, params = { moveType = "direction", distance = 20, speed = 55 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "charge_trail", attachToSelf = true, duration = 0.4 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "lianpo_charge_dust", attachToSelf = true, duration = 0.4 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "lianpo_charge_wave", attachToSelf = true, duration = 0.4 } },
        { startTime = 0.00, type = ET.CameraShake, duration = 0.4, params = { intensity = 0.2 } },
        -- 鍐查攱鍛戒腑锛氫激瀹?鍑婚0.5绉?
        { startTime = 0.00, type = ET.HitDetect, duration = 0.4, params = {
            shape = "Box", size = Vector3.new(3.5, 10, 3),
            attachToSelf = true, maxTargets = 5, interval = 0.5,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 150, damageType = "Physical", adRatio = 0.65 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Airborne", duration = 0.5 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
    },
}

-- W - 鐔斿博閲嶅嚮锛堣幏寰楁姢鐩?+ 1绉掑悗鍦伴潰宕╄ + 鍑忛€?0% + 閲嶇疆Q鍐峰嵈锛?
SkillEventTable.lianpo_w = {
    totalDuration = 1.5,
    events = {
        { startTime = 0.00, type = ET.ForbidAbility, duration = 1.2, params = { forbidMove = false, forbidSkill = false } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.SuperArmor, duration = 1.2 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 1.2, params = { animId = "lianpo_ground_charge", speed = 1.0 } },
        -- 鑾峰緱鎶ょ浘
        { startTime = 0.00, type = ET.ApplyBuff, params = { 
            buffType = "Shield", duration = 4, value = 350, toSelf = true,
        }},
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "lianpo_charge_aura", attachToSelf = true, duration = 1.2 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "lianpo_ring_outer", attachToSelf = true, duration = 1.0 } },
        
        -- 1绉掑悗鍦伴潰宕╄锛氫激瀹筹紙涓績瓒婅繎瓒婇珮锛屾渶楂?00%锛? 鍑忛€?0%
        { startTime = 1.00, type = ET.PlayVFX, params = { templateId = "lianpo_w_release", attachToSelf = true } },
        { startTime = 1.00, type = ET.PlayVFX, params = { templateId = "lianpo_ground_crack", attachToSelf = true, duration = 1.0 } },
        { startTime = 1.00, type = ET.CameraShake, duration = 0.3, params = { intensity = 0.4 } },
        -- 澶栧湀浼ゅ
        { startTime = 1.00, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Sphere", radius = 5, attachToSelf = true, maxTargets = 32, interval = 0,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 100, damageType = "Physical", adRatio = 1.00, maxHpRatio = 0.04 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 2, value = 0.3 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
        -- 鍐呭湀棰濆浼ゅ锛堣窛绂讳腑蹇冭秺杩戣秺楂橈紝鏈€楂?100%锛?
        { startTime = 1.00, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Sphere", radius = 2.5, attachToSelf = true, maxTargets = 32, interval = 0, hitTag = "inner",
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 100, damageType = "Physical", adRatio = 1.00 } },
        }},
        -- 閲嶇疆 Q 鎶€鑳藉喎鍗达紙鏍稿績鏈哄埗锛侊級
        { startTime = 1.00, type = ET.TriggerCD, params = { cdOverride = 0, targetSkillId = "lianpo_q", resetCD = true } },
    },
}

-- E - 澶╁穿鍦拌锛堣烦璺冨埌鎸囧畾浣嶇疆 + 涓夋閿ゅ湴锛氬噺閫熲啋鍑忛€熲啋鍑婚锛?
SkillEventTable.lianpo_e = {
    totalDuration = 3.2,
    events = {
        { startTime = 0.00, type = ET.ForbidAbility, duration = 3.0, params = { forbidMove = true, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.SuperArmor, duration = 3.0 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "lianpo_jump", speed = 1.2 } },
        { startTime = 0.00, type = ET.MoveActor, duration = 0.5, params = { moveType = "toPosition", speed = 50 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "super_armor_aura", attachToSelf = true, duration = 3.0 } },
        
        -- 绗竴娈甸敜鍦?@0.75s锛氬噺閫?0%
        { startTime = 0.55, type = ET.PlayAnim, duration = 0.4, params = { animId = "lianpo_slam_1", speed = 1.0 } },
        { startTime = 0.75, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Sphere", radius = 5, attachToSelf = true, maxTargets = 32, interval = 0,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 60, damageType = "Physical", adRatio = 0.60, maxHpRatio = 0.03 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 2, value = 0.3 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
        { startTime = 0.75, type = ET.PlayVFX, params = { templateId = "lianpo_ground_crack", attachToSelf = true, duration = 1.0 } },
        { startTime = 0.75, type = ET.PlayVFX, params = { templateId = "lianpo_slam_explosion", attachToSelf = true } },
        { startTime = 0.75, type = ET.PlayVFX, params = { templateId = "lianpo_shockwave", attachToSelf = true } },
        { startTime = 0.75, type = ET.CameraShake, duration = 0.3, params = { intensity = 0.3 } },
        
        -- 绗簩娈甸敜鍦?@1.2s锛氬噺閫?0%
        { startTime = 1.00, type = ET.PlayAnim, duration = 0.4, params = { animId = "lianpo_slam_2", speed = 1.0 } },
        { startTime = 1.20, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Sphere", radius = 5, attachToSelf = true, maxTargets = 32, interval = 0,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 90, damageType = "Physical", adRatio = 0.90, maxHpRatio = 0.04 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 2, value = 0.5 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
        { startTime = 1.20, type = ET.PlayVFX, params = { templateId = "lianpo_ground_crack", attachToSelf = true, duration = 1.0, scale = 1.2 } },
        { startTime = 1.20, type = ET.PlayVFX, params = { templateId = "lianpo_slam_explosion", attachToSelf = true, scale = 1.2 } },
        { startTime = 1.20, type = ET.CameraShake, duration = 0.4, params = { intensity = 0.5 } },
        
        -- 绗笁娈甸敜鍦?@2.55s锛氬嚮椋烇紙鏈€寮猴級
        { startTime = 2.20, type = ET.PlayAnim, duration = 0.6, params = { animId = "lianpo_slam_3", speed = 0.9 } },
        { startTime = 2.55, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Sphere", radius = 5, attachToSelf = true, maxTargets = 32, interval = 0,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 120, damageType = "Physical", adRatio = 1.50, maxHpRatio = 0.06 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Airborne", duration = 1.0 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
        { startTime = 2.55, type = ET.PlayVFX, params = { templateId = "lianpo_ground_crack", attachToSelf = true, duration = 1.5, scale = 1.5 } },
        { startTime = 2.55, type = ET.PlayVFX, params = { templateId = "lianpo_slam_explosion", attachToSelf = true, scale = 1.5 } },
        { startTime = 2.55, type = ET.CameraShake, duration = 0.5, params = { intensity = 0.8 } },
        { startTime = 2.55, type = ET.PlayVFX, params = { templateId = "screen_shake_heavy" } },
    },
}

-- R - 琚姩路鍕囧＋涔嬮瓊
-- 鏈哄埗锛氶噴鏀炬妧鑳芥椂鑷姩闇镐綋锛堢敱鍚勬妧鑳戒腑鐨?SuperArmor 浜嬩欢瀹炵幇锛?
-- 杩涘叆鎴樻枟鍚庢垬鎰忔彁鍗囷紙鍑忎激鏈€楂?0%锛夛紝婊℃垬鎰忔彁鍗囨敾閫?
-- 鑴辨垬鍚庢垬鎰忛檷浣?
SkillEventTable.lianpo_r = {
    totalDuration = 0,
    isPassive = true,
    passiveType = "onCombatState",
    events = {},
    -- 鎴樻剰绯荤粺鍙傛暟
    combatParams = {
        maxZhanYi = 100,           -- 婊℃垬鎰?
        gainPerSecond = 10,        -- 鎴樻枟涓瘡绉掕幏寰?
        losePerSecond = 20,        -- 鑴辨垬姣忕涓㈠け
        maxDamageReduction = 0.20, -- 婊℃垬鎰忓噺浼?0%
        attackSpeedBonus = 0.30,   -- 婊℃垬鎰忔敾閫?30%
        healPerZhanYi = 0.005,     -- 鑴辨垬姣忔崯澶?鎴樻剰鍥炲0.5%鏈€澶х敓鍛?
    },
}

--============================================================
-- 瀹夌惇鎷?(142_Angela) - 娉曞笀
-- 琚姩锛氬拻鏈伀鐒帮紙鎶€鑳界伡鐑у彔鍔狅紝鏈€澶?0灞傦級
--============================================================

--[[
    Q - 鐏悆鏈紙鏈濇寚瀹氫綅缃噴鏀?棰楃伀鐞冿級
    鏈哄埗锛?
    - 5棰楃伀鐞冩湞鎸囧畾浣嶇疆渚濇鍙戝皠锛堥棿闅?.08s锛?
    - 姣忛鐏悆閫犳垚 270(+30%AP) 娉曟湳浼ゅ
    - 瀵瑰悓涓€鐩爣绗?棰楄捣鍙€犳垚 30% 浼ゅ
    - 鍛戒腑鏁屾柟鑻遍泟鏃跺仠姝㈢Щ鍔ㄥ苟閿€姣?
]]
SkillEventTable.angela_q = {
    totalDuration = 1.2,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.ForbidAbility, duration = 0.4, params = { forbidMove = true, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.PlayAnim, duration = 1.0, params = { animId = "angela_cast", speed = 1.0 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "angela_cast_circle", attachToSelf = true, duration = 0.8 } },

        -- 5棰楃伀鐞冩湞鎸囧畾浣嶇疆渚濇鍙戝皠
        { startTime = 0.30, type = ET.SpawnBullet, params = {
            bulletId = "angela_q_b1", speed = 45, maxDist = 15,
            size = Vector3.new(1.2, 1.2, 1.2),
            targetMode = "position", destroyOnHeroHit = true,
        }},
        { startTime = 0.38, type = ET.SpawnBullet, params = {
            bulletId = "angela_q_b2", speed = 45, maxDist = 15,
            size = Vector3.new(1.2, 1.2, 1.2),
            targetMode = "position", destroyOnHeroHit = true,
        }},
        { startTime = 0.46, type = ET.SpawnBullet, params = {
            bulletId = "angela_q_b3", speed = 45, maxDist = 15,
            size = Vector3.new(1.2, 1.2, 1.2),
            targetMode = "position", destroyOnHeroHit = true,
        }},
        { startTime = 0.54, type = ET.SpawnBullet, params = {
            bulletId = "angela_q_b4", speed = 45, maxDist = 15,
            size = Vector3.new(1.2, 1.2, 1.2),
            targetMode = "position", destroyOnHeroHit = true,
        }},
        { startTime = 0.62, type = ET.SpawnBullet, params = {
            bulletId = "angela_q_b5", speed = 45, maxDist = 15,
            size = Vector3.new(1.2, 1.2, 1.2),
            targetMode = "position", destroyOnHeroHit = true,
        }},

        -- 寮归亾椋炶
        { startTime = 0.30, type = ET.MoveBullet, duration = 1, params = { bulletId = "angela_q_b1", speed = 45, maxDist = 15 } },
        { startTime = 0.38, type = ET.MoveBullet, duration = 1, params = { bulletId = "angela_q_b2", speed = 45, maxDist = 15 } },
        { startTime = 0.46, type = ET.MoveBullet, duration = 1, params = { bulletId = "angela_q_b3", speed = 45, maxDist = 15 } },
        { startTime = 0.54, type = ET.MoveBullet, duration = 1, params = { bulletId = "angela_q_b4", speed = 45, maxDist = 15 } },
        { startTime = 0.62, type = ET.MoveBullet, duration = 1, params = { bulletId = "angela_q_b5", speed = 45, maxDist = 15 } },

        -- 鍛戒腑妫€娴嬶紙姣忛鐏悆鐙珛锛岄€掑噺鏍囪鏈哄埗锛?
        { startTime = 0.30, type = ET.HitDetect, duration = 1, params = {
            attachToBullet = true, bulletId = "angela_q_b1",
            shape = "Box", size = Vector3.new(1.2, 1.2, 1.2), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true, diminishingTag = "angela_q", diminishingRatio = 0.30,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 270, damageType = "Magic", apRatio = 0.30 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},
        { startTime = 0.38, type = ET.HitDetect, duration = 1, params = {
            attachToBullet = true, bulletId = "angela_q_b2",
            shape = "Box", size = Vector3.new(1.2, 1.2, 1.2), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true, diminishingTag = "angela_q", diminishingRatio = 0.30,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 270, damageType = "Magic", apRatio = 0.30 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},
        { startTime = 0.46, type = ET.HitDetect, duration = 1, params = {
            attachToBullet = true, bulletId = "angela_q_b3",
            shape = "Box", size = Vector3.new(1.2, 1.2, 1.2), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true, diminishingTag = "angela_q", diminishingRatio = 0.30,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 270, damageType = "Magic", apRatio = 0.30 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},
        { startTime = 0.54, type = ET.HitDetect, duration = 1, params = {
            attachToBullet = true, bulletId = "angela_q_b4",
            shape = "Box", size = Vector3.new(1.2, 1.2, 1.2), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true, diminishingTag = "angela_q", diminishingRatio = 0.30,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 270, damageType = "Magic", apRatio = 0.30 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},
        { startTime = 0.62, type = ET.HitDetect, duration = 1, params = {
            attachToBullet = true, bulletId = "angela_q_b5",
            shape = "Box", size = Vector3.new(1.2, 1.2, 1.2), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true, diminishingTag = "angela_q", diminishingRatio = 0.30,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 270, damageType = "Magic", apRatio = 0.30 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},

        -- 寮归亾鐗规晥锛堢传鑹茬伀鐞冿級
        { startTime = 0.30, type = ET.PlayVFX, params = { templateId = "fireball_purple", attachToBullet = true, bulletId = "angela_q_b1" } },
        { startTime = 0.38, type = ET.PlayVFX, params = { templateId = "fireball_purple", attachToBullet = true, bulletId = "angela_q_b2" } },
        { startTime = 0.46, type = ET.PlayVFX, params = { templateId = "fireball_purple", attachToBullet = true, bulletId = "angela_q_b3" } },
        { startTime = 0.54, type = ET.PlayVFX, params = { templateId = "fireball_purple", attachToBullet = true, bulletId = "angela_q_b4" } },
        { startTime = 0.62, type = ET.PlayVFX, params = { templateId = "fireball_purple", attachToBullet = true, bulletId = "angela_q_b5" } },
    },
}

--[[
    W - 娣锋矊鐏锛堟柟鍚戝瀷寮归亾 鈫?瑁傚彉鐏劙婕╂丁锛?
    鏈哄埗锛?
    - 鏈濇寚瀹氭柟鍚戦噴鏀剧伀绉嶅脊閬?
    - 鍛戒腑鎴栧埌杈炬渶杩滃鏃惰鍙樹负鐏劙婕╂丁
    - 婕╂丁姣?.5绉掍激瀹虫寔缁?绉掞紝鍑忛€?0%鎸佺画1.5绉?
    - 鐩存帴鍛戒腑鏅曠湬1绉?
]]
SkillEventTable.angela_w = {
    totalDuration = 3.8,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.ForbidAbility, duration = 0.4, params = { forbidMove = true, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.6, params = { animId = "angela_push", speed = 1.0 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "angela_cast_circle", attachToSelf = true, duration = 0.5 } },

        -- 鍙戝皠鐏寮归亾
        { startTime = 0.20, type = ET.SpawnBullet, params = {
            bulletId = "angela_w_seed", speed = 50, maxDist = 15,
            size = Vector3.new(1.5, 1.5, 1.5),
            stopOnHit = true, spawnFieldOnStop = true,
        }},
        { startTime = 0.20, type = ET.PlayVFX, params = { templateId = "angela_w_seed_vfx", attachToBullet = true, bulletId = "angela_w_seed" } },
        { startTime = 0.20, type = ET.MoveBullet, duration = 0.5, params = { bulletId = "angela_w_seed", speed = 50, maxDist = 15 } },

        -- 鐩存帴鍛戒腑锛氭檿鐪?绉?
        { startTime = 0.20, type = ET.HitDetect, duration = 0.5, params = {
            attachToBullet = true, bulletId = "angela_w_seed",
            shape = "Box", size = Vector3.new(1.5, 1.5, 1.5), maxTargets = 1, interval = 0,
            stopBulletOnHit = true,
        }, onHit = {
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Stun", duration = 1.0 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},

        -- 瑁傚彉婕╂丁
        { startTime = 0.70, type = ET.PlayVFX, params = { 
            templateId = "angela_w_vortex", useBulletStopPosition = true, 
            bulletId = "angela_w_seed", duration = 3.0 
        }},
        { startTime = 0.70, type = ET.PlayVFX, params = { 
            templateId = "angela_w_vortex_circle", useBulletStopPosition = true, 
            bulletId = "angela_w_seed", duration = 3.0 
        }},

        -- 婕╂丁鍛戒腑锛氭瘡0.5绉掍竴娆′激瀹?鍑忛€?0%
        { startTime = 0.70, type = ET.HitDetect, duration = 3.0, params = {
            shape = "Sphere", radius = 3.5,
            useBulletStopPosition = true, bulletId = "angela_w_seed",
            maxTargets = 32, interval = 0.5,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 130, damageType = "Magic", apRatio = 0.17 } },
            { startTime = 0, type = ET.ApplyBuff, params = { buffType = "Slow", duration = 1.5, value = 0.50 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},
    },
}

--[[
    E - 鐐界儹鍏夎緣锛堟柟鍚戝瀷寮曞 鈥?鎸佺画3绉掕兘閲忓厜鏉燂級
    鉁?淇锛氱帇鑰呰崳鑰€鍘熺増鏄湞鎸囧畾鏂瑰悜鎸佺画閲婃斁鑳介噺鍏夋潫锛屼笉鏄嚜韬负涓績AOE
    鏈哄埗锛?
    - 鏈濇寚瀹氭柟鍚戞寔缁噴鏀剧偨鐑厜杈?绉?
    - 姣?.3绉掑瑙︾鐨勬晫浜洪€犳垚娉曟湳浼ゅ
    - 鑾峰緱鎶ょ浘+鎶ょ浘鏈熼棿鍏嶆帶
    - 鏂芥硶鏈熼棿鍙Щ鍔紙鏀瑰彉鏈濆悜鏉ヨ皟鏁村厜鏉熸柟鍚戯級
    - 鏂芥硶1绉掑悗鍙啀娆￠噴鏀惧彇娑堝紩瀵?
]]
SkillEventTable.angela_e = {
    totalDuration = 3.5,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.ForbidAbility, duration = 0.5, params = { forbidMove = false, forbidSkill = true } },
        { startTime = 0.00, type = ET.TriggerCD },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "angela_channel_start", speed = 1.0 } },
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "angela_cast_circle", attachToSelf = true, duration = 3.0 } },

        -- 鑾峰緱鎶ょ浘 + 鍏嶆帶
        { startTime = 0.00, type = ET.ApplyBuff, params = { 
            buffType = "Shield", duration = 3.0, value = 700, toSelf = true,  -- 鉁?Lv1 鎶ょ浘鍊?00
            apRatio = 0.88, grantImmunity = true,
        }},

        -- 鍏佽绉诲姩杞悜锛堟敼鍙樻湞鍚戞潵璋冩暣鍏夋潫鏂瑰悜锛?
        { startTime = 0.00, type = ET.RotateActor, duration = 3.0, params = { rotateSpeed = 90 } },

        -- 1绉掑悗鍏佽鍙栨秷
        { startTime = 1.00, type = ET.ChangeSkill, params = { replaceKey = "E", newSkillId = "angela_e_cancel", revertTime = 2.0 } },

        -- 寮曞鍔ㄧ敾
        { startTime = 0.50, type = ET.PlayAnim, duration = 2.5, params = { animId = "angela_channel_loop", speed = 1.0, loopCount = 5 } },
        { startTime = 3.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "angela_channel_end", speed = 1.0 } },

        -- 鐐界儹鍏夎緣鍏夋潫鐗规晥锛堝墠鏂规柟鍚戝瀷锛?
        { startTime = 0.00, type = ET.PlayVFX, params = { 
            templateId = "angela_e_beam", attachToSelf = true, duration = 3.0,
            isDirectional = true, beamLength = 12,
        }},
        { startTime = 0.00, type = ET.PlayVFX, params = { templateId = "angela_e_shield_aura", attachToSelf = true, duration = 3.0 } },

        -- 鍛戒腑妫€娴嬶細鍓嶆柟鐭╁舰鍖哄煙锛屾寔缁?绉掞紝姣?.3绉掓娴嬩竴娆?
        { startTime = 0.00, type = ET.HitDetect, duration = 3.0, params = {
            shape = "Box", size = Vector3.new(3, 4, 12),  -- 瀹? x 楂? x 闀?2 鐨勭煩褰㈠尯鍩?
            attachToSelf = true, 
            useForwardDirection = true,  -- 浣跨敤鏂芥硶鑰呭綋鍓嶆湞鍚?
            maxTargets = 32, interval = 0.3,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 150, damageType = "Magic", apRatio = 0.21 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},

        -- 鎸佺画鏂芥硶杩涘害鏉?
        { startTime = 0.00, type = ET.ChannelBar, duration = 3.0, params = { barType = "channel" } },
    },
}

-- E鍙栨秷锛堢偨鐑厜杈夊彇娑堝紩瀵硷紝淇濈暀鎶ょ浘锛?
SkillEventTable.angela_e_cancel = {
    totalDuration = 0.1,
    isCancelSkill = true,
    cancelTarget = "angela_e",
    events = {},
}

--============================================================
-- 琚姩鎶€鑳介厤缃?
--============================================================

-- 瀹夌惇鎷夎鍔細鍜掓湳鐏劙锛堟妧鑳界伡鐑у彔鍔狅紝鏈€澶?0灞傦紝姣忓眰棰濆娉曟湳浼ゅ锛?
-- 鉁?瀵规爣鐜嬭€呰崳鑰€瀹樻柟锛氬嵃璁伴€愬眰娑堝け锛屼笉鏄叏閮ㄦ竻闄?
SkillEventTable.angela_passive = {
    totalDuration = 0,
    isPassive = true,
    passiveType = "onSkillHit",  -- 鎶€鑳藉懡涓椂瑙﹀彂
    events = {},
    onTrigger = {
        -- 姣忔鎶€鑳藉懡涓彔鍔犵伡鐑у嵃璁帮紙duration鏄€愬眰娑堝け寮€濮嬪墠鐨勫欢杩燂級
        { startTime = 0, type = ET.AddMark, params = { 
            markId = "angela_burn", amount = 1, duration = 3, maxStack = 10,
        }},
    },
    -- 鐏肩儳鍙傛暟
    burnParams = {
        damagePerStack = 8,         -- 姣忓眰姣忕浼ゅ鍩虹鍊?
        apRatioPerStack = 0.02,     -- 姣忓眰 +2%娉曟湳鍔犳垚
        tickInterval = 1.0,         -- 姣忕瑙﹀彂
        decayMode = "perStack",     -- 鉁?閫愬眰娑堝け妯″紡锛堝畼鏂规満鍒讹級
        decayInterval = 1.0,        -- 姣忕娑堝け1灞?
        speedPerStack = 0.02,       -- 姣忓眰缁欐柦娉曡€?+2% 绉婚€?
    },
}

--============================================================
-- 鏅敾閰嶇疆
--============================================================

-- 鍚庣究鏅敾锛堣繙绋嬬鐭級
SkillEventTable.basic_attack_houyi = {
    totalDuration = 0.6,
    isBasicAttack = true,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "houyi_attack", speed = 1.0 } },
        { startTime = 0.15, type = ET.SpawnBullet, params = {
            bulletId = "houyi_auto", speed = 60, maxDist = 12,
            size = Vector3.new(0.4, 0.4, 1.0),
        }},
        { startTime = 0.15, type = ET.PlayVFX, params = { templateId = "arrow_normal", attachToBullet = true, bulletId = "houyi_auto" } },
        { startTime = 0.15, type = ET.MoveBullet, duration = 0.3, params = { bulletId = "houyi_auto", speed = 60, maxDist = 12 } },
        { startTime = 0.15, type = ET.HitDetect, duration = 0.3, params = {
            attachToBullet = true, bulletId = "houyi_auto",
            shape = "Box", size = Vector3.new(0.6, 0.6, 1.0), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 0, damageType = "Physical", useAttackDamage = true } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
    },
    -- Q澶氶噸绠煝婵€娲绘椂浣跨敤鐨勫己鍖栨櫘鏀?
    multiArrowEvents = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "houyi_multi_attack", speed = 1.2 } },
        -- 涓棿涓荤
        { startTime = 0.15, type = ET.SpawnBullet, params = {
            bulletId = "houyi_multi_1", speed = 60, maxDist = 12,
            size = Vector3.new(0.5, 0.5, 1.2),
        }},
        { startTime = 0.15, type = ET.PlayVFX, params = { templateId = "arrow_fire", attachToBullet = true, bulletId = "houyi_multi_1" } },
        { startTime = 0.15, type = ET.MoveBullet, duration = 0.3, params = { bulletId = "houyi_multi_1", speed = 60, maxDist = 12 } },
        { startTime = 0.15, type = ET.HitDetect, duration = 0.3, params = {
            attachToBullet = true, bulletId = "houyi_multi_1",
            shape = "Box", size = Vector3.new(0.6, 0.6, 1.2), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 0, damageType = "Physical", useAttackDamage = true, adRatio = 0.75 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_fire" } },
        }},
        -- 宸︿晶鍓锛堝亸杞?15搴︼級
        { startTime = 0.15, type = ET.SpawnBullet, params = {
            bulletId = "houyi_multi_2", speed = 55, maxDist = 10,
            size = Vector3.new(0.4, 0.4, 1.0), angle = -15,
        }},
        { startTime = 0.15, type = ET.PlayVFX, params = { templateId = "arrow_fire", attachToBullet = true, bulletId = "houyi_multi_2" } },
        { startTime = 0.15, type = ET.MoveBullet, duration = 0.3, params = { bulletId = "houyi_multi_2", speed = 55, maxDist = 10 } },
        { startTime = 0.15, type = ET.HitDetect, duration = 0.3, params = {
            attachToBullet = true, bulletId = "houyi_multi_2",
            shape = "Box", size = Vector3.new(0.5, 0.5, 1.0), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 0, damageType = "Physical", useAttackDamage = true, adRatio = 0.50 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_fire" } },
        }},
        -- 鍙充晶鍓锛堝亸杞?15搴︼級
        { startTime = 0.15, type = ET.SpawnBullet, params = {
            bulletId = "houyi_multi_3", speed = 55, maxDist = 10,
            size = Vector3.new(0.4, 0.4, 1.0), angle = 15,
        }},
        { startTime = 0.15, type = ET.PlayVFX, params = { templateId = "arrow_fire", attachToBullet = true, bulletId = "houyi_multi_3" } },
        { startTime = 0.15, type = ET.MoveBullet, duration = 0.3, params = { bulletId = "houyi_multi_3", speed = 55, maxDist = 10 } },
        { startTime = 0.15, type = ET.HitDetect, duration = 0.3, params = {
            attachToBullet = true, bulletId = "houyi_multi_3",
            shape = "Box", size = Vector3.new(0.5, 0.5, 1.0), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 0, damageType = "Physical", useAttackDamage = true, adRatio = 0.50 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_fire" } },
        }},
    },
}

-- 寤夐鏅敾锛堣繎鎴樻嫵鍑伙紝绗?涓嬪己鍖栤€斺€?鎶€鑳借鍔級
SkillEventTable.basic_attack_lianpo = {
    totalDuration = 0.5,
    isBasicAttack = true,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.4, params = { animId = "lianpo_attack", speed = 1.0 } },
        { startTime = 0.15, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Box", size = Vector3.new(3, 3, 4),
            attachToSelf = true, maxTargets = 1, interval = 0,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 0, damageType = "Physical", useAttackDamage = true } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
        }},
    },
    -- 绗?娈靛己鍖栵紙1鎶€鑳借鍔級
    enhancedAttackCount = 3,
    enhancedEvents = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.5, params = { animId = "lianpo_enhanced_punch", speed = 1.0 } },
        { startTime = 0.20, type = ET.HitDetect, duration = 0.1, params = {
            shape = "Sphere", radius = 5, attachToSelf = true, maxTargets = 32, interval = 0,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 200, damageType = "Physical", adRatio = 0.15 } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "lianpo_enhanced_punch" } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_physical" } },
            -- 寮哄寲鏅敾鍛戒腑鍑廞 CD 2绉?
            { startTime = 0, type = ET.TriggerCD, params = { resetCD = true, targetSkillId = "lianpo_q", cdReduction = 2 } },
        }},
        { startTime = 0.20, type = ET.CameraShake, duration = 0.2, params = { intensity = 0.3 } },
    },
}

-- 瀹夌惇鎷夋櫘鏀伙紙杩滅▼娉曠悆锛?
SkillEventTable.basic_attack_angela = {
    totalDuration = 0.7,
    isBasicAttack = true,
    events = {
        { startTime = 0.00, type = ET.SetAttackDir, duration = 0.05 },
        { startTime = 0.00, type = ET.PlayAnim, duration = 0.6, params = { animId = "angela_attack", speed = 1.0 } },
        { startTime = 0.20, type = ET.SpawnBullet, params = {
            bulletId = "angela_auto", speed = 50, maxDist = 8,
            size = Vector3.new(0.5, 0.5, 0.5),
        }},
        { startTime = 0.20, type = ET.PlayVFX, params = { templateId = "fireball_purple_small", attachToBullet = true, bulletId = "angela_auto" } },
        { startTime = 0.20, type = ET.MoveBullet, duration = 0.3, params = { bulletId = "angela_auto", speed = 50, maxDist = 8 } },
        { startTime = 0.20, type = ET.HitDetect, duration = 0.3, params = {
            attachToBullet = true, bulletId = "angela_auto",
            shape = "Box", size = Vector3.new(0.5, 0.5, 0.5), maxTargets = 1, interval = 0,
            destroyBulletOnHit = true,
        }, onHit = {
            { startTime = 0, type = ET.DealDamage, params = { damage = 0, damageType = "Magic", useAttackDamage = true } },
            { startTime = 0, type = ET.PlayVFX, params = { templateId = "impact_magic" } },
        }},
    },
}

--============================================================
-- 鏌ヨ鎺ュ彛
--============================================================

function SkillEventTable.getSkillEvents(skillId: string)
    return SkillEventTable[skillId]
end

function SkillEventTable.getBasicAttack(heroId: string)
    return SkillEventTable["basic_attack_" .. heroId]
end

function SkillEventTable.getPassive(heroId: string)
    -- 鑻遍泟涓撳睘琚姩
    if heroId == "angela" then
        return SkillEventTable.angela_passive
    end
    -- 鍚庣究/寤夐鐨勮鍔ㄥ湪 R 鎶€鑳戒腑瀹氫箟
    local passiveId = heroId .. "_r"
    local passive = SkillEventTable[passiveId]
    if passive and passive.isPassive then
        return passive
    end
    return nil
end

return SkillEventTable

