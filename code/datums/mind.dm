/*	Note from Carnie:
		The way datum/mind stuff works has been changed a lot.
		Minds now represent IC characters rather than following a client around constantly.

	Guidelines for using minds properly:

	-	Never mind.transfer_to(ghost). The var/current and var/original of a mind must always be of type mob/living!
		ghost.mind is however used as a reference to the ghost's corpse

	-	When creating a new mob for an existing IC character (e.g. cloning a dead guy or borging a brain of a human)
		the existing mind of the old mob should be transfered to the new mob like so:

			mind.transfer_to(new_mob)

	-	You must not assign key= or ckey= after transfer_to() since the transfer_to transfers the client for you.
		By setting key or ckey explicitly after transferring the mind with transfer_to you will cause bugs like DCing
		the player.

	-	IMPORTANT NOTE 2, if you want a player to become a ghost, use mob.ghostize() It does all the hard work for you.

	-	When creating a new mob which will be a new IC character (e.g. putting a shade in a construct or randomly selecting
		a ghost to become a xeno during an event). Simply assign the key or ckey like you've always done.

			new_mob.key = key

		The Login proc will handle making a new mind for that mobtype (including setting up stuff like mind.name). Simple!
		However if you want that mind to have any special properties like being a traitor etc you will have to do that
		yourself.

*/

/datum/mind
	var/key
	var/name				//replaces mob/var/original_name
	var/ghostname			//replaces name for observers name if set
	var/mob/living/current
	var/active = FALSE

	var/memory

	var/assigned_role
	var/special_role
	var/list/restricted_roles = list()
	var/list/datum/objective/objectives = list()

	var/linglink
	var/datum/martial_art/martial_art
	var/static/default_martial_art = new/datum/martial_art
	var/miming = FALSE // Mime's vow of silence
	var/list/antag_datums
	///this mind's ANTAG_HUD should have this icon_state
	var/antag_hud_icon_state = null
	///this mind's antag HUD
	var/datum/atom_hud/alternate_appearance/basic/antagonist_hud/antag_hud = null
	var/damnation_type = 0
	var/datum/mind/soulOwner //who owns the soul.  Under normal circumstances, this will point to src
	var/hasSoul = TRUE // If false, renders the character unable to sell their soul.
	var/holy_role = NONE //is this person a chaplain or admin role allowed to use bibles, Any rank besides 'NONE' allows for this.

	///If this mind's master is another mob (i.e. adamantine golems)
	var/mob/living/enslaved_to
	var/datum/language_holder/language_holder
	var/unconvertable = FALSE
	var/late_joiner = FALSE

	var/last_death = 0

	var/force_escaped = FALSE  // Set by Into The Sunset command of the shuttle manipulator

	var/list/learned_recipes //List of learned recipe TYPES.

	///List of skills the user has received a reward for. Should not be used to keep track of currently known skills. Lazy list because it shouldnt be filled often
	var/list/skills_rewarded
	///Assoc list of skills. Use SKILL_LVL to access level, and SKILL_EXP to access skill's exp.
	var/list/known_skills = list()
	///Weakref to thecharacter we joined in as- either at roundstart or latejoin, so we know for persistent scars if we ended as the same person or not
	var/datum/weakref/original_character
	/// The index for what character slot, if any, we were loaded from, so we can track persistent scars on a per-character basis. Each character slot gets PERSISTENT_SCAR_SLOTS scar slots
	var/original_character_slot_index
	/// The index for our current scar slot, so we don't have to constantly check the savefile (unlike the slots themselves, this index is independent of selected char slot, and increments whenever a valid char is joined with)
	var/current_scar_slot_index

	///Skill multiplier, adjusts how much xp you get/loose from adjust_xp. Dont override it directly, add your reason to experience_multiplier_reasons and use that as a key to put your value in there.
	var/experience_multiplier = 1
	///Skill multiplier list, just slap your multiplier change onto this with the type it is coming from as key.
	var/list/experience_multiplier_reasons = list()

	/// A lazy list of statuses to add next to this mind in the traitor panel
	var/list/special_statuses

	///Assoc list of addiction values, key is the type of withdrawal (as singleton type), and the value is the amount of addiction points (as number)
	var/list/addiction_points
	///Assoc list of key active addictions and value amount of cycles that it has been active.
	var/list/active_addictions

