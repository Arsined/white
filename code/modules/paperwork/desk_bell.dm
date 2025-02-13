// A receptionist's bell

/obj/structure/desk_bell
	name = "Звонок"
	desc = "Нужно срочно нажать на это."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "desk_bell"
	layer = OBJ_LAYER
	anchored = FALSE
	pass_flags = PASSTABLE // Able to place on tables
	max_integrity = 5000 // To make attacking it not instantly break it
	/// The amount of times this bell has been rang, used to check the chance it breaks
	var/times_rang = 0
	/// Is this bell broken?
	var/broken_ringer = FALSE
	/// The cooldown for ringing the bell
	COOLDOWN_DECLARE(ring_cooldown)
	/// The length of the cooldown. Setting it to 0 will skip all cooldowns alltogether.
	var/ring_cooldown_length = 0.3 SECONDS // This is here to protect against tinnitus.
	/// The sound the bell makes
	var/ring_sound = 'sound/machines/microwave/microwave-end.ogg'

/obj/structure/desk_bell/Initialize(mapload)
	. = ..()
	register_context()

/obj/structure/desk_bell/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()

	if(held_item?.tool_behaviour == TOOL_WRENCH)
		context[SCREENTIP_CONTEXT_RMB] = "Разобрать"
		return CONTEXTUAL_SCREENTIP_SET

	if(broken_ringer)
		if(held_item?.tool_behaviour == TOOL_SCREWDRIVER)
			context[SCREENTIP_CONTEXT_LMB] = "Починить"
	else
		var/click_context = "Дзынь"
		if(prob(1))
			click_context = "Раздражать"
		context[SCREENTIP_CONTEXT_LMB] = click_context
	return CONTEXTUAL_SCREENTIP_SET

/obj/structure/desk_bell/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!COOLDOWN_FINISHED(src, ring_cooldown) && ring_cooldown_length)
		return TRUE
	if(!ring_bell(user))
		to_chat(user, span_notice("[src] сломан. Какой-то идиот сломал его."))
	if(ring_cooldown_length)
		COOLDOWN_START(src, ring_cooldown, ring_cooldown_length)
	return TRUE

/obj/structure/desk_bell/attackby(obj/item/weapon, mob/living/user, params)
	. = ..()
	times_rang += weapon.force
	ring_bell(user)

// Fix the clapper
/obj/structure/desk_bell/screwdriver_act(mob/living/user, obj/item/tool)
	if(broken_ringer)
		balloon_alert(user, "чиним...")
		tool.play_tool_sound(src)
		if(tool.use_tool(src, user, 5 SECONDS))
			balloon_alert_to_viewers("починено")
			playsound(user, 'sound/items/change_drill.ogg', 50, vary = TRUE)
			broken_ringer = FALSE
			times_rang = 0
			return TOOL_ACT_TOOLTYPE_SUCCESS
		return FALSE
	return ..()

// Deconstruct
/obj/structure/desk_bell/wrench_act_secondary(mob/living/user, obj/item/tool)
	balloon_alert(user, "разбираем...")
	tool.play_tool_sound(src)
	if(tool.use_tool(src, user, 5 SECONDS))
		balloon_alert(user, "разобрано")
		playsound(user, 'sound/items/deconstruct.ogg', 50, vary = TRUE)
		if(!broken_ringer) // Drop 2 if it's not broken.
			new/obj/item/stack/sheet/iron(drop_location())
		new/obj/item/stack/sheet/iron(drop_location())
		qdel(src)
		return TOOL_ACT_TOOLTYPE_SUCCESS
	return ..()

/// Check if the clapper breaks, and if it does, break it
/obj/structure/desk_bell/proc/check_clapper(mob/living/user)
	if(((times_rang >= 10000) || prob(times_rang/100)) && ring_cooldown_length)
		to_chat(user, span_notice("Слышу как защёлкиватель [src] выпадает из паза. Отличная работа."))
		broken_ringer = TRUE

/// Ring the bell
/obj/structure/desk_bell/proc/ring_bell(mob/living/user)
	if(broken_ringer)
		return FALSE
	check_clapper(user)
	// The lack of varying is intentional. The only variance occurs on the strike the bell breaks.
	playsound(src, ring_sound, 70, vary = broken_ringer, extrarange = SHORT_RANGE_SOUND_EXTRARANGE)
	flick("desk_bell_ring", src)
	times_rang++
	return TRUE

// A warning to all who enter; the ringing sound STACKS. It won't be deafening because it only goes every decisecond,
// but I did feel like my ears were going to start bleeding when I tested it with my autoclicker.
/obj/structure/desk_bell/speed_demon
	desc = "Нужно срочно нажать на это и не раз."
	ring_cooldown_length = 0

/obj/structure/desk_bell/MouseDrop(obj/over_object, src_location, over_location)
	if((!istype(over_object, /obj/vehicle/ridden/wheelchair)))
		return
	if(!Adjacent(over_object) || !Adjacent(usr))
		return
	var/obj/vehicle/ridden/wheelchair/target = over_object
	if(target.bell_attached)
		usr.balloon_alert(usr, "уже имеет звонок!")
		return
	usr.balloon_alert(usr, "присоединяем...")
	if(!do_after(usr, 5))
		return
	target.attach_bell(src)
	qdel(src)
	return ..()
