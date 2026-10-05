# Project Zomboid mods for human NPCs, human-vs-human combat, and weapon variety (state as of 2026-10-05)

Conventions used throughout. Every Workshop number labelled "subs" is the item's **current subscriber count**, pulled on **2026-10-05** from the public Steam Web API ([GetPublishedFileDetails](https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/)). Its `subscriptions` field matched the page's "Current Subscribers" (the Bandits page showed 1,043,649 and the API returned 1,043,650 minutes later). "Lifetime" is the API's `lifetime_subscriptions`. Steam changelog dates with no year are **2026**, because Steam omits the current year. Changelog page numbers (`?p=N`) are as of 2026-10-05 and shift as new notes are added. Steam's page fetcher rate-limited (HTTP 429) during this research, so mod descriptions were read through the API's `description` field, and some Steam discussion pages were read via curl.

---

## 1. Which human-NPC mods are most popular or most cited, and how does their AI work (combat tactics, cover, fleeing, surrender, recruitment, factions, base raids, relationships)?

### Takeaway
In October 2026 one ecosystem dominates human NPCs: **Slayer's Bandits family**. Bandits NPC is the engine (about 1.04M current subs, B42-only, SP+MP). Week One, The Ark and Bandit Creator sit on top of it, along with a ring of third-party add-ons. The B41-era **Superb Survivors** line (385K subs, SP-only) is frozen. Bandits' base AI is built from a few parts: zombie actors in a human "costume", wave/clan programs (attackers, wanderers, defenders, roadblocks, friendlies), raids that steal and sabotage, health-threshold flee/limp/surrender, and turn-then-aim gunfire with distance-dependent aim time and per-clan accuracy. **Cover use, suppressing fire and flanking do not appear in any base-mod material found.** They appear only in an unofficial add-on (Bandits Radio Expansion) whose author says Gemini AI writes the code. That add-on is also the source of the clearest group-surrender mechanic and the only prisoner choice found (execute or release).

### Cited Findings

#### Bandits NPC (Slayer / Piotr Pawłowski): the reference implementation
- Title "[B42] Bandits NPC", Workshop 3268487204, Mod ID `Bandits2`. "This mod works for: B42 ONLY (B42.20+) both single and multiplayer." Created 2024-06-15, updated 2026-10-04. Current subs 1,043,650 (lifetime 1,650,930), 50,402 favorites, 1,047,084 unique visitors. Workshop tags include "Framework" and "Multiplayer". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- The page shows 10,660 ratings and 272 change notes. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- Design intent: "Enemies in this mod can be extremely dangerous ... Treat them as actual players when it comes to combat." The friendly NPCs in the base mod "aren't complex companions." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- It is an NPC engine for other mods: "Bandits mod is also the base NPC mod for a number of different mods, including The Ark, Week One, and more." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- **Implementation (third-party code reading):** "Bandits are zombies wearing a costume. They are dressed with item visuals - graphics with no real item behind them ... Bandits empties that list [worn items] every tick to draw its NPCs." The same author notes that in multiplayer "the engine's own zombie AI keeps pathing bandits straight to players across the map." — [Bandits Fix Plus page](https://steamcommunity.com/sharedfiles/filedetails/?id=3777752751)
- **Spawning and escalation:** "Initially, small groups of armed bandits with melee weapons will appear after 24 hours in the world around ~55 tiles away from the player. Over time, larger groups and ones more frequently with firearms will start to arrive." Spawning "is purely distance based", because "There is no way to easily check if the area is enclosed." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- Location and clan shape the spawn odds. "Player location will heavilly impact bandit spawn chance. Examples: Deepforest -75%, Riverside center: +42%, Wespoint center: +85%". Spawn boosts also depend on clan: "Hunters in forest, militians on the road etc" (Aug 29, 2024). — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- **Raid behaviours.** Bandits "Steal items from your base, sabotage your generators, vehicles or crops", "Destroy things such as doors and furniture that block their path", "Resupply from corpses or containers", "Use all weapons, including melee and firearms", and "can track you to your location". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- Vehicle sabotage was added on Aug 17, 2024: "possibility for bandits to remove car battery and tires". On Aug 20, 2024 it got a sandbox toggle and became server-synced, and "vehicle operations by bandits take more time". — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22); [Changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204)
- **Factions (clans):**
  - Aug 2, 2024: "added bandit clans (different types will fight each other)". — [Changelog p24](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=24)
  - Aug 10, 2024: "Bandit AI behaviour selectable per clan". — [Changelog p23](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=23)
  - Jul 26, 2024: "Bandit vs bandit friendly hits now removed". My reading, not stated by the author: bandits no longer damage each other by accidental friendly fire. — [Changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204)
- **Encounter archetypes:**
  - Defenders: "Bandit defenders added" (Jun 26, 2024). — [Changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204)
  - Defender homes: "house of the defender bandit will have defences, running generator and food in fridge" (Aug 2, 2024). — [Changelog p24](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=24)
  - Wanderers: "they will not attack player but wander in the world. If they spot you they will hunt you down". The same note sets the map icon colours: "red=attacker, yellow=wanderers, green=friendly, magenta=base" (Aug 4, 2024). — [Changelog p24](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=24)
  - Roadblocks: "NEW - Bandit Roadblocks!" (Aug 22, 2024). — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
  - Wanderer rework, Aug 17, 2026: wanderers "spawn very far from player and travel across the cities and to visit certain known locations", plus "dozen of new wanderer clans". — [Changelog p2](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=2)
- **Friendly NPCs and recruitment:**
  - Aug 8, 2024: "Friendly bandits will spawn using the wave system if the wave is set to friendly. They will try to locate the player and join him as companions." — [Changelog p23](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=23)
  - Aug 13, 2024: "option to make friendly stop following the player and stay guarding the place"; "Friendly bandits will not destroy windows and doors in a safehouse"; "friendlies will not attack friendlies from another clan". — [Changelog p23](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=23)
  - Aug 17, 2024: "removed context-menu for friendlies - this method will not work well in multiplayer (desync)". — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- **Fleeing, limping and surrender (base mod).** Jul 5, 2024: "Bandits can now run away when hurt", "Bandits can now surrender when very low health", "Bandits can now limp when low health". — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26)
- Mar 2, 2026: "some movement fixes and new experimental bandit escape logic". — [Changelog p5](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=5)
- **Melee tactics** (Aug 29, 2024): "Bandits will use more advanced tactics: they will assume combat stance when close to enemy earlier, when overwhelmed will find optimal escape vector, they will only hit if properly rotated towards enemy, melle weapon range optimized ..., endurance will not be depleted that fast". — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- More melee additions:
  - May 2, 2025: "added bandit step-back attacks for more weapon types". — [Changelog p12](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=12)
  - Sep 19, 2026: "bandit handgun/rifle whip attack added". — [Changelog p1](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204)
- **Gun tactics** (Aug 29, 2024): "bandits must rotate and then aim properly, aiming time depends on distance, bandits accuracy boosted/ deboosted based on clan (military higher accuracy, others lower)". — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- Earlier gun tuning (Jul 27, 2024) published "bandit accuracy levels" as a linked spreadsheet and made "bandit weapons range configurable in sandbox settings". — [Changelog p25](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=25)
- **Damage model vs the player** (Jun 30, 2025): "Chance to hit specific part is calculated realistically, favoring chest parts the most, feet, hands, neck and head the least. Bullet protective clothes such as bulletproff vest will work against bandit bullets. Shot in the head is least probable but result in instant death." — [Changelog p10](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=10)
- **Vehicles as cover:**
  - Aug 6, 2024: "Car will now protect players inside agains bandit bullets. The protection wil ldepend on car condition. Bandits can damage cars by shooting at them." — [Changelog p24](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=24)
  - Nov 22, 2025: "vehicles with armor cannot be destroyed by bandit bullets, nor can the player inside be hurt". — [Changelog p7](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=7)
- **Perception:**
  - Aug 6, 2024: "Bandits should not see players who are directly behind them (may hear them)". — [Changelog p24](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=24)
  - May 20, 2025: "bandits dont see players in darness fix" and "less bandits with tracker ability". — [Changelog p12](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=12)
  - Aug 6, 2026: "AI IMPROVEMENT: BANDITS REGISTER PLAYER LAST KNOWN LOCATION TO FOLLOW ONCE EYE CONTACT IS LOST". — [Changelog p2](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=2)
- **Noise links NPC gunfights to zombies:**
  - Jul 4, 2024: "Zombies react to bandit weapon sounds". — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26)
  - Jun 30, 2025: "zombies will now head to sounds emitted by bandit firearms". — [Changelog p10](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=10)
  - Jul 11, 2024: "Bandits carry torches which emit light during the night". — [Changelog p25](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=25)
