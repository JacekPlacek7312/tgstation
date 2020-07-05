SUBSYSTEM_DEF(economy)
	name = "Economy"
	wait = 5 MINUTES
	init_order = INIT_ORDER_ECONOMY
	runlevels = RUNLEVEL_GAME
	var/roundstart_paychecks = 5
	var/budget_pool = 35000
	var/list/department_accounts = list(ACCOUNT_CIV = ACCOUNT_CIV_NAME,
										ACCOUNT_ENG = ACCOUNT_ENG_NAME,
										ACCOUNT_SCI = ACCOUNT_SCI_NAME,
										ACCOUNT_MED = ACCOUNT_MED_NAME,
										ACCOUNT_SRV = ACCOUNT_SRV_NAME,
										ACCOUNT_CAR = ACCOUNT_CAR_NAME,
										ACCOUNT_SEC = ACCOUNT_SEC_NAME)
	var/list/generated_accounts = list()
	var/full_ancap = FALSE // Enables extra money charges for things that normally would be free, such as sleepers/cryo/cloning.
							//Take care when enabling, as players will NOT respond well if the economy is set up for low cash flows.
	var/alive_humans_bounty = 100
	var/crew_safety_bounty = 1500
	var/monster_bounty = 150
	var/mood_bounty = 100
	var/techweb_bounty = 250
	var/slime_bounty = list("grey" = 10,
							// tier 1
							"orange" = 100,
							"metal" = 100,
							"blue" = 100,
							"purple" = 100,
							// tier 2
							"dark purple" = 500,
							"dark blue" = 500,
							"green" = 500,
							"silver" = 500,
							"gold" = 500,
							"yellow" = 500,
							"red" = 500,
							"pink" = 500,
							// tier 3
							"cerulean" = 750,
							"sepia" = 750,
							"bluespace" = 750,
							"pyrite" = 750,
							"light pink" = 750,
							"oil" = 750,
							"adamantine" = 750,
							// tier 4
							"rainbow" = 1000)
	var/list/bank_accounts = list() //List of normal accounts (not department accounts)
	var/list/dep_cards = list()
	/// A var that collects the total amount of credits owned in player accounts on station, reset and recounted on fire()
	var/station_total = 0
	/// A var that tracks how much money is expected to be on station at a given time. If less than station_total prices go up in vendors.
	var/station_target = 1
	/// A var that displays the result of inflation_value for easier debugging and tracking.
	var/inflation_value = 1
	/// Contains the message to send to newscasters about price inflation and earnings, updated on price_update()
	var/earning_report

/datum/controller/subsystem/economy/Initialize(timeofday)
	var/budget_to_hand_out = round(budget_pool / department_accounts.len)
	for(var/A in department_accounts)
		new /datum/bank_account/department(A, budget_to_hand_out)
	return ..()

/datum/controller/subsystem/economy/fire(resumed = 0)
	boring_eng_payout()  // Payout based on nothing. What will replace it? Surplus power, powered APC's, air alarms? Who knows.
	boring_sci_payout() // Payout based on slimes.
	boring_secmedsrv_payout() // Payout based on crew safety, health, and mood.
	boring_civ_payout() // Payout based on ??? Profit
	station_total = 0
	for(var/A in bank_accounts)
		var/datum/bank_account/B = A
		B.payday(1)
		if(!istype(B, /datum/bank_account/department))
			station_total += B.account_balance
			station_target += STATION_TARGET_INCREMENT
	price_update()

/datum/controller/subsystem/economy/proc/get_dep_account(dep_id)
	for(var/datum/bank_account/department/D in generated_accounts)
		if(D.department_id == dep_id)
			return D

/datum/controller/subsystem/economy/proc/boring_eng_payout()
	var/engineering_cash = 3000
	var/datum/bank_account/D = get_dep_account(ACCOUNT_ENG)
	if(D)
		D.adjust_money(engineering_cash)

/datum/controller/subsystem/economy/proc/boring_secmedsrv_payout()
	var/crew
	var/alive_crew
	var/dead_monsters
	var/cash_to_grant
	for(var/mob/m in GLOB.mob_list)
		if(isnewplayer(m))
			continue
		if(m.mind)
			if(isbrain(m) || iscameramob(m))
				continue
			if(ishuman(m))
				var/mob/living/carbon/human/H = m
				crew++
				if(H.stat != DEAD)
					alive_crew++
					var/datum/component/mood/mood = H.GetComponent(/datum/component/mood)
					var/medical_cash = (H.health / H.maxHealth) * alive_humans_bounty
					if(mood)
						var/datum/bank_account/D = get_dep_account(ACCOUNT_SRV)
						if(D)
							var/mood_dosh = (mood.mood_level / 9) * mood_bounty
							D.adjust_money(mood_dosh)
						medical_cash *= (mood.sanity / 100)

					var/datum/bank_account/D = get_dep_account(ACCOUNT_MED)
					if(D)
						D.adjust_money(medical_cash)
		if(ishostile(m))
			var/mob/living/simple_animal/hostile/H = m
			if(H.stat == DEAD && (H.z in SSmapping.levels_by_trait(ZTRAIT_STATION)))
				dead_monsters++
		CHECK_TICK
	var/fuck = alive_crew / crew
	cash_to_grant = (crew_safety_bounty * fuck) + (monster_bounty * dead_monsters)
	var/datum/bank_account/D = get_dep_account(ACCOUNT_SEC)
	if(D)
		D.adjust_money(cash_to_grant)

/datum/controller/subsystem/economy/proc/boring_sci_payout()
	var/science_bounty = 0
	for(var/mob/living/simple_animal/slime/S in GLOB.mob_list)
		if(S.stat == DEAD)
			continue
		science_bounty += slime_bounty[S.colour]
	var/datum/bank_account/D = get_dep_account(ACCOUNT_SCI)
	if(D)
		D.adjust_money(science_bounty)

/datum/controller/subsystem/economy/proc/boring_civ_payout()
	var/datum/bank_account/D = get_dep_account(ACCOUNT_CIV)
	if(D)
		D.adjust_money(min(civ_cash, MAX_GRANT_CIV))


/**
  * Updates the prices of all station vendors with the inflation_value, increasing/decreasing costs.
  *
  **/
/datum/controller/subsystem/economy/proc/price_update()
	for(var/obj/machinery/vending/V in GLOB.machines)
		if(istype(V, /obj/machinery/vending/custom))
			continue
		if(!is_station_level(V.z))
			continue
		V.reset_prices(V.product_records, V.coin_records)
		V.updateUsrDialog()
	earning_report = "Sector Economic Report<br /> Sector price inflation is current at [SSeconomy.inflation_value()*100]%.<br /> Station Budget is currently <b>[station_total] Credits</b>, and Station Targeted Allowance is at <b>[station_target] Credits</b>.<br /> That's all from the <i>Nanotrasen Economist Division</i>."
	GLOB.news_network.SubmitArticle(earning_report, "Station Earnings Report", "Station Announcements", null)

/**
  * Proc that returns a value meant to undercut the value of civilian bounties, based on how much money exists on the station.
  *
  * If crew are somehow aquiring far too much money, this value will dynamically cause vendables across the station to skyrocket in price until some money is spent.
  **/
/datum/controller/subsystem/economy/proc/inflation_value()
	if(station_total > station_target)
		var/holder = station_total - station_target
		holder = clamp(round((holder / max(station_target,1) + 1),0.1),1,5)
		inflation_value = holder
		return holder
	return 1
