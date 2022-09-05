/atom/var/can_atmos_pass = ATMOS_PASS_YES
/atom/var/can_atmos_passVertical = ATMOS_PASS_YES

/atom/proc/can_atmos_pass(turf/T)
	switch (can_atmos_pass)
		if (ATMOS_PASS_PROC)
			return ATMOS_PASS_YES
		if (ATMOS_PASS_DENSITY)
			return !density
		else
			return can_atmos_pass

/turf/can_atmos_pass = ATMOS_PASS_NO
/turf/can_atmos_passVertical = ATMOS_PASS_NO

/turf/open/can_atmos_pass = ATMOS_PASS_PROC
/turf/open/can_atmos_passVertical = ATMOS_PASS_PROC

/turf/open/can_atmos_pass(turf/T, vertical = FALSE)
	var/dir = vertical? get_dir_multiz(src, T) : get_dir(src, T)
	. = TRUE
	if(vertical && !(zAirOut(dir, T) && T.zAirIn(dir, src)))
		. = FALSE
	if(blocks_air || T.blocks_air)
		. = FALSE
	if (T == src)
		return .
	for(var/obj/O in contents+T.contents)
		var/turf/other = (O.loc == src ? T : src)
		if(!(vertical? (CANVERTICALATMOSPASS(O, other)) : (CANATMOSPASS(O, other))))
			. = FALSE

/turf/proc/update_conductivity(turf/T)
	var/dir = get_dir_multiz(src, T)
	var/opp = REVERSE_DIR(dir)

	if(T == src)
		return

	//all these must be above zero for auxmos to even consider them
	if(!thermal_conductivity || !heat_capacity || !T.thermal_conductivity || !T.heat_capacity)
		conductivity_blocked_directions |= dir
		T.conductivity_blocked_directions |= opp
		return

	for(var/obj/O in contents+T.contents)
		if(O.BlockThermalConductivity(opp)) 	//the direction and open/closed are already checked on CanAtmosPass() so there are no arguments
			conductivity_blocked_directions |= dir
			T.conductivity_blocked_directions |= opp

/atom/movable/proc/BlockThermalConductivity() // Objects that don't let heat through.
	return FALSE

/turf/proc/ImmediateCalculateAdjacentTurfs()
	var/canpass = CANATMOSPASS(src, src)
	var/canvpass = CANVERTICALATMOSPASS(src, src)

	conductivity_blocked_directions = 0

	for(var/direction in GLOB.cardinals_multiz)
		var/turf/T = get_step_multiz(src, direction)
		if(!istype(T))
			conductivity_blocked_directions |= direction
			continue

		var/src_contains_firelock = 1
		if(locate(/obj/machinery/door/firedoor) in src)
			src_contains_firelock |= 2

		var/other_contains_firelock = 1
		if(locate(/obj/machinery/door/firedoor) in T)
			other_contains_firelock |= 2

		update_conductivity(T)

		if(isopenturf(T) && !(blocks_air || T.blocks_air) && ((direction & (UP|DOWN))? (canvpass && CANVERTICALATMOSPASS(T, src)) : (canpass && CANATMOSPASS(T, src))) )
			LAZYINITLIST(atmos_adjacent_turfs)
			LAZYINITLIST(T.atmos_adjacent_turfs)
			atmos_adjacent_turfs[T] = other_contains_firelock
			T.atmos_adjacent_turfs[src] = src_contains_firelock
		else
			if (atmos_adjacent_turfs)
				atmos_adjacent_turfs -= T
			if (T.atmos_adjacent_turfs)
				T.atmos_adjacent_turfs -= src
			UNSETEMPTY(T.atmos_adjacent_turfs)

		T.__update_auxtools_turf_adjacency_info(isspaceturf(T.get_z_base_turf()))
	SEND_SIGNAL(src, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS)
	UNSETEMPTY(atmos_adjacent_turfs)
	src.atmos_adjacent_turfs = atmos_adjacent_turfs
	__update_auxtools_turf_adjacency_info(isspaceturf(get_z_base_turf()))

/turf/proc/__update_auxtools_turf_adjacency_info()

//returns a list of adjacent turfs that can share air with this one.
//alldir includes adjacent diagonal tiles that can share
//	air with both of the related adjacent cardinal tiles
/turf/proc/GetAtmosAdjacentTurfs(alldir = 0)
	var/adjacent_turfs
	if (atmos_adjacent_turfs)
		adjacent_turfs = atmos_adjacent_turfs.Copy()
	else
		adjacent_turfs = list()

	if (!alldir)
		return adjacent_turfs

	var/turf/curloc = src

	for (var/direction in GLOB.diagonals_multiz)
		var/matchingDirections = 0
		var/turf/S = get_step_multiz(curloc, direction)
		if(!S)
			continue

		for (var/checkDirection in GLOB.cardinals_multiz)
			var/turf/checkTurf = get_step(S, checkDirection)
			if(!S.atmos_adjacent_turfs || !S.atmos_adjacent_turfs[checkTurf])
				continue

			if (adjacent_turfs[checkTurf])
				matchingDirections++

			if (matchingDirections >= 2)
				adjacent_turfs += S
				break

	return adjacent_turfs

/atom/proc/air_update_turf()
	if(!get_turf(src))
		return
	var/turf/T = get_turf(src)
	T.air_update_turf()

/turf/air_update_turf()
	ImmediateCalculateAdjacentTurfs()

/atom/movable/proc/move_update_air(turf/T)
    if(isturf(T))
        T.air_update_turf()
    air_update_turf()

/atom/proc/atmos_spawn_air(text) //because a lot of people loves to copy paste awful code lets just make an easy proc to spawn your plasma fires
	var/turf/open/T = get_turf(src)
	if(!istype(T))
		return
	T.atmos_spawn_air(text)

/turf/open/atmos_spawn_air(text)
	if(!text || !air)
		return

	var/datum/gas_mixture/G = new
	G.parse_gas_string(text)
	assume_air(G)
