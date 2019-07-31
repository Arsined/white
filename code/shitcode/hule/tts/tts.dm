 //needs gtts module and ffmpeg

GLOBAL_VAR_INIT(tts, FALSE)
GLOBAL_VAR_INIT(tts_lang, "ru")
GLOBAL_VAR_INIT(tts_os_unix, TRUE)

/proc/tts(var/mob/M, var/msg, var/lang=GLOB.tts_lang)
	if(!isliving(M))
		return

	msg = ph2up(msg)
	//msg = trim(rhtml_encode(msg), 16)

	if(GLOB.tts_os_unix)
		world.shelleo("python3 code/shitcode/hule/tts/tts.py \"[M.ckey]\" \"[msg]\" \"[lang]\" ")
	else
		var/list/output = world.shelleo("python code/shitcode/hule/tts/tts.py \"[M.ckey]\" \"[msg]\" \"[lang]\" ")
		to_chat(M, output)

	//spawn(10)
	var/path = "code/shitcode/hule/tts/lines/[M.ckey].ogg"
	if(fexists(path))
		for(var/mob/MB in range(13))
			MB.playsound_local(get_turf(M), path, 100)
			fdel(path)
			fdel("code/shitcode/hule/tts/conv/[M.ckey].mp3")

/mob/living
	var/datum/tts = new

/datum/tts
	var/mob/living/owner
	var/cooldown = 0
	var/cdincrease = 3 //ds for one char
	var/maxlen = 64 //sasai kudosai
	var/cTSS = 0 //create tts on hear

/datum/tts/New()
	. = ..()
	START_PROCESSING(SSobj, src)

/datum/tts/Destroy()
	. = ..()
	STOP_PROCESSING(SSobj, src)

/datum/tts/process()
	if(cooldown > 0)
		cooldown--

/datum/tts/proc/generate_tts(msg)
	if(!cooldown)
		msg = trim(msg, maxlen)
		cooldown = length(msg)
		tts(owner, msg)


/client/proc/anime_voiceover()
	set category = "Fun"
	set name = "ANIME VO"

	if(!(ckey in GLOB.anonists))
		return

	var/list/menu = list("Cancel", "Toggle TTS", "Change Lang", "OS Settings")

	var/selected = input("Main Menu", "ANIME VOICEOVER", "Cancel") as null|anything in menu

	switch(selected)
		if("Cancel")
			return

		if("Toggle TTS")
			GLOB.tts = !GLOB.tts

			if(GLOB.tts)
				message_admins("[key] toggled anime voiceover on.")
			else
				message_admins("[key] toggled anime voiceover off.")

		if("Change Lang")
			var/list/langlist = list("Cancel", "ru", "en", "en-gb", "ja", "fr")

			var/selectedlang = input("Main Menu", "ANIME VOICEOVER", null) as null|anything in langlist
			if(selectedlang == "Cancel")
				return

			message_admins("[key] sets anime voiceover lang to \"[selectedlang]\"")
			GLOB.tts_lang = selectedlang

		if("OS Settings")
			GLOB.tts_os_unix = !GLOB.tts_os_unix

			if(GLOB.tts_os_unix)
				message_admins("[key] sets anime voiceover OS to Unix")
			else
				message_admins("[key] sets anime voiceover OS to Windows (Debug)")