/datum/mind/New(_key)
	key = _key
	src.key = _key
	soulOwner = src
	martial_art = default_martial_art
	init_known_skills()

/datum/mind/Destroy()
	SSticker.minds -= src
	QDEL_NULL(antag_hud)
	QDEL_LIST(antag_datums)
	QDEL_NULL(language_holder)
	set_current(null)
	return ..()

/datum/mind/proc/set_current(mob/new_current)
	if(new_current && QDELETED(new_current))
		CRASH("Tried to set a mind's current var to a qdeleted mob, what the fuck")
	if(current)
		UnregisterSignal(src, COMSIG_PARENT_QDELETING)
	current = new_current
	if(current)
		RegisterSignal(src, COMSIG_PARENT_QDELETING, .proc/clear_current)

/datum/mind/proc/clear_current(datum/source)
	SIGNAL_HANDLER
	set_current(null)

/datum/mind/proc/get_language_holder()
	if(!language_holder)
		language_holder = new (src)
	return language_holder

/datum/mind/proc/transfer_to(mob/new_character, force_key_move = 0)
	set_original_character(null)
	if(current) // remove ourself from our old body's mind variable
		current.mind = null
		UnregisterSignal(current, COMSIG_LIVING_DEATH)
		SStgui.on_transfer(current, new_character)

	if(key)
		if(new_character.key != key)					//if we're transferring into a body with a key associated which is not ours
			new_character.ghostize(1)						//we'll need to ghostize so that key isn't mobless.
	else
		key = new_character.key

	if(new_character.mind) //disassociate any mind currently in our new body's mind variable
		new_character.mind.set_current(null)

	var/mob/living/old_current = current
	if(current)
		current.transfer_observers_to(new_character) //transfer anyone observing the old character to the new one
	set_current(new_character) //associate ourself with our new body
	QDEL_NULL(antag_hud)
	new_character.mind = src //and associate our new body with ourself
	antag_hud = new_character.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/antagonist_hud, "combo_hud", src)
	for(var/a in antag_datums) //Makes sure all antag datums effects are applied in the new body
		var/datum/antagonist/A = a
		A.on_body_transfer(old_current, current)
	if(iscarbon(new_character))
		var/mob/living/carbon/C = new_character
		C.last_mind = src
	transfer_martial_arts(new_character)
	RegisterSignal(new_character, COMSIG_LIVING_DEATH, .proc/set_death_time)
	if(active || force_key_move)
		new_character.key = key		//now transfer the key to link the client to our new body
	if(new_character.client)
		LAZYCLEARLIST(new_character.client.recent_examines)
		new_character.client.init_verbs() // re-initialize character specific verbs
	current.update_atom_languages()

//I cannot trust you fucks to do this properly
/datum/mind/proc/set_original_character(new_original_character)
	original_character = WEAKREF(new_original_character)

/datum/mind/proc/init_known_skills()
	for (var/type in GLOB.skill_types)
		known_skills[type] = list(SKILL_LEVEL_NONE, 0)

///Return the amount of EXP needed to go to the next level. Returns 0 if max level
/datum/mind/proc/exp_needed_to_level_up(skill)
	var/lvl = update_skill_level(skill)
	if (lvl >= length(SKILL_EXP_LIST)) //If we're already past the last exp threshold
		return 0
	return SKILL_EXP_LIST[lvl+1] - known_skills[skill][SKILL_EXP]

///Adjust experience of a specific skill
/datum/mind/proc/adjust_experience(skill, amt, silent = FALSE, force_old_level = 0)
	var/datum/skill/S = GetSkillRef(skill)
	var/old_level = force_old_level ? force_old_level : known_skills[skill][SKILL_LVL] //Get current level of the S skill
	experience_multiplier = initial(experience_multiplier)
	for(var/key in experience_multiplier_reasons)
		experience_multiplier += experience_multiplier_reasons[key]
	known_skills[skill][SKILL_EXP] = max(0, known_skills[skill][SKILL_EXP] + amt*experience_multiplier) //Update exp. Prevent going below 0
	known_skills[skill][SKILL_LVL] = update_skill_level(skill)//Check what the current skill level is based on that skill's exp
	if(silent)
		return
	if(known_skills[skill][SKILL_LVL] > old_level)
		S.level_gained(src, known_skills[skill][SKILL_LVL], old_level)
	else if(known_skills[skill][SKILL_LVL] < old_level)
		S.level_lost(src, known_skills[skill][SKILL_LVL], old_level)