- **Ammo realism:** "Bandits drop empty mags after reload" (Jun 20, 2024). — [Changelog p27](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=27)
- **Weapon-mod integration for NPC loadouts:**
  - Jul 4, 2024: "Added Gunfighter and brita weapons for bandits". — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26)
  - Aug 17, 2024: "integration with Guns of 93". — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
  - Aug 29, 2024: "Vanilla Firearms Expanded weapons for bandits". — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- "Raider" AI type: "In the BANDITS release of 9/2/25 default Raider behaviour was turned off for most spawns." A third-party option exists to "Prevent bandits from knowing your location without ever seeing you by disabling Raider AI type for all waves". — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)

#### Bandit Creator (Slayer): data-driven clans
- Workshop 3469292499. 144,573 subs; created 2025-04-23, updated 2026-08-21. "Compatibile with B42 version for single and multiplayer." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3469292499)
- Customisation covers:
  - Outfit and physical appearance.
  - Attributes: "Health, Sight (affects weapon accuracy), Endurance (determines when they need to stop to catch their breath), Strength (affects melee combat, shoves, and barricade damage)".
  - "Weapons – melee, primary, and secondary weapons, plus ammo count", and a bag whose contents are "auto-generated based on their expertise".
  - "Clan spawn settings: Define AI behavior, spawn location, time frame, and group size."
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3469292499)
- Each bandit can have "up to three unique skills, called expertises".
  - Implemented: Breaker (breaks barricades and doors), Electrician ("Sabotages generators and electrical devices"), Cook ("Steals or sabotages crops"), Infected (bites like a zombie), Mechanic ("Sabotages cars and steals fuel"), Recon (faster), Thief, Repairman, Tracker ("Tracks the player more easily").
  - Marked "(Not implemented)": Assassin, Goblin, Medic, Trapper, Traitor ("May pretend to be a friend"), Sacrificer ("Explodes on death"), Zombiemaster.
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3469292499)
- Creations are stored in two text files, `bandits.txt` and `clans.txt`, in either local storage or mod storage, merged in memory. Dedicated servers get bandits via a "Bandit Sync" context option. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3469292499)

#### Bandits Extra Options (third-party): what players wanted to tune
- Workshop 3412682512. 42,592 subs; updated 2025-02-28; tagged B41 and B42. Its credits say "All functions of this mod are derived from [Slayer's] code". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
- Per-wave loadout presets:
  - "Civilian: Handguns and single shot rifles."
  - "Police: Semi-automatic rifles and SMGs. Special weapons are automatic and sniper rifles."
  - "Military: US-type automatic rifles. Special weapons are sniper rifles and LMGs."
  - "Exotic"
  - "Looted: Lower quality weapons loadout for desperate bandits."
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
- Other options:
  - Random group size, health and ammo.
  - "Player base minimum spawn radius".
  - "Days before visited building may be occupied", where visited means you "remain inside for 10 game minutes".
  - "Occupied buildings have generators".
  - "Allow sandbag roadblocks".
  - Car or helicopter sound effects when large groups spawn.
  - "Spawn icons do not show hostility ... Who is there? You'll have to find out...".
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
- Week One / Day One options: "Trespass grace period: Choose how long it will take for inhabitants of buildings to attack, if you trespass". Day One "Starting companions: Start with a random family of NPCs, a group of co-workers, or nobody". There are also toggles for a nuke, fire-bombing, gas attacks and "A10 attacks". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)

#### Bandits Radio Expansion (unofficial add-on): the only found implementation of suppression, flanking and group surrender
- Title "Bandits Radio Expansion 42.20 MP (Unofficial addon)", Workshop 3630494926. 38,869 subs; created 2025-12-24, updated 2026-09-15. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926)
- **Surrender System (V2.1):** "let's say there are 4 bandits in a group and you kill 3 of them — the 4th one will surrender. Before surrendering, the bandit will drop all their belongings on the ground and play a corresponding animation, after which they will freeze with their hands in the air. At this point, you have 2 options: kill them or let them go. If you choose the 2nd option, they will simply run away from you in a random direction." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926)
- **Surrender to a rival clan:** "One random bandit from the group will be chosen to take on the role of the 'executioner', while the rest will simply point their guns at the captive ... walk up to the surrendered bandit, loot them, and then execute them." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926)
- **Radios.** "bandits now have the ability to request backup". Radio dialogue is "semi-dynamic" and reacts to situation, weather and night. A frequency "might be intercepted by raiders and an inter-clan shootout will break out". Bandits also now drop their weapons on death. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926)
- **Advanced Combat & Backup AI (V2.5):**
  - "Active Patrols: If backup arrives and there is no visible enemy, the squad will now spread out and actively patrol the area."
  - "Hivemind Vision: ... shared vision system, allowing them to instantly coordinate their hunt once an enemy is spotted by any member."
  - "Reworked Suppression & Flanking: ... Bandits will now utilize suppressive fire to execute V-shaped flanking maneuvers against the enemy."
  - "WIP CQB Module ... for better tactical movement and combat inside buildings."
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926)
- Known issues and provenance: "The custom AI program for the radio backup bandits is not fully finished yet". "I do not know how to code personally — Gemini AI helps me write the code." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926)

#### Week One (Slayer): a pre-outbreak social sandbox on the Bandits engine
- Workshop 3403180543, Mod ID `BanditsWeekOne`. 330,249 subs (lifetime 651,565), 30,101 favorites, 8,275 ratings; created 2025-01-08, updated 2026-08-07. "Use 42.19. or 42.20 / stable"; "Must also have enabled Bandits mod which serves as NPC engine". Workshop tags have no "Multiplayer". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- Premise: "begin the game 7 days before the zombie outbreak ... It will be your choice whether you want to be a decent citizen, a serial killer or somebody else, just remember that your actions have consequences." NPC chat: "Press 'T' to chat with them. Use American English, type simple sentences". Intent: "it's supposed to be funny, so take it lightly when things don't go as planned." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- Changelog hints about systems:
  - "new chat lines (including commands to stay in place or return home)" (Feb 3, 2025). — [Changelog p11](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=11)
  - A companion NPC called "babe" "can be passenger of a car" (Feb 7, 2025). — [Changelog p10](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=10)
  - "if babe is unloaded from the cell, she will automatically return home" (Feb 2, 2025). — [Changelog p11](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=11)
  - "earn money by killing bandits fix for police officer" and "proper recognition of non-hostility when killing bandits" (May 1, 2025). — [Changelog p7](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=7)
  - A Louisville military checkpoint "has now a very strong military presence" (Feb 27, 2025). — [Changelog p8](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=8)
  - "more choppers (police and CDC)" (Jun 4, 2025). — [Changelog p6](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=6)
  - "new late survivors companions" and "fixed inmates in prison cells being hostile" (Sep 29, 2025). — [Changelog p3](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=3)
  - "word lemmatization for npc chat" (Mar 4, 2025). — [Changelog p8](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543?p=8)

#### The Ark (Slayer): narrative sequel to Week One
- Workshop 3707475814. 54,394 subs, 10,007 favorites; created 2026-04-15, updated 2026-09-29. "Use 42.20 or 42.21 Stable". "SINGLE-PLAYER ONLY"; "total conversion" with "hundreds of quest lines". Requires Bandits NPC and Waterpipes. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3707475814)
- NPC interaction: "talk with NPC's by pressing the T key, however you will not be expected to type out what you want to say". Holding Q gives "commands such as to follow/stay". Theme: "forming connection with other human". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3707475814)

#### Superb Survivors line (B41, frozen)
- "Superb Survivors!" by nolanritchie, Workshop 1905148104. 385,094 subs (lifetime 1,025,534), 32,579 favorites, 8,754 ratings; created 2019-11-03, last updated 2023-02-05. "REQUIRES BUILD 41! UPDATED TO 41.73 SINGLE PLAYER ONLY!" — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104)
- Lineage: "Survivors!" in Build 39, then "Super Survivors!" in Build 40, then "Superb Survivors" in Build 41. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104)
- Behaviour: "Random NPCs will attempt to find a weapon then food and shelter and will barricade and hold up in a base."
- Recruitment: "invite them to join your group and if successful you can give them orders with right click or group UI by pressing U key". Tasks include "chopping, gathering, foraging, guarding, farming, doctor etc."
- Hostility: "NPCs can be hostile, and there are raider events were groups of survivors attempt to take over your base".
- Also a small quest system, plus preset map folders "Hilltop Survivor Camp", "Military Blockade", "Prison Escape" and "Woobury".

  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104)
