/datum/round_event_control/aurora_caelus
	name = "Aurora Caelus"
	typepath = /datum/round_event/aurora_caelus
	max_occurrences = 1
	weight = 1
	earliest_start = 5 MINUTES

/datum/round_event_control/aurora_caelus/canSpawnEvent(players, gamemode)
	if(!CONFIG_GET(flag/starlight))
		return FALSE
	return ..()

/datum/round_event/aurora_caelus
	announceWhen = 1
	startWhen = 9
	endWhen = 50
	var/list/aurora_colors = list("#A2FF80", "#A2FF8B", "#A2FF96", "#A2FFA5", "#A2FFB6", "#A2FFC7", "#A2FFDE", "#A2FFEE")
	var/aurora_progress = 0 //this cycles from 1 to 8, slowly changing colors from gentle green to gentle blue

/datum/round_event/aurora_caelus/announce()
	var/annus = "Безвредное облако ионов приближается к вашей станции истощая свою энергию стукаясь о корпус. NanoTrasen разрешает всем сотрудникам сделать короткий перерыв, чтобы расслабиться и понаблюдать за этим редким событием. В это время звездный свет будет ярким, но мягким, переходя от тихого зеленого к синему цвету. Любой сотрудник, желающий увидеть эти огни самостоятельно, может отправиться в ближайший к ним район с видом на космос. Надеемся, что вам понравится свет."
	priority_announce("Внимание, [station_name()]. [annus]",
	sound = 'sound/misc/notice2.ogg',
	sender_override = "Отдел метеорологии NanoTrasen")
	for(var/V in GLOB.player_list)
		var/mob/M = V
		if((M.client.prefs.toggles & SOUND_MIDI) && is_station_level(M.z))
			M.playsound_local(M, 'sound/ambience/aurora_caelus.ogg', 20, FALSE, pressure_affected = FALSE)

/datum/round_event/aurora_caelus/start()
	for(var/area in GLOB.sortedAreas)
		var/area/A = area
		if(A.area_flags & AREA_USES_STARLIGHT)
			for(var/turf/open/space/S in A)
				S.set_light(S.light_range * 3, S.light_power * 0.5)
			for(var/turf/open/openspace/S in A)
				S.set_light(S.light_range * 3, S.light_power * 0.5)

/datum/round_event/aurora_caelus/tick()
	if(activeFor % 5 == 0)
		aurora_progress++
		var/aurora_color = aurora_colors[aurora_progress]
		for(var/area in GLOB.sortedAreas)
			var/area/A = area
			if(A.area_flags & AREA_USES_STARLIGHT)
				for(var/turf/open/space/S in A)
					S.set_light(l_color = aurora_color)
				for(var/turf/open/openspace/S in A)
					S.set_light(l_color = aurora_color)

/datum/round_event/aurora_caelus/end()
	for(var/area in GLOB.sortedAreas)
		var/area/A = area
		if(A.area_flags & AREA_USES_STARLIGHT)
			for(var/turf/open/space/S in A)
				fade_to_black(S)
			for(var/turf/open/openspace/S in A)
				fade_to_black(S)
	priority_announce("Событие, связанное с полярным сиянием, заканчивается. Звездный свет постепенно возвращается в нормальное состояние. Возвращайтесь на свое рабочее место и продолжайте работать в обычном режиме. Приятной смены [station_name()] и спасибо, что посмотрели с нами.",
	sound = 'sound/misc/notice2.ogg',
	sender_override = "Отдел метеорологии NanoTrasen")

/datum/round_event/aurora_caelus/proc/fade_to_black(turf/open/space/S)
	set waitfor = FALSE
	var/new_light = initial(S.light_range)
	while(S.light_range > new_light)
		S.set_light(S.light_range - 0.2)
		sleep(30)
	S.set_light(new_light, initial(S.light_power), initial(S.light_color))