///Set experience of a specific skill to a number
/datum/mind/proc/set_experience(skill, amt, silent = FALSE)
	var/old_level = known_skills[skill][SKILL_EXP]
	known_skills[skill][SKILL_EXP] = amt
	adjust_experience(skill, 0, silent, old_level) //Make a call to adjust_experience to handle updating level

///Set level of a specific skill
/datum/mind/proc/set_level(skill, newlevel, silent = FALSE)
	var/oldlevel = get_skill_level(skill)
	var/difference = SKILL_EXP_LIST[newlevel] - SKILL_EXP_LIST[oldlevel]
	adjust_experience(skill, difference, silent)

///Check what the current skill level is based on that skill's exp
/datum/mind/proc/update_skill_level(skill)
	var/i = 0
	for (var/exp in SKILL_EXP_LIST)
		i ++
		if (known_skills[skill][SKILL_EXP] >= SKILL_EXP_LIST[i])
			continue
		return i - 1 //Return level based on the last exp requirement that we were greater than
	return i //If we had greater EXP than even the last exp threshold, we return the last level

///Gets the skill's singleton and returns the result of its get_skill_modifier
/datum/mind/proc/get_skill_modifier(skill, modifier)
	var/datum/skill/S = GetSkillRef(skill)
	return S.get_skill_modifier(modifier, known_skills[skill][SKILL_LVL])

///Gets the player's current level number from the relevant skill
/datum/mind/proc/get_skill_level(skill)
	return known_skills[skill][SKILL_LVL]

///Gets the player's current exp from the relevant skill
/datum/mind/proc/get_skill_exp(skill)
	return known_skills[skill][SKILL_EXP]

/datum/mind/proc/get_skill_level_name(skill)
	var/level = get_skill_level(skill)
	return SSskills.level_names[level]

/datum/mind/proc/print_levels(user)
	var/list/shown_skills = list()
	for(var/i in known_skills)
		if(known_skills[i][SKILL_LVL] > SKILL_LEVEL_NONE) //Do we actually have a level in this?
			shown_skills += i
	if(!length(shown_skills))
		to_chat(user, span_notice("Да у меня и нет каких-то особых навыков."))
		return
	var/msg = "<span class='info'><EM>Мои навыки</EM></span>\n<span class='notice'>"
	for(var/i in shown_skills)
		var/datum/skill/the_skill = i
		msg += "[initial(the_skill.name)] - [get_skill_level_name(the_skill)]\n"
	msg += "</span>"
	to_chat(user, "<div class='examine_block'>[msg]</div>")

/datum/mind/proc/set_death_time()
	SIGNAL_HANDLER

	last_death = world.time

/datum/mind/proc/store_memory(new_text)
	var/newlength = length_char(memory) + length_char(new_text)
	if (newlength > MAX_MESSAGE_LEN * 100)
		memory = copytext_char(memory, -newlength-MAX_MESSAGE_LEN * 100)
	memory += "[new_text]<BR>"

/datum/mind/proc/wipe_memory()
	memory = null

// Datum antag mind procs
/datum/mind/proc/add_antag_datum(datum_type_or_instance, team)
	if(!datum_type_or_instance)
		return
	var/datum/antagonist/A
	if(!ispath(datum_type_or_instance))
		A = datum_type_or_instance
		if(!istype(A))
			return
	else
		A = new datum_type_or_instance()
	//Choose snowflake variation if antagonist handles it
	var/datum/antagonist/S = A.specialization(src)
	if(S && S != A)
		qdel(A)
		A = S
	if(!A.can_be_owned(src))
		qdel(A)
		return
	A.owner = src
	LAZYADD(antag_datums, A)
	A.create_team(team)
	var/datum/team/antag_team = A.get_team()
	if(antag_team)
		antag_team.add_member(src)
	INVOKE_ASYNC(A, /datum/antagonist.proc/on_gain)
	log_game("[key_name(src)] has gained antag datum [A.name]([A.type])")
	return A

/datum/mind/proc/remove_antag_datum(datum_type)
	if(!datum_type)
		return
	var/datum/antagonist/A = has_antag_datum(datum_type)
	if(A)
		A.on_removal()
		return TRUE


