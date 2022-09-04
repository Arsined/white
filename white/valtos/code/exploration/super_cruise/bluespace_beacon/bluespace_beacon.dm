/obj/item/sbeacondrop/exploration
	name = "блюспейс-маяк"
	desc = "Надпись на нём оглашает: <i>ВНИМАНИЕ: Активация данного устройства отправит к вам блюспейс-гигамаяк, который позволит возвращаться в зону активации снова.</i>."
	droptype = /obj/structure/bluespace_beacon

//Beacon structure

/obj/structure/bluespace_beacon
	name = "блюспейс-гигамаяк"
	desc = "Закрепляет текущее местоположение в глобальной блюспейс-сети, разрешая возвращаться сюда снова."
	icon = 'icons/obj/machines/NavBeacon.dmi'
	icon_state = "beacon-item"
	density = TRUE

	max_integrity = 200
	resistance_flags = FIRE_PROOF | ACID_PROOF

	light_power = 2
	light_range = 3
	light_color = "#cd87df"

	anchored = TRUE

/obj/structure/bluespace_beacon/Initialize(mapload)
	. = ..()
	GLOB.zclear_blockers += src

/obj/structure/bluespace_beacon/Destroy()
	GLOB.zclear_blockers -= src
	. = ..()

/obj/structure/bluespace_beacon/wrench_act(mob/living/user, obj/item/I)
	if(anchored)
		to_chat(user, "<span class='notice'>Начинаю откручивать [src]...</span>")
	else
		to_chat(user, "<span class='notice'>Начинаю прикручивать [src]...</span>")
	if(I.use_tool(src, user, 40, volume=50))
		if(QDELETED(I))
			return
		if(anchored)
			to_chat(user, "<span class='notice'>Откручиваю [src].</span>")
		else
			to_chat(user, "<span class='notice'>Прикручиваю [src].</span>")
		anchored = !anchored
