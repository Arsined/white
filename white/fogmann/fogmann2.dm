//KAMA THE BULLET martials

/datum/martial_art/shaitanka
	name = "shaitanka mma movements"
	id = MARTIALART_DAGESTAN
	var/datum/action/taa/taa = new/datum/action/taa()
	var/datum/action/shaa/shaa = new/datum/action/shaa()
	var/datum/action/progib/progib = new/datum/action/progib()
	var/datum/action/uatknut/uatknut = new/datum/action/uatknut()

/datum/martial_art/shaitanka/proc/check_streak(mob/living/carbon/human/A, mob/living/carbon/human/D)
	switch(streak)
		if("taa")
			streak = ""
			taa(A,D)
			return TRUE
		if("shaa")
			streak = ""
			shaa(A,D)
			return TRUE
		if("progib")
			streak = ""
			progib(A,D)
			return TRUE
		if("uatknut")
			streak = ""
			uatknut(A,D)
			return TRUE
	return FALSE

/datum/action/uatknut
	name = "Уаткнуть (с захватом) - Уаткнуть очкушника в землю."
	button_icon_state = "wrassle_slam"

/datum/action/uatknut/Trigger(trigger_flags)
	if(owner.incapacitated())
		to_chat(owner, "<span class='warning'>Ты не можешь уаткнуть уже уоткнутого.</span>")
		return
	owner.visible_message("<span class='danger'>[owner] собирается кого-то уаткнуть!</span>" , "<b><i>Твой следующий прием - уаткнуть.</i></b>")
	var/mob/living/carbon/human/H = owner
	H.mind.martial_art.streak = "uatknut"

/datum/action/progib
	name = "Прогиб (с захватом) - кинуть чмошь на прогиб."
	button_icon_state = "wrassle_throw"

/datum/action/progib/Trigger(trigger_flags)
	if(owner.incapacitated())
		to_chat(owner, "<span class='warning'>Ты не можешь кинуть на прогиб лежачего.</span>")
		return
	owner.visible_message("<span class='danger'>[owner] собирается кинуть неверного!</span>" , "<b><i>Твой следующий прием - кинуть на прогиб.</i></b>")
	var/mob/living/carbon/human/H = owner
	H.mind.martial_art.streak = "progib"

/datum/action/taa
	name = "ТАА - Сейчас вы уебете кого-то макасином по лицу."
	button_icon_state = "wrassle_kick"

/datum/action/taa/Trigger(trigger_flags)

	owner.visible_message("<span class='danger'>[owner] орет ТАА!</span>" , "<b><i>Сейчас вы уебете кого-то макасином по лицу.</i></b>")
	var/mob/living/carbon/human/H = owner
	H.mind.martial_art.streak = "taa"

/datum/action/shaa
	name = "ШАА - дать чапалаха уцику."
	button_icon_state = "wrassle_strike"

/datum/action/shaa/Trigger(trigger_flags)
	owner.visible_message("<span class='danger'>[owner] готов отвесить ЧАПАЛАХ!</span>" , "<b><i>Твой следующий удар - ЧАПАЛАХ.</i></b>")
	var/mob/living/carbon/human/H = owner
	H.mind.martial_art.streak = "shaa"


/datum/martial_art/shaitanka/teach(mob/living/carbon/human/H,make_temporary=0)
	if(..())
		to_chat(H, "<span class='userdanger'>ПОСАДИ ВСЕХ НА БУТЫЛКУ!</span>")
		to_chat(H, "<span class='danger'>Наведи курсор на иконку, чтобы узнать о своих приемах.</span>")
		uatknut.Grant(H)
		progib.Grant(H)
		taa.Grant(H)
		shaa.Grant(H)

/datum/martial_art/shaitanka/on_remove(mob/living/carbon/human/H)
	to_chat(H, "<span class='userdanger'>Чувствую вкус аромат коровьего навоза и бутылку в анальном проходе</span>")
	uatknut.Remove(H)
	progib.Remove(H)
	taa.Remove(H)
	shaa.Remove(H)