/datum/mind/proc/remove_all_antag_datums() //For the Lazy amongst us.
	for(var/a in antag_datums)
		var/datum/antagonist/A = a
		A.on_removal()

/datum/mind/proc/has_antag_datum(datum_type, check_subtypes = TRUE)
	if(!datum_type)
		return
	for(var/a in antag_datums)
		var/datum/antagonist/A = a
		if(check_subtypes && istype(A, datum_type))
			return A
		else if(A.type == datum_type)
			return A

/*
	Removes antag type's references from a mind.
	objectives, uplinks, powers etc are all handled.
*/

/datum/mind/proc/remove_changeling()
	var/datum/antagonist/changeling/C = has_antag_datum(/datum/antagonist/changeling)
	if(C)
		remove_antag_datum(/datum/antagonist/changeling)
		special_role = null

/datum/mind/proc/remove_traitor()
	remove_antag_datum(/datum/antagonist/traitor)
/*
/datum/mind/proc/remove_brother()
	if(src in SSticker.mode.brothers)
		remove_antag_datum(/datum/antagonist/brother)
*/
/datum/mind/proc/remove_nukeop()
	var/datum/antagonist/nukeop/nuke = has_antag_datum(/datum/antagonist/nukeop,TRUE)
	if(nuke)
		remove_antag_datum(nuke.type)
		special_role = null

/datum/mind/proc/remove_wizard()
	remove_antag_datum(/datum/antagonist/wizard)
	special_role = null

/datum/mind/proc/remove_cultist()
	if(src in SSticker.mode.cult)
		SSticker.mode.remove_cultist(src, 0, 0)
	special_role = null
	remove_antag_equip()

/datum/mind/proc/remove_rev()
	var/datum/antagonist/rev/rev = has_antag_datum(/datum/antagonist/rev)
	if(rev)
		remove_antag_datum(rev.type)
		special_role = null


/datum/mind/proc/remove_antag_equip()
	var/list/Mob_Contents = current.get_contents()
	for(var/obj/item/I in Mob_Contents)
		var/datum/component/uplink/O = I.GetComponent(/datum/component/uplink) //Todo make this reset signal
		if(O)
			O.unlock_code = null

/datum/mind/proc/remove_all_antag() //For the Lazy amongst us.
	remove_changeling()
	remove_traitor()
	remove_nukeop()
	remove_wizard()
	remove_cultist()
	remove_rev()

/datum/mind/proc/equip_traitor(employer = "Синдикат", silent = FALSE, datum/antagonist/uplink_owner)
	if(!current)
		return
	var/mob/living/carbon/human/traitor_mob = current
	if (!istype(traitor_mob))
		return

	var/list/all_contents = traitor_mob.get_all_contents()
	var/obj/item/modular_computer/tablet/pda/PDA = locate() in all_contents
	var/obj/item/radio/R = locate() in all_contents
	var/obj/item/pen/P

	if (PDA) // Prioritize PDA pen, otherwise the pocket protector pens will be chosen, which causes numerous ahelps about missing uplink
		P = locate() in PDA
	if (!P) // If we couldn't find a pen in the PDA, or we didn't even have a PDA, do it the old way
		P = locate() in all_contents

	var/obj/item/uplink_loc
	var/implant = FALSE

	if(traitor_mob.client && traitor_mob.client.prefs)
		switch(traitor_mob.client.prefs.uplink_spawn_loc)
			if(UPLINK_PDA)
				uplink_loc = PDA
				if(!uplink_loc)
					uplink_loc = R
				if(!uplink_loc)
					uplink_loc = P
			if(UPLINK_RADIO)
				uplink_loc = R
				if(!uplink_loc)
					uplink_loc = PDA
				if(!uplink_loc)
					uplink_loc = P
			if(UPLINK_PEN)
				uplink_loc = P
			if(UPLINK_IMPLANT)
				implant = TRUE

	if(!uplink_loc) // We've looked everywhere, let's just implant you
		implant = TRUE

	if (!implant)
		. = uplink_loc
		var/datum/component/uplink/U = uplink_loc.AddComponent(/datum/component/uplink, traitor_mob.key)
		if(!U)
			CRASH("Uplink creation failed.")
		U.setup_unlock_code()
		if(!silent)
			if(uplink_loc == R)
				to_chat(traitor_mob, span_boldnotice("[employer] хитро замаскировал аплинк в [R.name]. Нужно только выбрать частоту [format_frequency(U.unlock_code)], чтобы получить доступ к нему."))
			else if(uplink_loc == PDA)
				to_chat(traitor_mob, span_boldnotice("[employer] хитро замаскировал аплинк в [PDA.name]. Нужно ввести код \"[U.unlock_code]\" как рингтон, чтобы получить доступ к нему."))
			else if(uplink_loc == P)
				to_chat(traitor_mob, span_boldnotice("[employer] хитро замаскировал аплинк в [P.name]. Нужно просто покрутить головку ручки [english_list(U.unlock_code)] со стартовой позиции, чтобы получить доступ к нему."))

		if(uplink_owner)
			uplink_owner.antag_memory += U.unlock_note + "<br>"
		else
			traitor_mob.mind.store_memory(U.unlock_note)
	else
		var/obj/item/implant/uplink/starting/I = new(traitor_mob)
		I.implant(traitor_mob, null, silent = TRUE)
		if(!silent)
			to_chat(traitor_mob, span_boldnotice("[employer] has cunningly implanted you with a Syndicate Uplink (although uplink implants cost valuable TC, so you will have slightly less). Simply trigger the uplink to access it."))
		return I



