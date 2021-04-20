// stored_energy += (pulse_strength-RAD_COLLECTOR_EFFICIENCY)*RAD_COLLECTOR_COEFFICIENT
#define RAD_COLLECTOR_EFFICIENCY 80 	// radiation needs to be over this amount to get power
#define RAD_COLLECTOR_COEFFICIENT 100
#define RAD_COLLECTOR_STORED_OUT 0.04	// (this*100)% of stored power outputted per tick. Doesn't actualy change output total, lower numbers just means collectors output for longer in absence of a source
#define RAD_COLLECTOR_MINING_CONVERSION_RATE 0.00001 //This is gonna need a lot of tweaking to get right. This is the number used to calculate the conversion of watts to research points per process()
#define RAD_COLLECTOR_OUTPUT min(stored_energy, (stored_energy*RAD_COLLECTOR_STORED_OUT)+1000) //Produces at least 1000 watts if it has more than that stored
#define PUBLIC_TECHWEB_GAIN 0.6 //how many research points go directly into the main pool
#define PRIVATE_TECHWEB_GAIN (1 - PUBLIC_TECHWEB_GAIN) //how many research points go to the user
/obj/machinery/power/rad_collector
	name = "радиационный коллекторный массив"
	desc = "Устройство, которое использует излучение Хокинга и плазму для производства энергии."
	icon = 'icons/obj/singularity.dmi'
	icon_state = "ca"
	anchored = FALSE
	density = TRUE
	req_access = list(ACCESS_ENGINE_EQUIP, ACCESS_ATMOSPHERICS)
	max_integrity = 350
	integrity_failure = 0.2
	circuit = /obj/item/circuitboard/machine/rad_collector
	rad_insulation = RAD_EXTREME_INSULATION
	var/obj/item/tank/internals/plasma/loaded_tank = null
	var/stored_energy = 0
	var/active = 0
	var/locked = FALSE
	var/drainratio = 0.5
	var/powerproduction_drain = 0.001
	var/bitcoinproduction_drain = 0.15
	var/bitcoinmining = FALSE
	///research points stored
	var/stored_research = 0

/obj/machinery/power/rad_collector/anchored/Initialize()
	. = ..()
	set_anchored(TRUE)

/obj/machinery/power/rad_collector/Destroy()
	return ..()

/obj/machinery/power/rad_collector/should_have_node()
	return anchored

/obj/machinery/power/rad_collector/process(delta_time)
	if(!loaded_tank)
		return
	if(!bitcoinmining)
		if(loaded_tank.air_contents.get_moles(/datum/gas/plasma) < 0.0001)
			investigate_log("<font color='red'>out of fuel</font>.", INVESTIGATE_SINGULO)
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			eject()
		else
			var/gasdrained = min(powerproduction_drain*drainratio,loaded_tank.air_contents.get_moles(/datum/gas/plasma))
			loaded_tank.air_contents.adjust_moles(/datum/gas/plasma, -gasdrained)
			loaded_tank.air_contents.adjust_moles(/datum/gas/tritium, gasdrained)

			var/power_produced = RAD_COLLECTOR_OUTPUT
			add_avail(power_produced)
			stored_energy-=power_produced
	else if(is_station_level(z) && SSresearch.science_tech)
		if(!loaded_tank.air_contents.get_moles(/datum/gas/tritium) || !loaded_tank.air_contents.get_moles(/datum/gas/oxygen))
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			eject()
		else
			var/gasdrained = bitcoinproduction_drain*drainratio
			loaded_tank.air_contents.adjust_moles(/datum/gas/tritium, -gasdrained)
			loaded_tank.air_contents.adjust_moles(/datum/gas/oxygen, -gasdrained)
			loaded_tank.air_contents.adjust_moles(/datum/gas/carbon_dioxide, gasdrained*2)
			var/bitcoins_mined = RAD_COLLECTOR_OUTPUT
			var/datum/bank_account/D = SSeconomy.get_dep_account(ACCOUNT_ENG)
			if(D)
				D.adjust_money(bitcoins_mined*RAD_COLLECTOR_MINING_CONVERSION_RATE)
			stored_research += bitcoins_mined*RAD_COLLECTOR_MINING_CONVERSION_RATE*PRIVATE_TECHWEB_GAIN
			SSresearch.science_tech.add_point_list(list(TECHWEB_POINT_TYPE_DEFAULT = bitcoins_mined*RAD_COLLECTOR_MINING_CONVERSION_RATE*PUBLIC_TECHWEB_GAIN))
			stored_energy-=bitcoins_mined