- On AI improvement, nolanritchie wrote: "so far most of my time has been spent just with fixing and compatibility". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104)
- "Superb Survivors Continued" (SSC), Workshop 2980672778, by Cows with Guns (GitHub shadowhunter100). 36,923 subs; created 2023-05-26, updated 2023-07-06. "I am no longer working on this mod." Hard-coded companion hotkeys: Follow, Stop, Stand Ground, Barricade, come closer, spread further, Group Window, and spawn a "wild survivor". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778)
- PZNS NPC Framework (same author), Workshop 3001908830. 23,577 subs; tagged B41; API shows last update 2026-08-18. "If you can read, you can create a standalone NPC with less than 200 lines of code using this framework". "There are no Multiplayer Support planned". Examples include a Rosewood Police group and a standalone "Agent Wong" NPC. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3001908830); [GitHub](https://github.com/shadowhunter100/PZNS)

#### Other NPC items: cited but not retrievable
- On 2026-10-05 the Steam API returned result code 9 (not found, hidden or removed) for:
  - Knox Event Expanded (3397396843), which an aggregator described as "[COMING SOON] Knox Event Expanded NPC mod — not Build 42.20-compatible yet". — [pzfans](https://pzfans.com/zomboid_npc_mods_in_b42_surviving_the_apocalypse_with_friends/)
  - Slayer's Day One (3329251514). Its existence and features (e.g. "SWAT team from Day One", starting family or co-worker companions) are attested on other pages. — [Bandits Expansion Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3474469914); [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
  - Week One (B41) (3420587101), which is linked from Bandits Extra Options. — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)

### Inferences
Design lessons for 3–6 enemy firefights with cover, suppression, flanking, retreat/surrender and prisoners. All of these are my inferences.
- **Proven, cheap tactical primitives in the most popular mod:**
  - turn-then-aim with aim time scaling with distance
  - per-faction accuracy
  - flee when hurt, limp when low, surrender when very low
  - an "escape vector" to regroup when overwhelmed
  - last-known-position pursuit after losing line of sight
  
  Each of these creates a readable window for the player to act. A mobile game can show them visually: an aim line, a limp animation, a "searching" icon.
- **Two surrender models exist, and they combine well.** One is individual (a health threshold, base Bandits). The other is a group casualty ratio (the last of 4 gives up after 3 die, Radio Expansion). A morale rule like "surrender if (HP low) OR (squad losses ≥ 75%)" is easy to read for 3–6 enemy squads.
- **Surrender is already shown with good visual grammar.** The NPC drops gear, raises hands and freezes. The player's choices stop at kill or release. A prisoner system (capture, interrogate, recruit, ransom) is unexplored territory, and a differentiation opportunity.
- **Suppression and V-flank appear only in an AI-generated, self-described "not fully finished" add-on.** The most popular Zomboid mods offer no stable reference for cover-based squad tactics. The pattern itself is still worth borrowing: one or two suppressors pin while others flank in a V, with vision shared only within the squad and only after contact. Tuning should come from tactics-game references, not Zomboid mods.
- **Encounter variety comes from a few archetypes:** attackers (raids), wanderers (neutral until they spot you), defenders (occupied buildings with loot: generator and food), roadblocks (sandbags or vehicles), and friendlies. For a train game, roadblocks on the track and wanderers met at stations map naturally.
- **Raids that hit the economy, not just HP,** make human enemies feel different from zombies: thief, electrician cutting the generator, mechanic stealing fuel, cook ruining crops, breaker taking doors. On a train these could target the fuel car, generator car or food car.
- **Escalation pacing:** melee-only small groups first, guns and bigger groups later, with odds weighted by region and clan.
- **NPC gunfire draws zombies.** Bandits made zombies head to NPC gun sounds, so human firefights turn into horde events. This gives a built-in clock and a reason to prefer quiet weapons.
- **Architecture:** treat human NPCs as lightweight actors on the existing crowd/zombie system with a costume layer. Bandits did this and scaled to over 1M subscribers with multiplayer support. Superb Survivors' "full survivor" agents failed (see question 2).

### Gaps
- What happens after a **base-mod** Bandits surrender (from the Jul 5, 2024 note) is not documented: whether the player can capture, rob or release them, and whether it still exists after later AI rewrites. No source was found.
- The details of Slayer's 2026 "experimental bandit escape logic" and of the 2025 "Raider" default change were not found beyond the one-line notes.
- Whether base Bandits uses cover objects at all is unconfirmed. No changelog line among the 182 parsed entries mentions "cover". Some older pages may not have been parsed: the page reports 272 notes, while 30 pages yielded 182 entries.
- True Companions, a Bandits companion add-on referenced by Bandits Fix Plus, was not investigated. Its Workshop ID was not found.

---

## 2. What are the known problems of human-NPC AI in these mods (performance, dumb behaviour, multiplayer), and how did authors address them?

### Takeaway
There are three recurring failure families:
1. **Unfair information.** NPCs know where you are, track through walls, or shoot from off-screen. Fixes: the "Raider" behaviour was turned off by default, Tracker bandits were made rarer, last-known-position memory was added, and a third-party patch enforces line of sight and hearing.
2. **Performance and data.** Unlimited spawns, Superb Survivors' file-per-NPC bloat, and Week One's NPC cars. Fixes: spawn caps, adaptive update throttling, or a full rewrite (PZNS).
3. **Brittle companion and task AI.** Allies chop down your doors, jitter at guard posts or run on the spot. Superb Survivors' task AI was tangled with its threat AI, so workers died mid-job.

Multiplayer works only in the zombie-actor design (Bandits). Every player-clone design (SS, SSC, PZNS) declared multiplayer impossible.

### Cited Findings
- **Omniscience, as described by a third-party fix:** "Out of the box a Tracker hears you through walls from fifty-five tiles away, and in multiplayer the engine's own zombie AI keeps pathing bandits straight to players across the map." The fix makes them find you "the way zombies do: line of sight, sound at close range, or getting shot. They also remember where they last saw you and search there for a while ... Gunshots and alarms still pull them in." — [Bandits Fix Plus](https://steamcommunity.com/sharedfiles/filedetails/?id=3777752751)
- Upstream responses:
  - "less bandits with tracker ability" (May 20, 2025). — [Changelog p12](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=12)
  - "default Raider behaviour was turned off for most spawns" in the 9/2/25 release. — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
  - Last-known-location tracking (Aug 6, 2026). — [Changelog p2](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=2)
- **Spawn problems:**
  - "They spawned inside my base: There is no way to easily check if the area is enclosed. So the spawn is purely distance based." Too many bandits: "Use Bandit Creator mod to tune the right amount". — [Bandits page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
  - A third-party mod adds a "Player base minimum spawn radius" and an option to tie wave progression to world age, because "By default wave progression resets when you create a new character in the same world". — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
  - "FIXED PERFORMANCE PROBLEM CAUSED BY UNLIMITED NPC SPAWN" (Dec 9, 2025). — [Changelog p6](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=6)
- **Melee fairness:** "When a bandit engages the player from the zero distance, they perform a shove which knocks the player away or down, and start their next attack immediately, before the shove animation has played." The add-on's fix prevents bandits from cancelling attack animations. — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
- Upstream fix (Apr 15, 2026): "fix for bandits performing an invisible melee hit while being in hitreaction or other unsuitable for combat state". — [Changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204)
- **Companion bugs** (third-party fix, Aug–Sep 2026):
  - Doors: "Most of the demolition code checks whether the NPC is hostile first. Three branches do not: a barricaded door, a locked double door, and any other locked door. That is why your own ally walks up to your front door and chops it down."
  - Stuck movement: a "watchdog measures whether an NPC on a move order is actually covering ground. If it has not moved for a few seconds its path is dropped".
  - Guard posts: "A guard post is one exact tile, and pathfinding does not reliably land on one exact tile ... Posts now have a tolerance of a tile or two".
  
  — [Bandits Fix Plus](https://steamcommunity.com/sharedfiles/filedetails/?id=3777752751)
- **Costume-actor side effects:** corpses rendered bare or lost loot, because "Bandits empties that list every tick to draw its NPCs". Upstream: "fixed naked bodies and empty loot in multiplayer" (Dec 15, 2025). — [Bandits Fix Plus](https://steamcommunity.com/sharedfiles/filedetails/?id=3777752751); [Changelog p6](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=6)
- **Bandits performance work:**
  - "Performance optimization (step1)/(step2)" (Jul 7–8, 2024). — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26)
  - "performance optimization (avoiding pathing loop)" (Jul 31, 2024). — [Changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204)
  - "adaptive performance which drop zombie/bandit updates to avoid dropping frames" (Aug 29, 2024). — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- **Bandits multiplayer:**
  - "Multiplayer desync problem minimized" (Jul 4, 2024). — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26)
  - "Major improvement in multiplayer sync, all players should observe very similar behavior" (Jul 8, 2024). — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26)
  - The friendly context menu was removed because of multiplayer desync (Aug 17, 2024). — [Changelog p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
  - Multiplayer hosting needs the mod enabled in "three distinct areas". — [Bandits page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
  - An aggregator says Linux dedicated servers "may need DoLuaChecksum=false". This targets 42.19 and is unverified. — [pzfans](https://pzfans.com/zomboid_npc_mods_in_b42_surviving_the_apocalypse_with_friends/)
- **Build churn on unstable B42:** the changelog shows ports for 42.12, 42.13, 42.14, 42.15, 42.16, 42.17, 42.18 and "42.20 / stable quickfix" (Jul 30, 2026). Examples:
  - "b42.16 fixed bandit reloads (mod regression due to vanilla WeaponReloadType enum introduction)". — [Changelog p4](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=4)
  - 42.13: "renamed mod folder to 42.13 so that players with older version cant play it with billions of errors". — [Changelog p6](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=6)
  - "42.20 / stable quickfix". — [Changelog p3](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=3)
- **Week One** ("This mod consumes a lot of performance"):
  - The workaround is to cut NPC and zombie counts. "NPC vehicles might crash the game."
  - Known bugs: "can't forward time - happens when there are npc driven cars", "Missing aiming cursor - disable NPC cars", and "NPC cars drive only in straight line - no possible solution".
  - Must start new: "The mod modifies the world, if you remove the mod, the changes in the world will stay."
  
  — [Week One page](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- Week One performance changelog notes (Feb 2025): "performance optimization", "more significant performance improvements", "yet another performance optimizations". — [Week One changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3403180543)
- **Superb Survivors' issues, as listed by the SSC fork:**
  - "Game FPS drops to single digits when playing for more than 30 minutes"
  - "NPCs fleeing when more than 3 enemies are around"
  - "NPCs pulling an RKO on the player when they are fleeing"
  - "NPCs spawning in doing nothing and standing around"
  - The original "had no specified limits on spawning" and had "out-of-sequence code executions"
  
  Assessment: "Beyond 'Follow', 'Barricade', and 'Pile corpses'... I wouldn't trust the NPCs to do much besides dying and attacking." "Farming is broken." — [SSC page](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778)
- Original SS FAQ: "Why do the Survivors walk so slow/stuttery? Set FPS cap to 60". Survivors "de spawned for illigitimate reasons ... will respawn when you exit / re enter". Multiplayer: "Not likely". — [SS page](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104)
- **Root causes, from SSC/PZNS author "Technical Details: Why I no longer actively work on SS/SSC"** (post undated in the extracted page). Three causes:
  - **Data files.** SS writes loose per-NPC files with no clean-up "even for NPCs that are dead". Deleting files breaks the mod because "the core function(s) expects there to be a file based on the number of NPCs and number of groups". "Eventually, there will be too many files to load".
  - **Tangled AI.** "The SS AI code is entangled between Tasks and 'General AI' ... your NPC workers basically lets themselves get killed while working when attacked ... SS did not have a clear distinction between their job actions, threat assessment, and attacking actions. Some actions terminate early ... -OR- they queue up so many times the NPCs freeze or becomes stuck (Such as Reloading)."
  - **Size.** "rather than go through 6000+ lines of code ... it was far easier to start from scratch".
  
  — [PZNS discussion thread](https://steamcommunity.com/workshop/filedetails/discussion/3001908830/3812910027113381244/)
- **Engine limits, from the same author:** "'Full' NPCs are simply not realistic in the current build until TIS implements background simulations for NPCs and improves cache clearing/memory management." "Off-screen NPCs can and will cause the game to crash (because the square the NPC is on is unloaded)." "Non-zombified dead bodies are NOT (and NEVER) removed from the game world in single player". — [PZNS discussion thread](https://steamcommunity.com/workshop/filedetails/discussion/3001908830/3812910027113381244/); [PZNS issue #34](https://github.com/shadowhunter100/PZNS/issues/34)
- **Multiplayer refusals in player-clone designs:** SSC: "THERE IS NO MULTIPLAYER SUPPORT AND THERE NEVER WILL BE". PZNS: "There are no Multiplayer Support planned". — [SSC page](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778); [PZNS page](https://steamcommunity.com/sharedfiles/filedetails/?id=3001908830)
- **Maintainer burnout:**
  - SSC: "If you want a change or a feature, do it yourself or commission another person". — [SSC page](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778)
  - PZNS author: "Modding a game as a hobby doesn't pay the bills ... I am (or trying) to hand the PZNS project off". — [PZNS discussion thread](https://steamcommunity.com/workshop/filedetails/discussion/3001908830/3812910027113381244/)
  - Bandits and Week One both closed comments "because of hostility" and "due to continued hostility". — [Bandits](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204); [Week One](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)

### Inferences
- **Fairness of information matters more to players than lethality.** The fixes cluster around perception (line of sight, hearing, memory), not damage. A mobile game should make perception symmetric and visible: an enemy "alert" or "searching" state, and gunshot noise as the main thing that reveals the player.
- **Keep threat and combat logic separate from task logic** (the SS failure). A companion doing a job must still be preempted by threat assessment. Keep action queues idempotent so "reload" cannot stack.
- **Companions need rules that cannot be broken by ordinary code paths:** never damage player-owned structures; guard posts with tolerance; a stuck-movement watchdog; a small command set (follow / stay-guard / return home) instead of many fragile jobs.
- **Spawn safety rules are a must-have:** a no-spawn zone around the base and the player's line of sight, and progression tied to world or run age.
- **Instanced encounters avoid the hardest problems.** Small fights of 3–6 enemies in an instanced or local encounter sidestep off-screen simulation, unloaded-square crashes and corpse bloat, which killed SS-style "full" NPCs.

### Gaps
- No quantitative performance data was found (FPS cost per NPC). The figures are qualitative or anecdotal (e.g. "single digits ... after 30 minutes").
- The PZNS technical post's date was not captured. By context it was written after PZNS launched (2023-07) and before B42 (Dec 2024): an inference.

---

## 3. Which weapon mods are most popular, and how do they handle ammunition, attachments, weapon noise, jamming or durability, and melee alternatives?

### Takeaway
By current subscribers the B41 giants still lead: **Brita's Weapon Pack (3.30M)** with **Arsenal[26] GunFighter (2.90M)**, then **Scrap Weapons (1.20M, melee)**, **Firearms (1.07M)** and **Vanilla Firearms Expansion B41 (1.01M)**. Brita/GunFighter has **no official B42 release**: its own page says B42 broke "not one single feature spared". On B42 stable the active leaders are:
- **Guns of Marz** (443K, created May 2026, on the "Gunworks Framework")
- **Real Firearms** (195K)
- the community **VFE [CLASSIC] fork** (117K)
- the **Improvised Silencers 42.20 port** (121K)
- unofficial Brita ports

The mods split into two philosophies: "no such thing as too much" realism (GunFighter) versus "curated, vanilla-style" rosters (VFE, GoM). **Noise is handled mostly through suppressors that trade off** range and durability, with factory-suppressed guns at top rarity. **Jamming is tied to weapon condition.**

### Cited Findings

#### Brita's Weapon Pack + Arsenal[26] GunFighter (B41)
- Brita's Weapon Pack, Workshop 2200148440. 3,301,837 subs (lifetime 5,307,558), 133,609 favorites; created 2020-08-17, last updated 2023-03-13; tagged B41. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2200148440)
- Arsenal[26] GunFighter Mod [2.0], Workshop 2297098490. 2,897,215 subs (lifetime 4,811,406); created 2020-11-24, updated 2023-03-17; tagged B41. "You MUST Update Brita's Weapon Pack, GunFighter[2.0] Requires Most Recent Version". "Single-Player Still Requires ModOptions; Multi-Player uses Sandbox Settings". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2297098490)
- A GunFighter TempPatch (3353217712, 3,531 subs, 2024-10-22) is "A TEMPORARY PATCH UNTIL MAIN UPDATE". — [TempPatch page](https://steamcommunity.com/sharedfiles/filedetails/?id=3353217712)
- **B42 status, from the Brita page header:** "We are trying to fix the mod, no promises....Many of the work-around methods that allow the features of this mod to work have been shut-down and disabled by B42. Some are recoverable, some may not be, some will not be. Everything was affected, and not one single feature spared. It's FUBAR at the moment. - Arsenal[26]". — [Brita page](https://steamcommunity.com/sharedfiles/filedetails/?id=2200148440)
- **Unofficial B42 ports, both despite reupload bans on the originals:**
  - "Brita Weapon and Armor B42 Unified Compatibility Port" (3777433827): 45,158 subs, created 2026-08-04. It "Uses Build 42 reload, chamber, aiming, fire-mode, attachment ... systems" and "Uses vanilla magazines first". — [Port page](https://steamcommunity.com/sharedfiles/filedetails/?id=3777433827)
  - "Brita's B42 gutted Armor and Weapon pack" (3778836814): 10,997 subs. "gutted ... due to missing features ... (e.g. vanilla ammo only, mismatched magazines, missing explosives, etc.)". "This is the same mod that was taken down a couple days ago, I simply reuploaded it." — [Port page](https://steamcommunity.com/sharedfiles/filedetails/?id=3778836814)
  - Brita's page: "Absolutely NO Permission is given ... to re-post or re-publish this mod". — [Brita page](https://steamcommunity.com/sharedfiles/filedetails/?id=2200148440)
- **Philosophy** (GunFighter guide, last updated 2024-10-07, 191,199 visitors): "Brita and I both agree, that there is no such thing as too much ... Some like to use the term 'bloated' without realizing that there are even options to reduce loot". "You can literally make it so NO GUNS SPAWN... or GUNS ARE EVERYWHERE". — [GunFighter v2.0 guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Loot controls:**
  - "YES you can disable (or reduce) items produced Post~1992".
  - Caliber filters also remove that caliber's ammo boxes and dedicated magazines.
  - Categories include "Fully Automatic (Rifle Caliber)" and "Fully Automatic (Pistol Caliber)", and "Non-Hunting in Hunting locations".
  - "Conceal Carry Handguns can be found in 'Fanny Packs' and 'Purses' on Civilian zombies".
  - Gun cases in residences, and a vehicle loot reducer.
  
  — [Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Ammo and magazines:**
  - "We decided to use a 'Generic' magazine approach where ever possible ... to avoid over-saturating the loot ... if the magazine (of the same caliber) is within 1-2 rounds, it will use the generic mag type."
  - Visibly detachable magazines, and a clip / magazine / speedloader distinction.
  - Auto-select of the next magazine type.
  - "DROPPING A MAGAZINE TO THE GROUND Is about 1-3 seconds ... faster than retaining the ejected magazine".
  - Stripper clips, Emergency Reloading, Alternate Loading Methods.
  - Ammo reloading from "Empty Shell or Casing", "Primer", "Powder", "Projectile".
  - Spent-casing ejection, with a warning that accumulated items hurt performance.
  
  — [Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Muzzle devices and noise.** "There are (6) categories of muzzle attachment": suppressor ("Primarily reduces sound level, and slightly mitigates recoil"), muzzle brake, compensator, comp/brake combo, linear comp and shotgun choke. "Linear Comps will reduce sound by about 15-20% ... but will NOT change the sound signature in-game". Suppressors include pistol, rifle, .50 BMG and shotgun types, plus improvised ones: "Soda Bottle + Duct Tape" and "Oil Filter + Solvent Trap Adapter". — [Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Attachment trade-offs:**
  - Grenade-launcher attachments: "the large bulky additional weight has a negative effect ... will reduce overall accuracy".
  - Fore-grips: "improve aim time and reduce recoil slightly".
  - Bayonets: they enable a melee mode, but "there is an accuracy penalty when firing with a Bayonet attached ... increases minimum range slightly ... makes aiming slightly slower".
  - Variable optics: extend "[Max] range, at the cost of loosing effective [Min] range".
  - Lights and lasers need battery charging, with an optional "Toggle Laser on automatically when aiming".
  
  — [Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Melee and thrown weapons:**
  - "Swinging Sectional" weapons: nunchucks, "Lock on a belt", "Ball in a sock".
  - "Thrown Mode" for knives, some axes and spears.
  - "Variable Grip Modes" for butterfly knife, karambit, ASP baton and others; "(3) kinds" of chainsaws.
  - Thrown weapons "had to be coded from scratch with similar rules as firearms", using "a weighted combination" of stats for hit chance.
  - Archery, slingshots, flamethrowers, rocket launchers and PCP air guns are also covered.
  
  — [Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Planned but not shipped as of the guide:** "Suppressor and Bayonet Condition", "Crouched and Prone Shooting Support", "Dynamic Scope Bonus", "Grenades (Cooking Off)" — all "Not Applicable Until Next Update". — [Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- **Balance knobs:** damage multipliers "for General firearms from (50% to 200%)", the same for melee and archery. Incompatible with "Real Full Auto" and the "Snakes" mod pack. — [Brita page](https://steamcommunity.com/sharedfiles/filedetails/?id=2200148440)

#### Vanilla Firearms Expansion (VFE): B41 original, plus a B42 community fork
- B41 original, Workshop 2667899942: 1,013,344 subs (lifetime 1,988,663); created 2021-11-29, updated 2024-09-30. "This upload will no longer be updated (I literally can't) but a B42 branch will happen when it's ready. I will keep this mod up for both B41 users and as a memorial. - Vilespring". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2667899942)
- Co-author Stendo_Clip (Michael Shtudiner) died on Feb 17, 2025. Vilespring said: "I am still planning on making the B42 update". The article is dated Feb 21, 2025. — [Destructoid](https://www.destructoid.com/the-creator-of-one-of-project-zomboids-best-mods-has-passed-away/)
- **Content:** "23 new firearms (and their magazines), 6 attachments, and two new calibers", plus linked .308 for an M60 that "will drop the links while shooting". Each gun is tagged with a rarity (Common to Extremely rare); e.g. "MP5SD ... Very rare suppressed". Attachments were rebalanced ("you cannot mount a red dot sight on most handguns"). — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2667899942)
- **Jamming rework:**
  - "In vanilla when a weapon jams it consumes a round when it is unjammed. With VFE the round is returned if the gun is completely unloaded before clearing."
  - "In vanilla a 90% M16 only has a 50% chance of getting through a magazine without jamming. Now guns only begin to jam at 75% or 70%. They also start to jam more than vanilla guns do at 25% or 20%."
  - "Manually cycled guns can jam now ... when a round is chambered."
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2667899942)
- Asked whether it has suppressors: "No. They're not off the table but they are also not a priority." On Brita/Arsenal: "They are incompatible at the lua level. VFE is also designed around its own balance design". "Many more zombies in the world can spawn with firearms on them." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2667899942)
- **B42 history:**
  - A "[42][Discontinued] Vanilla Firearms Expansion" item (3611718925) appears in search results, but the API returned not-found on 2026-10-05. — [Search-result URL](https://steamcommunity.com/workshop/filedetails/?id=3611718925)
  - The active B42 version is a fork, "[B42] Vanilla Firearms Expansion [CLASSIC]" (3761077099) by Sejbr/PolishCow: 117,290 subs, created 2026-07-09, updated 2026-09-08. "One of the original authors, Stendo_Clip, has passed away. This fork keeps the mod running." — [Fork page](https://steamcommunity.com/sharedfiles/filedetails/?id=3761077099)
- **VFE CLASSIC (B42) mechanics:**
  - "Around 40 firearms", with attachments: "optics, bipods, slings, recoil pads, choke tubes, ammo straps and coupled magazines".
  - "Craftable ammunition packing, integrated with vanilla's own recipes".
  - Loot "by rarity tier ... Common weapons turn up in houses, cars and pawn shops; rare ones concentrate in police and military locations".
  - An admin panel for "per-weapon and per-class tuning: damage, fire rate, jamming, reload speed, range, loot density and rounds per ammo box. Changes apply live and sync to connected clients."
  - "Built and tested on a dedicated PvP server. Server-authoritative where it matters."
  
  — [Fork page](https://steamcommunity.com/sharedfiles/filedetails/?id=3761077099)
- **VFE Post 93 [CLASSIC]** (3762355926): 42,756 subs, "15 modern firearms". "Three of them come suppressed from the factory ... They carry noticeably shorter noise ranges than their unsuppressed counterparts." "The AA12, MK12-SD and DN-418S sit at the top of the scale and concentrate in military and SWAT locations." — [Post 93 page](https://steamcommunity.com/sharedfiles/filedetails/?id=3762355926)
- A STALKER pack fork (3761284354) has 21,064 subs. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3761284354)

#### Firearms (Hyzo) and Firearms B41 Revamped
- "Firearms", Workshop 2256623447: 1,068,224 subs (lifetime 2,064,917); created 2020-10-13, updated 2026-04-05; tagged B41, B42 and Multiplayer.
  - Adds Glock 17, Colt SAA, MP5 (with MP5SD), UZI, Marlin 1894, FN FAL, M60, Ithaca 37, Remington 870, Ruger M77/22, M24, SKS and AKM, plus calibers 7.62x39mm, .44-40 WCF, .22 LR and 10mm.
  - "sandbox settings for suppressor efficiency and rarity, as well as improvised suppressor breakage".
  - "B42 Build is tested and works ... with B42.16.1" (not the current 42.20).
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=2256623447)
- The attribution to Hyzo comes from the Revamped page ("Original mod made by Hyzo"). The Workshop title no longer says "B41". — [Firearms B41 Revamped](https://steamcommunity.com/sharedfiles/filedetails/?id=3243752606)
- **Firearms B41 Revamped** (3243752606): 101,589 subs, B41.
  - "Working gun lights", "Fix bayonet", "Saw off any rifle or shotgun".
  - "Silencers. All weapons excluding revolvers and shotguns may be installed with a silencer if the caliber is matching. Silencer wear overhaul, with new silencer condition system."
  - The author recommends players "lower the spawn rate of guns, as default vanilla spawn rates are very high".
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3243752606)

#### New B42-era leaders
- **Guns of Marz (GoM)**, Workshop 3722134990, title "[42.20.4MP] GoM - Guns of Marz": 442,796 subs (lifetime 576,798); created 2026-05-08, updated 2026-09-20. "This mod requires Gunworks Framework." — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3722134990)
  - Features: "Real Automatic Fire-rate", "Foldable Stocks and Bipods", "Bayonets", "Underbarrel Grenade Launchers", "Multiple Magazines for weapons with seamless swapping", "Animated Weapon Parts", "Multiple ammo support and mix ammos in weapons or magazines", "Custom tracers", "Dynamic Attachments", "Curated list of guns to fit the game setting". — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3722134990)
- **B42 Real Firearms**, Workshop 3238830225, a Chinese/English mod: 194,621 subs; updated 2026-09-01; WIP. — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3238830225)
  - "Real firearms rate of fire", "Real firearms sound sampling (each firearm has its own sound effect)", "Real firearms weight".
  - Spawn tiers: "Military Spawn - 48 Guns", "Police Spawn - 17 Guns", "Civilian Spawn - 37 Guns", each tied to location and zombie outfit types.
  - Maintenance "Using WD40 metal lubricant" with "Aiming, Mechanics, Metal Welding ... All 3 skills used together give better repair".
  - "THIS MOD REMOVES ITEMS RELATED TO VANILLA FIREARMS".
  
  — [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3238830225)
- **Guns of 93:**
  - B41 (3077078907): 109,001 subs. — [B41 page](https://steamcommunity.com/sharedfiles/filedetails/?id=3077078907)
  - "Guns of 93: B42 Test Build" (3183820077): 39,814 subs, updated 2026-10-01. It reworks guns with "removable parts". "Fire modes and laser sights can now be toggled via hotkeys ... TAB toggles fire modes and V toggles laser sights". It "actively removes vanilla firearms unless you deactivate it within the sandbox". It lists multiplayer sync issues with icons and upgrades. — [B42 test page](https://steamcommunity.com/sharedfiles/filedetails/?id=3183820077)
- **Others:**
  - P.S.A. Post-Soviet Armory (2891251749): 152,416 subs, tagged B41. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2891251749)
  - "[B41] [B42] CJ Firearm [Discountiuned]" (2874163136): 149,960 subs. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2874163136)

#### Suppressor mods: the main noise lever
- "Improvised Silencers by Maxwell218" (2799742455): 402,299 subs, B41, last updated 2024-07-30. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2799742455)
- "Improvised Silencers - Build 42.20 Compatibility" (3779164273): 121,202 subs, created 2026-08-07. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3779164273)
  - "Five different craftable suppressors": professional, metal pipe, hand torch, water bottle, and "Potato suppressor: a deliberately weak one-shot gag attachment".
  - "Different noise-reduction and weapon-range trade-offs", and "11 new suppressed weapon sounds".
  - Optional "Extended Realism Mode": "Configurable noise-reduction values", "Optional suppressor durability", and "caliber-based wear: small calibers consume less durability, while rifle and shotgun ammunition consume more".
  - "A screwdriver is required to attach or remove the four standard suppressors".
- **Conflicting compatibility claims:** GoM says "Improvised Silencers will break the attachment logic". The 42.20 port claims "Automatic Guns of Marz compatibility". GoM may be referring to the original or an older version; unresolved. — [GoM](https://steamcommunity.com/sharedfiles/filedetails/?id=3722134990); [Silencers port](https://steamcommunity.com/sharedfiles/filedetails/?id=3779164273)

#### Melee alternatives
- **Scrap Weapons!** (2122265954): 1,195,478 subs (lifetime 2,418,544), B41, last updated 2023-03-05. "adds a ton of new post apocalyptic / homemade melee weapons ... Most weapons are upgrades from vanilla weapons", with a "Weapons" crafting tab and recipe magazines. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2122265954)
- **[B42 Stable] ScrapSmith Medieval Weapons and Armor** (2730784492): 60,516 subs, updated 2026-08-24. "over 30 fully custom craft-able medieval style melee weapons and armor"; recipes are found "in the wild". — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2730784492)
- **Melee Weapon Upgrade** (3394923321, B42): 19,945 subs. "At levels 2, 4, 6, 8, and 10, you can upgrade your melee weapons to stages II, III, IV, V, and VI". It needs "a hammer, 5 nails, 2 leather pieces, and the same weapon". — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3394923321)
- **Melee Weapon Upgrades - B42** (3649292581): 6,008 subs. "Weapons can be upgraded through 6 tiers, increasing durability and effectiveness", using upgrade kits and difficulty modes; SP and MP. — [Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3649292581)

#### Weapon mods as the loot source for NPC fights
- Bandits loads weapon mods into NPC loadouts: GunFighter/Brita (Jul 4, 2024), Guns of 93 (Aug 17, 2024) and VFE (Aug 29, 2024). — [Changelog p26](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=26); [p22](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=22)
- An integration pack lets "SWAT team from Day One ... carry MP5s from Firearms mod". — [Bandits Expansion Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3474469914)
- Extra Options lists compatible weapon mods: Brita's, Firearms, Firearms Revamped, VFE, CJ, Rain's, Real Firearms, Guns of 93 (B41/B42) and Post Soviet Armory. — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)

### Inferences
Weapon roster lessons that balance noise against effectiveness. All are my inferences.
- **Noise works best as a property you buy down with trade-offs, not a fixed stat.** Across mods, suppressors cost range or damage, durability (wear by caliber; improvised ones break), crafting time and a tool (screwdriver). Factory-suppressed guns sit at the top rarity tier.
- **A clean mobile version:** each weapon class has a base noise radius. A suppressor slot cuts noise by X% but adds a durability bar and a range penalty, and improvised suppressors are cheap but last N shots.
- **Linear comps** (15–20% less noise without changing the "signature") suggest a middle tier. Noise could have two numbers: radius (who hears) and signature (whether it reads as gunfire).
- **Noise has two audiences.** Bandits made zombies head to NPC gunfire. So the noise budget of a human firefight should also set how soon a horde arrives. That makes melee, bows and slingshots meaningful even with guns available.
- **Reliability tied to condition beats random jamming.** VFE's curve means good-condition guns are reliable and bad ones jam a lot. That gives a maintenance loop (Real Firearms: WD40 plus skills) without feeling random. Returning the round on unjam avoids feel-bad.
- **Roster size: avoid ammo sprawl.** GunFighter's generic magazines were added "to avoid over-saturating the loot", and critics call it "bloated". GoM and VFE sell "curated" and "vanilla-style" rosters. For mobile, a few ammo families (pistol / rifle / shotgun / special) and around 10–15 weapon archetypes is likely enough.
- **Enemy loadout tiers mirror loot tiers.** Civilian, police and military gun pools (Real Firearms, VFE CLASSIC) match the NPC loadout presets (Extra Options). Defeating a better-armed faction is how the player gets better guns, a natural risk-reward loop for human fights.
- **Melee alternatives with mechanical identity:**
  - thrown mode (knives, axes, spears)
  - bayonet mode that costs ranged accuracy and adds a minimum range
  - variable grips (fast vs strong)
  - tiered crafting upgrades
  
  These keep melee relevant when noise matters.

### Gaps
- **No vanilla noise-radius numbers per weapon were collected.** pzwiki.net returned HTTP 403, so mods' noise values cannot be compared with the B42 vanilla baseline.
- GunFighter's handling of jamming, cleaning and dirt was not found in the extracted guide text: no "jam" matches. It may not have such a system, or it may be described elsewhere; unknown.
- Gunworks Framework (which powers GoM) was not investigated: its Workshop ID, subscriber count and mechanics are unknown.
- Whether Brita/Arsenal will ship an official B42 version, or a date for one, is unknown. Only the "no promises" header was found.

---

## 4. What do players praise or complain about in these mods?

### Takeaway
**Praise** centres on Bandits making humans a real threat ("Treat them as actual players"), on Week One and The Ark as story experiences, and on the depth of realism in the gun packs.

**Complaints** centre on unfairness more than difficulty: bandits always knowing where you are, too many spawns, off-screen shots, and RNG-driven deaths. Bugs, performance and unpredictable NPC behaviour (Week One) also feature, along with "bloat" (GunFighter) and abandonment or B42 breakage (SS, Brita).

The direct evidence is thin: comment sections on Bandits and Week One are disabled, and Reddit was not reachable. Much of this question therefore rests on **indirect evidence**: which fixes third-party modders built, and what authors wrote in their FAQs.

### Cited Findings
- **Scale and ratings** (a positive signal):
  - Bandits: 10,660 ratings and 50,402 favorites. — [Bandits](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
  - Week One: 8,275 ratings and 30,101 favorites. — [Week One](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
  - Superb Survivors: 8,754 ratings. — [SS](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104)
  - SSC: 1,024 ratings, "predominantly positive (5-star dominant)" per a page summary. — [SSC](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778)
- **Hostility toward authors:** Bandits: "Comments section disabled because of hostility." Week One: "Comment section disabled due to continued hostility." — [Bandits](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204); [Week One](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- **Unverified exact wording** (a search engine's summary of Steam discussions on Bandits and Day One):
  - Spawn rate "considered too high by many players".
  - A request that "bandit waves should not always know where you are, making hiding a viable option, and bandits should be able to give up and leave".
  - Advice to set bandits to "only shoot from a minimum distance away" to avoid "getting shot by random strangers off-screen".
  - A veteran saying that without the mod they survive indefinitely, but with bandits "it's very hard to survive one week ... heavily dependent on RNG".
  
  — [Bandits discussion](https://steamcommunity.com/workshop/filedetails/discussion/3268487204/598537454201510909); [Bandits discussion 2](https://steamcommunity.com/workshop/filedetails/discussion/3268487204/4509876644765072678); [Day One discussion](https://steamcommunity.com/workshop/filedetails/discussion/3329251514/6633328326834948690)
- **The same complaints, institutionalised as fixes:**
  - Extra Options' first-listed features include preventing bandits "from knowing your location without ever seeing you" and a melee anti-animation-cancel rebalance. — [Bandits Extra Options](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512)
  - Fix Plus's section "Bandits do not know where you are" says: "You are supposed to have the advantage of knowing where they are. They should not have the same advantage over you." — [Bandits Fix Plus](https://steamcommunity.com/sharedfiles/filedetails/?id=3777752751)
- **Week One** (unverified wording, a search summary of Week One Steam discussions):
  - Praise that the mod "re-imagined the game"; NPCs playing piano.
  - "one of my favorite mods despite being so buggy and at time unplayable".
  - NPCs "unintelligent" and crashes.
  - Feeling forced into conflicts, e.g. being blamed for a car kill the player didn't commit.
  - NPCs breaking into player houses.
  
  — [Week One discussion](https://steamcommunity.com/workshop/filedetails/discussion/3403180543/523083364935259369); [Week One discussions index](https://steamcommunity.com/sharedfiles/filedetails/discussions/3403180543)
- **Author's framing of expectations:** "This mod isn't meant to be a faithful simulation of reality ... it's supposed to be funny". "Don't expect a peaceful experience either ... Things escalate quickly". — [Week One](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543)
- **GunFighter "bloat" criticism, acknowledged by the author:** "Some like to use the term 'bloated' ... there are plenty of mods that do the minimalist theme. This is not one of those." — [GunFighter guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2943058179)
- A curated list says the Brita/GunFighter combo "adds a slew of ammo types that may confuse players at first" and calls "B41 Firearms" "an all-timer". This was **not fetched; article date unknown, possibly outdated**. Its claim that Firearms is "not compatible with Multiplayer" **conflicts** with the Firearms Workshop page's Multiplayer tag. — [GameRant](https://gamerant.com/project-zomboid-best-weapon-mods/); [Firearms page](https://steamcommunity.com/sharedfiles/filedetails/?id=2256623447)
- **Superb Survivors pain points**, as the fork author documented them: FPS collapse, cowardly fleeing, "RKO" attacks while fleeing, idle NPCs, and "I wouldn't trust the NPCs to do much besides dying and attacking". — [SSC](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778)
- **Demand for NPCs, and frustration aimed at the developers** (a user comment): "why are the devs taking tooooooooo much time ... just focus on the damn npcs". — [PZNS discussion thread](https://steamcommunity.com/workshop/filedetails/discussion/3001908830/3812910027113381244/)

### Inferences
- Players accept deadly humans but reject **invisible causes of death**: omniscient tracking, off-screen hits, spawns inside safe areas. For a mobile game, every enemy shot should come from a visible or telegraphed source, and every enemy's knowledge should have a visible reason (they saw you, or heard your shot).
- **Emergent chaos is praised and criticised in the same breath** ("favorite ... despite being so buggy"). Week One's "it's supposed to be funny" framing is a deliberate expectation-setting tactic. A commercial mobile game cannot rely on that tolerance.
- Weapon variety appeals to enthusiasts, but **ammo-type sprawl confuses** casual players. Mobile should favour a curated roster.

### Gaps
- **Reddit (r/projectzomboid) could not be accessed.** The JSON endpoint returned an HTML challenge page, so there are no first-hand Reddit quotes.
- The Bandits and Week One comment sections are disabled, and the discussion pages fetched directly returned Steam error pages. The complaint wording above comes from search-engine summaries and is unverified.
- No systematic sentiment data (e.g. rating distributions per mod) was gathered.

---

## 5. Popularity and build support: Workshop subscriber counts (seen 2026-10-05), B41/B42 status as of October 2026, and the official status of vanilla NPCs

### Takeaway
**NPC mods:** Bandits (1.04M) is the only maintained human-NPC engine at scale on B42 stable. Week One (330K) and The Ark (54K) are Slayer's scenarios on top of it. Superb Survivors (385K) and SSC (37K) are B41-only and frozen since 2023.

**Weapon mods:** B41 legacy items still top raw counts: Brita 3.30M, GunFighter 2.90M, Scrap Weapons 1.20M, Firearms 1.07M, VFE 1.01M. The B42-native field is led by Guns of Marz (443K in about 5 months), Real Firearms (195K), the Improvised Silencers port (121K) and the VFE CLASSIC fork (117K).

**Vanilla NPCs:** official human NPCs remain a planned, undated future build. The first NPC build was described in 2022 as "wide, but perhaps shallower".

### Cited Findings
- **How the counts were collected:** `subscriptions`, `lifetime_subscriptions`, `favorited`, `time_created`, `time_updated` and `tags` from the Steam Web API on 2026-10-05. — [Steam API](https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/)

**Human-NPC mods** (dates are created → updated)

| Mod (author) | Workshop ID | Current subs | Lifetime subs | Created → updated | Build / mode | Source |
|---|---|---|---|---|---|---|
| [B42] Bandits NPC (Slayer) | 3268487204 | 1,043,650 | 1,650,930 | 2024-06-15 → 2026-10-04 | B42 only, "B42.20+", SP+MP | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204) |
| Superb Survivors! (nolanritchie) | 1905148104 | 385,094 | 1,025,534 | 2019-11-03 → 2023-02-05 | B41 (41.73), SP only | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=1905148104) |
| [B42] Week One NPC (Slayer) | 3403180543 | 330,249 | 651,565 | 2025-01-08 → 2026-08-07 | B42 "42.19 or 42.20 / stable"; no MP tag | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3403180543) |
| [B42] Bandits Creator (Slayer) | 3469292499 | 144,573 | 286,299 | 2025-04-23 → 2026-08-21 | B42, SP+MP | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3469292499) |
| The Ark (Slayer) | 3707475814 | 54,394 | 104,258 | 2026-04-15 → 2026-09-29 | B42 "42.20 or 42.21 Stable", SP only | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3707475814) |
| Bandits Extra Options (3rd party) | 3412682512 | 42,592 | 137,489 | 2025-01-23 → 2025-02-28 | tags B41+B42, MP | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412682512) |
| [B42] Bandits Expansion Pack (Slayer) | 3474469914 | 39,762 | 107,686 | 2025-05-02 → 2025-05-02 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3474469914) |
| Bandits Radio Expansion 42.20 MP (unofficial) | 3630494926 | 38,869 | 79,639 | 2025-12-24 → 2026-09-15 | B42.20, MP | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3630494926) |
| Superb Survivors Continued | 2980672778 | 36,923 | 122,577 | 2023-05-26 → 2023-07-06 | B41, SP only, abandoned | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2980672778) |
| PZNS NPC Framework | 3001908830 | 23,577 | 67,792 | 2023-07-09 → 2026-08-18 | tagged B41, no MP | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3001908830) |
| [B42.20] Bandits Fix Plus (3rd party) | 3777752751 | 16,714 | 22,960 | 2026-08-04 → 2026-09-07 | B42.20, MP | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3777752751) |

**Weapon mods** (dates are created → updated)

| Mod | Workshop ID | Current subs | Lifetime subs | Created → updated | Build | Source |
|---|---|---|---|---|---|---|
| Brita's Weapon Pack | 2200148440 | 3,301,837 | 5,307,558 | 2020-08-17 → 2023-03-13 | B41; B42 "FUBAR" | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2200148440) |
| Arsenal[26] GunFighter Mod [2.0] | 2297098490 | 2,897,215 | 4,811,406 | 2020-11-24 → 2023-03-17 | B41 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2297098490) |
| Scrap Weapons! (melee) | 2122265954 | 1,195,478 | 2,418,544 | 2020-06-07 → 2023-03-05 | B41 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2122265954) |
| Firearms (Hyzo) | 2256623447 | 1,068,224 | 2,064,917 | 2020-10-13 → 2026-04-05 | B41.78.16 + B42 (tested 42.16.1) | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2256623447) |
| [VFE] Vanilla Firearms Expansion (B41) | 2667899942 | 1,013,344 | 1,988,663 | 2021-11-29 → 2024-09-30 | B41 (memorial) | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2667899942) |
| [42.20.4MP] GoM - Guns of Marz | 3722134990 | 442,796 | 576,798 | 2026-05-08 → 2026-09-20 | B42, MP; needs Gunworks | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3722134990) |
| Improvised Silencers (Maxwell218) | 2799742455 | 402,299 | 886,399 | 2022-04-25 → 2024-07-30 | B41 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2799742455) |
| B42 Real Firearms (WIP) | 3238830225 | 194,621 | 381,548 | 2024-05-04 → 2026-09-01 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3238830225) |
| P.S.A Post-Soviet Armory | 2891251749 | 152,416 | 386,994 | 2022-11-20 → 2025-12-01 | tagged B41 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2891251749) |
| CJ Firearm [Discontinued] | 2874163136 | 149,960 | 394,635 | 2022-10-11 → 2025-12-01 | B41/B42 tags | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2874163136) |
| Improvised Silencers – B42.20 port | 3779164273 | 121,202 | 143,886 | 2026-08-07 → 2026-08-24 | B42.20+ | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3779164273) |
| [B42] VFE [CLASSIC] (fork) | 3761077099 | 117,290 | 145,606 | 2026-07-09 → 2026-09-08 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3761077099) |
| Guns of 93 (B41) | 3077078907 | 109,001 | 280,890 | 2023-11-09 → 2025-09-28 | B41 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3077078907) |
| Firearms B41 Revamped | 3243752606 | 101,589 | 240,059 | 2024-05-10 → 2024-10-28 | B41 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3243752606) |
| ScrapSmith Medieval (melee) | 2730784492 | 60,516 | 133,051 | 2022-01-25 → 2026-08-24 | "B42 Stable" | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=2730784492) |
| Brita B42 Unified Compatibility Port (unofficial) | 3777433827 | 45,158 | 65,194 | 2026-08-04 → 2026-09-17 | B42.20.x | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3777433827) |
| [B42] VFE Post 93 [CLASSIC] | 3762355926 | 42,756 | 56,205 | 2026-07-11 → 2026-09-08 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3762355926) |
| Guns of 93: B42 Test Build | 3183820077 | 39,814 | 75,778 | 2024-03-14 → 2026-10-01 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3183820077) |
| Melee Weapon Upgrade | 3394923321 | 19,945 | 57,034 | 2024-12-29 → 2025-08-17 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3394923321) |
| Brita's B42 "gutted" pack (unofficial reupload) | 3778836814 | 10,997 | 17,709 | 2026-08-06 → 2026-08-07 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3778836814) |
| Melee Weapon Upgrades - B42 | 3649292581 | 6,008 | 11,666 | 2026-01-18 → 2026-08-09 | B42 | [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3649292581) |