//Link a new mobs mind to the creator of said mob. They will join any team they are currently on, and will only switch teams when their creator does.

/datum/mind/proc/enslave_mind_to_creator(mob/living/creator)
	if(iscultist(creator))
		SSticker.mode.add_cultist(src)

	else if(is_servant_of_ratvar(creator))
		add_servant_of_ratvar(src)

	else if(is_revolutionary(creator))
		var/datum/antagonist/rev/converter = creator.mind.has_antag_datum(/datum/antagonist/rev,TRUE)
		converter.add_revolutionary(src,FALSE)

	else if(is_nuclear_operative(creator))
		var/datum/antagonist/nukeop/converter = creator.mind.has_antag_datum(/datum/antagonist/nukeop,TRUE)
		var/datum/antagonist/nukeop/N = new()
		N.send_to_spawnpoint = FALSE
		N.nukeop_outfit = null
		add_antag_datum(N,converter.nuke_team)


	enslaved_to = creator

	current.faction |= creator.faction
	creator.faction |= current.faction

	if(creator.mind.special_role)
		message_admins("[ADMIN_LOOKUPFLW(current)] has been created by [ADMIN_LOOKUPFLW(creator)], an antagonist.")
		to_chat(current, span_userdanger("Несмотря на преданность своим создателям, мой истинный хозяин <b>[creator.real_name]</b>. Если их лояльность изменится, изменится и моя. Это никогда не сменится, пока тело моего создателя не будет уничтожено."))

/datum/mind/proc/show_memory(mob/recipient, window=1)
	if(!recipient)
		recipient = current
	var/output = ""
	if(window)
		output += "<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8'><title>Воспоминания [current.real_name]</title></head>"
	else
		output += "<B>Воспоминания [current.real_name]:</B><br>"
	output += memory


	var/list/all_objectives = list()
	for(var/datum/antagonist/A in antag_datums)
		output += A.task_memory
		output += A.antag_memory
		all_objectives |= A.objectives

	if(all_objectives.len)
		output += "<B>Цели:</B>"
		var/obj_count = 1
		for(var/datum/objective/objective in all_objectives)
			output += "<br><B>Цель #[obj_count++]</B>: [objective.explanation_text]"
			var/list/datum/mind/other_owners = objective.get_owners() - src
			if(other_owners.len)
				output += "<ul>"
				for(var/datum/mind/M in other_owners)
					output += "<li>Сообщник: [M.name]</li>"
				output += "</ul>"

	if(window)
		output += "</body></html>"
		var/datum/browser/popup = new(recipient, "memory", "Воспоминания [current.real_name]", 350, 350)
		popup.set_content(output)
		popup.open()
	else if(all_objectives.len || memory)
		to_chat(recipient, "<i>[output]</i>")