/datum/martial_art/shaitanka/harm_act(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(check_streak(A,D))
		return 1
	log_combat(A, D, "punched with shaitanka")
	..()

/datum/martial_art/shaitanka/proc/progib(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(!D)
		return
	if(!A.pulling || A.pulling != D)
		to_chat(A, "<span class='warning'>Уазьми [D] iв захват!</span>")
		return
	D.forceMove(A.loc)
	D.setDir(get_dir(D, A))

	D.Stun(80)
	D.visible_message("<span class='danger'>[A] кидает на прогиб [D]!</span>" , \
					"<span class='userdanger'>Меня кидает на прогиб [A]!</span>" , "<span class='hear'>Слышу звук трещащих костей!</span>" , null, A)
	to_chat(A, "<span class='danger'>Кидаю на прогиб [D]!</span>")
	A.emote("agony")


	for (var/i = 0, i < 3, i++)
		if (A && D)
			A.pixel_y += 3
			D.pixel_y += 3
			A.setDir(turn(A.dir, 1))
			D.setDir(turn(D.dir, 1))

			switch (A.dir)
				if (NORTH)
					D.pixel_x = A.pixel_x
				if (SOUTH)
					D.pixel_x = A.pixel_x
				if (EAST)
					D.pixel_x = A.pixel_x - 8
				if (WEST)
					D.pixel_x = A.pixel_x + 8

			if (get_dist(A, D) > 1)
				to_chat(A, "<span class='warning'>[D] слишком далеко!</span>")
				A.pixel_x = 0
				A.pixel_y = 0
				D.pixel_x = 0
				D.pixel_y = 0
				return

			if (!isturf(A.loc) || !isturf(D.loc))
				to_chat(A, "<span class='warning'>Не могу кинуть [D] здесь!</span>")
				A.pixel_x = 0
				A.pixel_y = 0
				D.pixel_x = 0
				D.pixel_y = 0
				return
		else
			if (A)
				A.pixel_x = 0
				A.pixel_y = 0
			if (D)
				D.pixel_x = 0
				D.pixel_y = 0
			return

		sleep(1)


		D.forceMove(A.loc)

		if (A && D)

			if (get_dist(A, D) > 1)
				to_chat(A, "<span class='warning'>[D] слишком далеко!</span>")
				return

			if (!isturf(A.loc) || !isturf(D.loc))
				to_chat(A, "<span class='warning'>Не могу кинуть [D] здесь!</span>")
				return

			A.setDir(turn(A.dir, 1))
			var/turf/T = get_step(A, A.dir)
			var/turf/S = D.loc
			if ((S && isturf(S) && S.Exit(D)) && (T && isturf(T) && T.Enter(A)))
				D.forceMove(T)
				D.setDir(get_dir(D, A))
			else
				return

			sleep(3 SECONDS)

	if (A && D)
		// These are necessary because of the sleep call.

		D.forceMove(A.loc) // Maybe this will help with the wallthrowing bug.

		D.visible_message("<span class='danger'>[A] кидает [D]!</span>" , \
						"<span class='userdanger'>Меня кидает [A]!</span>" , "<span class='hear'>Слышу агрессивную потасовку и громкий стук!</span>" , null, A)
		to_chat(A, "<span class='danger'>Кидаю [D]!</span>")
		playsound(A.loc, "swing_hit", 50, TRUE)
		var/turf/T = get_edge_target_turf(A, A.dir)
		if (T && isturf(T))
			if (!D.stat)
				D.emote("agony")
			D.throw_at(T, 10, 4, A, TRUE, TRUE, callback = CALLBACK(D, /mob/living/carbon/human.proc/Paralyze, 20))
	log_combat(A, D, "has thrown with progib")
	return

/datum/martial_art/shaitanka/proc/FlipAnimation(mob/living/carbon/human/D)
	set waitfor = FALSE
	if (D)
		animate(D, transform = matrix(180, MATRIX_ROTATE), time = 1, loop = 0)
	sleep(15)
	if (D)
		animate(D, transform = null, time = 1, loop = 0)

/datum/martial_art/shaitanka/proc/uatknut(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(!D)
		return
	if(!A.pulling || A.pulling != D)
		to_chat(A, "<span class='warning'>Надо взять [D] в захват!</span>")
		return
	D.forceMove(A.loc)
	A.setDir(get_dir(A, D))
	D.setDir(get_dir(D, A))

	D.visible_message("<span class='danger'>[A] хватает [D] up!</span>" , \
					"<span class='userdanger'>Меня втыкает [A]!</span>" , "<span class='hear'>Слышу агрессивную потасовку!</span>" , null, A)
	to_chat(A, "<span class='danger'>Втыкаю [D]!</span>")


	for (var/i = 0, i < 3, i++)
		if (A && D)
			A.pixel_y += 3
			D.pixel_y += 3
			A.setDir(turn(A.dir, 180))
			D.setDir(turn(D.dir, 180))

			switch (A.dir)
				if (NORTH)
					D.pixel_x = A.pixel_x
				if (SOUTH)
					D.pixel_x = A.pixel_x
				if (EAST)
					D.pixel_x = A.pixel_x - 8
				if (WEST)
					D.pixel_x = A.pixel_x + 8

			if (get_dist(A, D) > 1)
				to_chat(A, "<span class='warning'>[D] слишком далеко!</span>")
				A.pixel_x = 0
				A.pixel_y = 0
				D.pixel_x = 0
				D.pixel_y = 0
				return

			if (!isturf(A.loc) || !isturf(D.loc))
				to_chat(A, "<span class='warning'>Не могу воткнуть [D] здесь!</span>")
				A.pixel_x = 0
				A.pixel_y = 0
				D.pixel_x = 0
				D.pixel_y = 0
				return
		else
			if (A)
				A.pixel_x = 0
				A.pixel_y = 0
			if (D)
				D.pixel_x = 0
				D.pixel_y = 0
			return

		sleep(1)

	if (A && D)
		A.pixel_x = 0
		A.pixel_y = 0
		D.pixel_x = 0
		D.pixel_y = 0

		if (get_dist(A, D) > 1)
			to_chat(A, "<span class='warning'>[D] слишком далеко!</span>")
			return

		if (!isturf(A.loc) || !isturf(D.loc))
			to_chat(A, "<span class='warning'>Не могу воткнуть [D] здесь!</span>")
			return

		D.forceMove(A.loc)

		var/fluff = "воткнул"
		switch(pick(2,3))
			if (2)
				fluff = "[fluff] по яйца"
			if (3)
				fluff = "пиздец как [fluff]"

		D.visible_message("<span class='danger'>[A] [fluff] [D]!</span>" , \
						"<span class='userdanger'>[fluff]ут  [A]!</span>" , "<span class='hear'>Слышу звук разрывающейся плоти!</span>" , COMBAT_MESSAGE_RANGE, A)
		to_chat(A, "<span class='danger'>[fluff] [D]!</span>")
		playsound(A.loc, "swing_hit", 50, TRUE)
		if (!D.stat)
			D.emote("agony")
			D.Paralyze(40)

			switch(rand(1,3))
				if (2)
					D.adjustBruteLoss(rand(20,30))
				if (3)
					D.ex_act(EXPLODE_LIGHT)
				else
					D.adjustBruteLoss(rand(10,20))
		else
			D.ex_act(EXPLODE_LIGHT)

	else
		if (A)
			A.pixel_x = 0
			A.pixel_y = 0
		if (D)
			D.pixel_x = 0
			D.pixel_y = 0


	log_combat(A, D, "body-slammed")
	return

/datum/martial_art/shaitanka/proc/CheckStrikeTurf(mob/living/carbon/human/A, turf/T)
	if (A && (T && isturf(T) && get_dist(A, T) <= 1))
		A.forceMove(T)

/datum/martial_art/shaitanka/proc/taa(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(!D)
		return
	A.emote("flip")
	var/turf/T = get_turf(A)
	if (T && isturf(T) && D && isturf(D.loc))
		for (var/i = 0, i < 4, i++)
			A.setDir(turn(A.dir, 90))

		A.forceMove(D.loc)
		addtimer(CALLBACK(src, .proc/CheckStrikeTurf, A, T), 4)


		D.visible_message("<span class='danger'>[A] дал чапалах [D]!</span>" , \
						"<span class='userdanger'>Получаю чапалахом по лицу от [A]!</span>" , "<span class='hear'>Слышу звук разрывающейся плоти!</span>" , COMBAT_MESSAGE_RANGE, A)
		to_chat(A, "<span class='danger'>Угаманил [D]!</span>")
		D.adjustBruteLoss(rand(10,20))
		playsound(A.loc, "white/fogmann/taa.ogg", 100, TRUE)
		D.Unconscious(20)
	log_combat(A, D, "headbutted")

/datum/martial_art/shaitanka/proc/shaa(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(!D)
		return
	A.emote("agony")
	A.setDir(turn(A.dir, 90))

	D.visible_message("<span class='danger'>[A] дает с вертухи [D]!</span>" , \
					"<span class='userdanger'>Почуствовал вкус макасинов [A]!</span>" , "<span class='hear'>Слышу звук разрывающейся плоти!</span>" , COMBAT_MESSAGE_RANGE, A)
	to_chat(A, "<span class='danger'>Угаманил [D]!</span>")
	playsound(A.loc, "white/fogmann/shaa.ogg", 100, TRUE)
	D.adjustBruteLoss(rand(10,20))

	var/turf/T = get_edge_target_turf(A, get_dir(A, get_step_away(D, A)))
	if (T && isturf(T))
		D.Paralyze(20)
		D.throw_at(T, 3, 2)
	log_combat(A, D, "roundhouse-kicked")

/datum/martial_art/shaitanka/disarm_act(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(check_streak(A,D))
		return 1
	log_combat(A, D, "shaitanka-disarmed")
	..()

/datum/martial_art/shaitanka/grab_act(mob/living/carbon/human/A, mob/living/carbon/human/D)
	if(check_streak(A,D))
		return 1
	if(A.pulling == D)
		return 1
	A.start_pulling(D)
	D.visible_message("<span class='danger'>[A] хватает [D] на болевой!</span>" , \
					"<span class='userdanger'>[A] взял меня на болевой!</span>" , "<span class='hear'>Слышу агрессивную потасовку!</span>" , COMBAT_MESSAGE_RANGE, A)
	to_chat(A, "<span class='danger'>Беру [D] на болевой!</span>")
	D.Stun(rand(60,100))
	log_combat(A, D, "cinched")
	return 1


/obj/item/clothing/mask/boroda
	name = "борода Дагестанца"
	desc = "говорят, без неё они - никто"
	icon = 'white/pieceofcrap.dmi'
	icon_state = "boroda"
	flags_inv = HIDEFACE|HIDEFACIALHAIR
	var/datum/martial_art/shaitanka/style = new

/obj/item/clothing/mask/boroda/equipped(mob/user, slot)
	. = ..()
	if(!ishuman(user))
		return
	if(slot == ITEM_SLOT_MASK)
		var/mob/living/carbon/human/H = user
		style.teach(H,1)
	return

/obj/item/clothing/mask/boroda/dropped(mob/user)
	. = ..()
	if(!ishuman(user))
		return
	var/mob/living/carbon/human/H = user
	if(H.get_item_by_slot(ITEM_SLOT_MASK) == src)
		style.remove(H)
	return

/obj/item/clothing/mask/boroda/curse
	flags_inv = HIDEFACE|HIDEHAIR|HIDEFACIALHAIR

/obj/item/clothing/mask/boroda/curse/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, CURSED_MASK_TRAIT)
