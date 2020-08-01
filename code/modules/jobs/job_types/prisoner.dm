/datum/job/prisoner
	title = "Prisoner"
	flag = PRISONER
	department_head = list("The Security Team")
	department_flag = CIVILIAN
	faction = "Station"
	total_positions = 4
	spawn_positions = 4
	supervisors = "the security team"

	outfit = /datum/outfit/job/prisoner

	display_order = JOB_DISPLAY_ORDER_PRISONER

/datum/outfit/job/prisoner
	name = "Prisoner"
	jobtype = /datum/job/prisoner

	uniform = /obj/item/clothing/under/rank/prisoner
	shoes = /obj/item/clothing/shoes/sneakers/orange
	id = /obj/item/card/id/prisoner
	ears = null
	belt = null

/datum/job/prisoner/after_spawn(mob/living/carbon/human/H, mob/M, latejoin)
	. = ..()
	if(latejoin)
		var/obj/structure/closet/supplypod/bluespacepod/pod = new()
		pod.style = STYLE_STANDARD
		H.forceMove(pod)
		var/droplocation = pick(GLOB.prisoner_start)
		new /obj/effect/pod_landingzone(droplocation, pod)

/datum/job/prisoner/override_latejoin_spawn()
	return TRUE