/datum/mind/Topic(href, href_list)
	if(!check_rights(R_FUN))
		return

	var/self_antagging = usr == current

	if(href_list["add_antag"])
		add_antag_wrapper(text2path(href_list["add_antag"]),usr)
	if(href_list["remove_antag"])
		var/datum/antagonist/A = locate(href_list["remove_antag"]) in antag_datums
		if(!istype(A))
			to_chat(usr,span_warning("Invalid antagonist ref to be removed."))
			return
		A.admin_remove(usr)

	if (href_list["role_edit"])
		var/new_role = tgui_input_list(usr, "Select new role", "Assigned role", sort_list(SSjob.station_jobs), assigned_role)
		if (!new_role)
			return
		assigned_role = new_role

	else if (href_list["memory_edit"])
		var/new_memo = stripped_multiline_input(usr, "Write new memory", "Memory", memory, MAX_MESSAGE_LEN)
		if (isnull(new_memo))
			return
		memory = new_memo

	else if (href_list["obj_edit"] || href_list["obj_add"])
		var/objective_pos //Edited objectives need to keep same order in antag objective list
		var/def_value
		var/datum/antagonist/target_antag
		var/datum/objective/old_objective //The old objective we're replacing/editing
		var/datum/objective/new_objective //New objective we're be adding

		if(href_list["obj_edit"])
			for(var/datum/antagonist/A in antag_datums)
				old_objective = locate(href_list["obj_edit"]) in A.objectives
				if(old_objective)
					target_antag = A
					objective_pos = A.objectives.Find(old_objective)
					break
			if(!old_objective)
				to_chat(usr,"Invalid objective.")
				return
		else
			if(href_list["target_antag"])
				var/datum/antagonist/X = locate(href_list["target_antag"]) in antag_datums
				if(X)
					target_antag = X
			if(!target_antag)
				switch(antag_datums.len)
					if(0)
						target_antag = add_antag_datum(/datum/antagonist/custom)
					if(1)
						target_antag = antag_datums[1]
					else
						var/datum/antagonist/target = tgui_input_list(usr, "Which antagonist gets the objective:", "Antagonist", sort_list(antag_datums) + "(new custom antag)", "(new custom antag)")
						if (QDELETED(target))
							return
						else if(target == "(new custom antag)")
							target_antag = add_antag_datum(/datum/antagonist/custom)
						else
							target_antag = target

		if(!GLOB.admin_objective_list)
			generate_admin_objective_list()

		if(old_objective)
			if(old_objective.name in GLOB.admin_objective_list)
				def_value = old_objective.name

		var/selected_type = tgui_input_list(usr, "Select objective type:", "Objective type", GLOB.admin_objective_list, def_value)
		selected_type = GLOB.admin_objective_list[selected_type]
		if (!selected_type)
			return

		if(!old_objective)
			//Add new one
			new_objective = new selected_type
			new_objective.owner = src
			new_objective.admin_edit(usr)
			target_antag.objectives += new_objective
			message_admins("[key_name_admin(usr)] added a new objective for [current]: [new_objective.explanation_text]")
			log_admin("[key_name(usr)] added a new objective for [current]: [new_objective.explanation_text]")
		else
			if(old_objective.type == selected_type)
				//Edit the old
				old_objective.admin_edit(usr)
				new_objective = old_objective
			else
				//Replace the old
				new_objective = new selected_type
				new_objective.owner = src
				new_objective.admin_edit(usr)
				target_antag.objectives -= old_objective
				target_antag.objectives.Insert(objective_pos, new_objective)
			message_admins("[key_name_admin(usr)] edited [current] objective to [new_objective.explanation_text]")
			log_admin("[key_name(usr)] edited [current] objective to [new_objective.explanation_text]")

	else if (href_list["obj_delete"])
		var/datum/objective/objective
		for(var/datum/antagonist/A in antag_datums)
			objective = locate(href_list["obj_delete"]) in A.objectives
			if(istype(objective))
				A.objectives -= objective
				break
		if(!objective)
			to_chat(usr,"Invalid objective.")
			return
		//qdel(objective) Needs cleaning objective destroys
		message_admins("[key_name_admin(usr)] removed an objective for [current]: [objective.explanation_text]")
		log_admin("[key_name(usr)] removed an objective for [current]: [objective.explanation_text]")

	else if(href_list["obj_completed"])
		var/datum/objective/objective
		for(var/datum/antagonist/A in antag_datums)
			objective = locate(href_list["obj_completed"]) in A.objectives
			if(istype(objective))
				objective = objective
				break
		if(!objective)
			to_chat(usr,"Invalid objective.")
			return
		objective.completed = !objective.completed
		log_admin("[key_name(usr)] toggled the win state for [current] objective: [objective.explanation_text]")

	else if (href_list["silicon"])
		switch(href_list["silicon"])
			if("unemag")
				var/mob/living/silicon/robot/R = current
				if (istype(R))
					R.SetEmagged(0)
					message_admins("[key_name_admin(usr)] has unemag'ed [R].")
					log_admin("[key_name(usr)] has unemag'ed [R].")

			if("unemagcyborgs")
				if(isAI(current))
					var/mob/living/silicon/ai/ai = current
					for (var/mob/living/silicon/robot/R in ai.connected_robots)
						R.SetEmagged(0)
					message_admins("[key_name_admin(usr)] has unemag'ed [ai] Cyborgs.")
					log_admin("[key_name(usr)] has unemag'ed [ai] Cyborgs.")

	else if (href_list["common"])
		switch(href_list["common"])
			if("undress")
				for(var/obj/item/W in current)
					current.dropItemToGround(W, TRUE) //The TRUE forces all items to drop, since this is an admin undress.
			if("takeuplink")
				take_uplink()
				memory = null//Remove any memory they may have had.
				log_admin("[key_name(usr)] removed [current] uplink.")
			if("crystals")
				if(check_rights(R_FUN, 0))
					var/datum/component/uplink/U = find_syndicate_uplink()
					if(U)
						var/crystals = input("Amount of telecrystals for [key]","Syndicate uplink", U.telecrystals) as null | num
						if(!isnull(crystals))
							U.telecrystals = crystals
							message_admins("[key_name_admin(usr)] changed [current] telecrystal count to [crystals].")
							log_admin("[key_name(usr)] changed [current] telecrystal count to [crystals].")
			if("uplink")
				if(!equip_traitor())
					to_chat(usr, span_danger("Equipping a syndicate failed!"))
					log_admin("[key_name(usr)] tried and failed to give [current] an uplink.")
				else
					log_admin("[key_name(usr)] gave [current] an uplink.")

	else if (href_list["obj_announce"])
		announce_objectives()

	//Something in here might have changed your mob
	if(self_antagging && (!usr || !usr.client) && current.client)
		usr = current
	traitor_panel()