- **Not retrievable on 2026-10-05** (API result 9): Knox Event Expanded (3397396843), Day One (3329251514), Week One B41 (3420587101), "[42][Discontinued] Vanilla Firearms Expansion" (3611718925), an "Arsenal(26) GunFighter" item (2762815930), Rain's Firearms (3387222454), and the original VFE Post 93 (3007780511). — [Steam API](https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/)
- **Bandits dropped B41 at some point after spring 2025.** It still shipped a "b41 error during spawning in multiplayer fix" on Apr 28, 2025. The page now reads "B42 ONLY (B42.20+)". — [Changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204); [page](https://steamcommunity.com/sharedfiles/filedetails/?id=3268487204)
- An aggregator article targeting 42.19 listed Bandits as "B42.18+". This is **outdated**: the page now requires 42.20+. — [pzfans](https://pzfans.com/zomboid_npc_mods_in_b42_surviving_the_apocalypse_with_friends/)
- **Evidence consistent with B42 stable arriving around July 2026:**
  - Bandits changelog "Jul 30 [2026]: 42.20 / stable quickfix". — [Changelog p3](https://steamcommunity.com/sharedfiles/filedetails/changelog/3268487204?p=3)
  - The Ark: "Use 42.20 or 42.21 Stable". — [The Ark](https://steamcommunity.com/sharedfiles/filedetails/?id=3707475814)
  - The VFE CLASSIC fork appeared 2026-07-09 and the Brita ports in August 2026. — [VFE CLASSIC](https://steamcommunity.com/sharedfiles/filedetails/?id=3761077099); [Brita port](https://steamcommunity.com/sharedfiles/filedetails/?id=3777433827)
- **Vanilla NPCs, brief context:**
  - **Outdated, 2022:** The Indie Stone said the first NPC build (Build 43) would have "a wide, but perhaps shallower, NPC system". Planned features: "a way to get NPCs to join your group", help with "crafting, cooking building and hauling and other safehouse tasks", "combat support on your travels and NPC threats to look out for", and a meta-simulation. The studio cautioned that plans "could change". Article dated March 4, 2022. — [NME](https://www.nme.com/news/project-zomboid-studio-shares-what-first-npc-update-will-include-3175952)
  - An aggregator (undated, targets 42.19): "Official human NPCs are still a future roadmap item (often associated with Build 43 in older posts); treat any release date as a plan, not a guarantee." — [pzfans](https://pzfans.com/zomboid_npc_mods_in_b42_surviving_the_apocalypse_with_friends/)
  - A 2026 hosting-company roadmap article, **seen only as a search snippet and unverified**, says there is no public stable date for Build 43 and NPCs should not be expected in 2026. — [Supercraft](https://supercraft.host/article/project-zomboid-roadmap-2026/)

### Inferences
- **Raw "current subscribers" overstate live usage of dead B41 mods.** Steam subscriptions persist until users unsubscribe. Brita (3.3M), GunFighter (2.9M) and Superb Survivors (385K) mostly reflect legacy reach. For "what people use on B42 stable now", growth rate is the better signal: GoM went from 0 to 443K in about 5 months, and VFE CLASSIC from 0 to 117K in about 3 months.
- **The ecosystem pattern on B42:** big B41 packs broke because B42 changed core firearm systems (reload enum, attachments, recipes). They were replaced by new frameworks (Gunworks) or community forks and ports, some of them unauthorised. Bandits survived by tracking every unstable patch (42.12 → 42.20) at real maintenance cost.
- Because official NPCs are still undated, the "humans as a threat" niche on PC Zomboid is held by one hobbyist-led mod family. That family's design choices (lethal, escalating raiders; light companions) are the de facto genre reference for players.

### Gaps
- No official Indie Stone statement from 2026 about Build 43 / NPC timing was fetched directly; the roadmap claims above come from aggregators.
- Unique-visitor and favorite counts were not collected for every item; the API provides them if needed (`views`, `favorited`).
- The ranking excludes items whose IDs were not discovered. "Most popular" is a ranking among the items found, not a full Workshop crawl. No `QueryFiles` crawl was done: it needs an API key.
