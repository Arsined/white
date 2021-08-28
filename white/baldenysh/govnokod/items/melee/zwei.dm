/obj/item/zwei
	name = "цвай"
	desc = "вхен зе претендер ис мислидинг."
	icon = 'white/baldenysh/icons/obj/weapons/melee.dmi'
	icon_state = "gs_dagger" //pohui
	inhand_icon_state = "gs_zwei"
	//lefthand_file = 'white/baldenysh/icons/mob/inhands/weapons/melee64x64_lefthand.dmi' //pohui
	righthand_file = 'white/baldenysh/icons/mob/inhands/weapons/melee64x64_righthand.dmi'
	inhand_x_dimension = 64
	inhand_y_dimension = 64
	slot_flags = ITEM_SLOT_BACK
	w_class = WEIGHT_CLASS_HUGE
	force = 5
	throwforce = 15
	hitsound = 'sound/weapons/bladeslice.ogg'
	attack_verb_simple = list("атакует", "рубит", "втыкает", "разрубает", "кромсает", "разрывает", "нарезает", "режет")
	block_chance = 20
	sharpness = SHARP_EDGED
	max_integrity = 150
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 100, "acid" = 50)
	resistance_flags = FIRE_PROOF
	reach = 2
	custom_materials = list(/datum/material/iron = 10000)

/obj/item/zwei/Initialize()
	. = ..()
	RegisterSignal(src, COMSIG_TWOHANDED_WIELD, .proc/on_wield)
	RegisterSignal(src, COMSIG_TWOHANDED_UNWIELD, .proc/on_unwield)
	update_icon()

/obj/item/zwei/ComponentInitialize()
	. = ..()
	AddComponent(/datum/component/two_handed, force_unwielded=5, force_wielded=40)

/obj/item/zwei/proc/rebuild_icon(wielded = FALSE)
	if(!iscarbon(loc))
		return
	//var/mob/living/carbon/C = loc
	//cut_overlays()
	inhand_icon_state = "gs_zwei[wielded ? "_wielded" : ""]"
	//хз неебу как накатить оверлеи на иконку в руках, но надо
	//add_overlay(image(icon = C.get_held_index_of_item(src) % 2 ? lefthand_file : righthand_file, icon_state = inhand_icon_state + "_grip"))
	update_icon()

/obj/item/zwei/proc/on_wield(obj/item/source, mob/user)
	rebuild_icon(TRUE)

/obj/item/zwei/proc/on_unwield(obj/item/source, mob/user)
	rebuild_icon(FALSE)

/obj/item/zwei/afterattack(atom/target, mob/user, proximity)
	. = ..()
	if(!proximity)
		return
	user.changeNext_move(3 SECONDS)