/datum/mind/proc/get_all_objectives()
	var/list/all_objectives = list()
	for(var/datum/antagonist/A in antag_datums)
		all_objectives |= A.objectives
	return all_objectives

/datum/mind/proc/announce_objectives()
	var/obj_count = 1
	to_chat(current, span_notice("Мои текущие цели:"))
	for(var/objective in get_all_objectives())
		var/datum/objective/O = objective
		to_chat(current, "<B>Цель #[obj_count]</B>: [O.explanation_text]")
		obj_count++

/datum/mind/proc/find_syndicate_uplink()
	var/list/L = current.get_all_contents()
	for (var/i in L)
		var/atom/movable/I = i
		. = I.GetComponent(/datum/component/uplink)
		if(.)
			break

/datum/mind/proc/take_uplink()
	qdel(find_syndicate_uplink())

/datum/mind/proc/make_Traitor()
	if(!(has_antag_datum(/datum/antagonist/traitor)))
		add_antag_datum(/datum/antagonist/traitor)

/datum/mind/proc/make_Contractor_Support()
	if(!(has_antag_datum(/datum/antagonist/traitor/contractor_support)))
		add_antag_datum(/datum/antagonist/traitor/contractor_support)

/datum/mind/proc/make_Changeling()
	var/datum/antagonist/changeling/C = has_antag_datum(/datum/antagonist/changeling)
	if(!C)
		C = add_antag_datum(/datum/antagonist/changeling)
		special_role = ROLE_CHANGELING
	return C

/datum/mind/proc/make_Wizard()
	if(!has_antag_datum(/datum/antagonist/wizard))
		special_role = ROLE_WIZARD
		assigned_role = ROLE_WIZARD
		add_antag_datum(/datum/antagonist/wizard)


