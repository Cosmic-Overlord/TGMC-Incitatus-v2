/datum/action/ability/xeno_action/psychic_whisper/action_activate()
	if(!xeno_owner.check_state())
		return

	var/msg = stripped_input(xeno_owner, "Message:", "Psychic Whisper")
	if(!msg)
		return

	log_directed_talk(xeno_owner, xeno_owner, msg, LOG_SAY, "psychic whisper")

	var/message_color
	var/caste_path = xeno_owner.xeno_caste.caste_type_path

	switch(caste_path)
		if(/mob/living/carbon/xenomorph/warlock)
			message_color = "#b200ff"
		if(/mob/living/carbon/xenomorph/shrike)
			message_color = "#ff24b6"
		if(/mob/living/carbon/xenomorph/hivemind)
			message_color = "#ff4482"
		else
			message_color = "#b200ff" // По умолчанию фиолетовый

	var/styled_msg = "<span style='color: [message_color]; font-size: 110%; font-weight: bold; text-shadow: 0 0 8px [message_color];'><b>[xeno_owner]</b> psychically whispers: <i>\"[msg]\"</i></span>"

	for(var/mob/M in viewers(xeno_owner))
		to_chat(M, styled_msg)

	message_admins("[key_name_admin(xeno_owner)] has psychic whispered: \"[msg]\" at [ADMIN_VERBOSEJMP(xeno_owner)].")

	flick("purple_thought_bubble", xeno_owner.chat_color)

	return TRUE