/obj/machinery/power/rad_collector/interact(mob/user)
	if(anchored)
		if(!src.locked)
			toggle_power()
			user.visible_message("<span class='notice'><b>[user.name]</b> [active? "включает":"выключает"] <b>[src.name]</b>.</span>", \
			"<span class='notice'>[active? "Включаю":"Выключаю"] <b>[src.name]</b>.</span>")
			if(loaded_tank.air_contents)
				var/fuel = loaded_tank.air_contents.get_moles(/datum/gas/plasma)
				investigate_log("turned [active?"<font color='green'>on</font>":"<font color='red'>off</font>"] by [key_name(user)]. [loaded_tank?"Fuel: [round(fuel/0.29)]%":"<font color='red'>It is empty</font>"].", INVESTIGATE_SINGULO)
			return
		else
			to_chat(user, "<span class='warning'>Управление заблокировано!</span>")
			return

/obj/machinery/power/rad_collector/can_be_unfasten_wrench(mob/user, silent)
	if(loaded_tank)
		if(!silent)
			to_chat(user, "<span class='warning'>Надо бы вытащить бак для начала!</span>")
		return FAILED_UNFASTEN
	return ..()

/obj/machinery/power/rad_collector/set_anchored(anchorvalue)
	. = ..()
	if(isnull(.))
		return //no need to process if we didn't change anything.
	if(anchorvalue)
		connect_to_network()
	else
		disconnect_from_network()

/obj/machinery/power/rad_collector/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/tank/internals/plasma))
		if(!anchored)
			to_chat(user, "<span class='warning'><b>[src]</b> должен быть прикручен к полу!</span>")
			return TRUE
		if(loaded_tank)
			to_chat(user, "<span class='warning'>Здесь уже есть бак!</span>")
			return TRUE
		if(panel_open)
			to_chat(user, "<span class='warning'>Техническая панель открыта. Не входит!</span>")
			return TRUE
		if(!user.transferItemToLoc(W, src))
			return
		loaded_tank = W
		update_icon()
	else if(W.GetID())
		if(allowed(user))
			if(active)
				locked = !locked
				to_chat(user, "<span class='notice'>Управление [locked ? "заблокировано" : "разблокировано"].</span>")
			else
				to_chat(user, "<span class='warning'>Управление может быть заблокировано только когда <b>[src]</b> включен!</span>")
		else
			to_chat(user, "<span class='danger'>Доступ запрещён.</span>")
			return TRUE
	else
		return ..()

/obj/machinery/power/rad_collector/analyzer_act(mob/living/user, obj/item/I)
	if(stored_research >= 1)
		//new /obj/item/research_notes(user.loc, stored_research, "engineering")
		stored_research = 0
		return TRUE
	return ..()

/obj/machinery/power/rad_collector/wrench_act(mob/living/user, obj/item/I)
	..()
	default_unfasten_wrench(user, I)
	return TRUE

/obj/machinery/power/rad_collector/screwdriver_act(mob/living/user, obj/item/I)
	if(..())
		return TRUE
	if(loaded_tank)
		to_chat(user, "<span class='warning'>Надо бы вытащить бак сначала!</span>")
	else
		default_deconstruction_screwdriver(user, icon_state, icon_state, I)
	return TRUE

/obj/machinery/power/rad_collector/crowbar_act(mob/living/user, obj/item/I)
	if(loaded_tank)
		if(locked)
			to_chat(user, "<span class='warning'>Управление заблокировано!</span>")
			return TRUE
		eject()
		return TRUE
	if(default_deconstruction_crowbar(I))
		return TRUE
	to_chat(user, "<span class='warning'>Здесь нет бака!</span>")
	return TRUE