/datum/mind/proc/make_Cultist()
	if(!has_antag_datum(/datum/antagonist/cult,TRUE))
		SSticker.mode.add_cultist(src,FALSE,equip=TRUE)
		special_role = ROLE_CULTIST
		to_chat(current, "<font color=\"purple\"><b><i>You catch a glimpse of the Realm of Nar'Sie, The Geometer of Blood. You now see how flimsy your world is, you see that it should be open to the knowledge of Nar'Sie.</b></i></font>")
		to_chat(current, "<font color=\"purple\"><b><i>Assist your new brethren in their dark dealings. Their goal is yours, and yours is theirs. You serve the Dark One above all else. Bring It back.</b></i></font>")

/datum/mind/proc/make_Rev()
	var/datum/antagonist/rev/head/head = new()
	head.give_flash = TRUE
	head.give_hud = TRUE
	add_antag_datum(head)
	special_role = ROLE_REV_HEAD

/datum/mind/proc/make_Dreamer()
	if(!(has_antag_datum(/datum/antagonist/dreamer)))
		add_antag_datum(/datum/antagonist/dreamer)

/datum/mind/proc/transfer_martial_arts(mob/living/new_character)
	if(!ishuman(new_character))
		return
	if(martial_art)
		if(martial_art.base) //Is the martial art temporary?
			martial_art.remove(new_character)
		else
			martial_art.teach(new_character)

/datum/mind/proc/get_ghost(even_if_they_cant_reenter, ghosts_with_clients)
	for(var/mob/dead/observer/G in (ghosts_with_clients ? GLOB.player_list : GLOB.dead_mob_list))
		if(G.mind == src)
			if(G.can_reenter_corpse || even_if_they_cant_reenter)
				return G
			break
/*
/datum/mind/proc/grab_ghost(force)
	var/mob/dead/observer/G = get_ghost(even_if_they_cant_reenter = force)
	. = G
	if(G)
		G.reenter_corpse()
*/
/// Sets our can_hijack to the fastest speed our antag datums allow.
/datum/mind/proc/get_hijack_speed()
	. = 0
	for(var/datum/antagonist/A in antag_datums)
		. = max(., A.hijack_speed())

/datum/mind/proc/has_objective(objective_type)
	for(var/datum/antagonist/A in antag_datums)
		for(var/O in A.objectives)
			if(istype(O,objective_type))
				return TRUE

/mob/proc/sync_mind()
	mind_initialize()	//updates the mind (or creates and initializes one if one doesn't exist)
	mind.active = TRUE	//indicates that the mind is currently synced with a client

/datum/mind/proc/has_martialart(string)
	if(martial_art && martial_art.id == string)
		return martial_art
	return FALSE

///Adds addiction points to the specified addiction
/datum/mind/proc/add_addiction_points(type, amount)
	LAZYSET(addiction_points, type, min(LAZYACCESS(addiction_points, type) + amount, MAX_ADDICTION_POINTS))
	var/datum/addiction/affected_addiction = SSaddiction.all_addictions[type]
	return affected_addiction.on_gain_addiction_points(src)

///Adds addiction points to the specified addiction
/datum/mind/proc/remove_addiction_points(type, amount)
	LAZYSET(addiction_points, type, max(LAZYACCESS(addiction_points, type) - amount, 0))
	var/datum/addiction/affected_addiction = SSaddiction.all_addictions[type]
	return affected_addiction.on_lose_addiction_points(src)

/mob/dead/new_player/sync_mind()
	return

/mob/dead/observer/sync_mind()
	return

//Initialisation procs
/mob/proc/mind_initialize()
	if(mind)
		mind.key = key

	else
		mind = new /datum/mind(key)
		SSticker.minds += mind
	if(!mind.name)
		mind.name = real_name
	mind.set_current(src)

/mob/living/carbon/mind_initialize()
	..()
	last_mind = mind

//HUMAN
/mob/living/carbon/human/mind_initialize()
	..()
	if(!mind.assigned_role)
		mind.assigned_role = "Unassigned" //default

//AI
/mob/living/silicon/ai/mind_initialize()
	..()
	mind.assigned_role = JOB_AI

//BORG
/mob/living/silicon/robot/mind_initialize()
	..()
	mind.assigned_role = JOB_CYBORG

//PAI
/mob/living/silicon/pai/mind_initialize()
	..()
	mind.assigned_role = ROLE_PAI
	mind.special_role = ""