/obj/machinery/power/rad_collector/multitool_act(mob/living/user, obj/item/I)
	if(!is_station_level(z) && !SSresearch.science_tech)
		to_chat(user, "<span class='warning'><b>[src]</b> не подключен к исследовательской сети!</span>")
		return TRUE
	if(locked)
		to_chat(user, "<span class='warning'><b>[src]</b> заблокирован!</span>")
		return TRUE
	if(active)
		to_chat(user, "<span class='warning'><b>[src]</b> на данный момент работает и производит [bitcoinmining ? "исследовательские очки":"энергию"].</span>")
		return TRUE
	bitcoinmining = !bitcoinmining
	to_chat(user, "<span class='warning'>[bitcoinmining ? "Включаю":"Выключаю"] сбор исследовательских очков у <b>[src]</b>.</span>")
	return TRUE

/obj/machinery/power/rad_collector/return_analyzable_air()
	if(loaded_tank)
		return loaded_tank.return_analyzable_air()
	else
		return null

/obj/machinery/power/rad_collector/examine(mob/user)
	. = ..()
	. += "<hr>"
	if(active)
		if(!bitcoinmining)
			// stored_energy is converted directly to watts every SSmachines.wait * 0.1 seconds.
			// Therefore, its units are joules per SSmachines.wait * 0.1 seconds.
			// So joules = stored_energy * SSmachines.wait * 0.1
			var/joules = stored_energy * SSmachines.wait * 0.1
			. += "<span class='notice'>Дисплей <b>[src]</b> сообщает о накопленных <b>[DisplayJoules(joules)]</b> и выработке <b>[DisplayPower(RAD_COLLECTOR_OUTPUT)]</b>.</span>"
		else
			. += "<span class='notice'>Дисплей <b>[src]</b> сообщает о <b>[stored_research]</b> исследовательских очках за всё время и также производит [RAD_COLLECTOR_OUTPUT*RAD_COLLECTOR_MINING_CONVERSION_RATE] исследовательских очков в минуту.</span>"
	else
		if(!bitcoinmining)
			. += "<span class='notice'>Дисплей <b>[src]</b> сообщает:</b> \"Режим производства электроэнергии. Пожалуйста, вставьте <b>бак плазмы</b>. Используйте мультитул для изменения режимов производства.\"</span>"
		else
			. += "<span class='notice'>Дисплей <b>[src]</b> сообщает:</b> \"Исследовательский режим производства. Пожалуйста, вставьте <b>тритий</b> и <b>кислород</b>. Используйте мультитул для изменения режимов производства.\"</span>"

/obj/machinery/power/rad_collector/obj_break(damage_flag)
	. = ..()
	if(.)
		eject()

/obj/machinery/power/rad_collector/proc/eject()
	locked = FALSE
	var/obj/item/tank/internals/plasma/Z = src.loaded_tank
	if (!Z)
		return
	Z.forceMove(drop_location())
	Z.layer = initial(Z.layer)
	Z.plane = initial(Z.plane)
	src.loaded_tank = null
	if(active)
		toggle_power()
	else
		update_icon()

/obj/machinery/power/rad_collector/rad_act(pulse_strength)
	. = ..()
	if(loaded_tank && active && pulse_strength > RAD_COLLECTOR_EFFICIENCY)
		stored_energy += (pulse_strength-RAD_COLLECTOR_EFFICIENCY)*RAD_COLLECTOR_COEFFICIENT

/obj/machinery/power/rad_collector/update_overlays()
	. = ..()
	if(loaded_tank)
		. += "ptank"
	if(machine_stat & (NOPOWER|BROKEN))
		return
	if(active)
		. += "on"

/obj/machinery/power/rad_collector/proc/toggle_power()
	active = !active
	if(active)
		icon_state = "ca_on"
		flick("ca_active", src)
	else
		icon_state = "ca"
		flick("ca_deactive", src)
	update_icon()
	return

#undef RAD_COLLECTOR_EFFICIENCY
#undef RAD_COLLECTOR_COEFFICIENT
#undef RAD_COLLECTOR_STORED_OUT
#undef RAD_COLLECTOR_MINING_CONVERSION_RATE
#undef RAD_COLLECTOR_OUTPUT
#undef PUBLIC_TECHWEB_GAIN
#undef PRIVATE_TECHWEB_GAIN
