# Frostpunk 2 politics: developer intent, mode differences, and post-launch changes (2022 – Oct 2026)

Research date: 2026-10-05. Source notes:
- Patch, roadmap and DLC data come from the complete official Steam announcement feed for app 1601580. I pulled it through the Steam News API ([feed](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1601580&count=500&maxlength=0&format=json)), so it covers every 11 bit post from Aug 2021 to the latest one on 2026-09-22.
- Steam links below use the canonical form the API returns (`steamstore-a.akamaihd.net/news/externalpost/...`). Each one redirects to the matching announcement on steamcommunity.com.
- "Dev quote" means words attributed to an 11 bit developer. "Journalist" means the outlet's own description or opinion.
- Roles: Jakub "Kuba" Stokalski is FP2 Game Director & Design Director, and Łukasz Juszczyk is FP2 Game Director & Art Director. Interviews often call them "co-directors." Source: [Steam AMA post, 2024-09-10](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076614907521).

## Q1. What design goals did the developers state for Frostpunk 2's politics?

### Takeaway
From 2023 to 2026, 11 bit framed the game the same way each time: Frostpunk 1 was about "surviving nature," and Frostpunk 2 is about "surviving human nature." Once survival no longer forces people to agree, a traumatized society splits along value lines. Politics (Council votes plus communities and factions on value axes) therefore becomes the main field of play. The player is a Steward without absolute power, whose job the developers describe as "negotiating a common future." Authoritarian routes exist but are framed as a choice with a moral cost. Developers said the Council was in the game from the very first build and that it is the system they are "particularly proud of."

### Cited Findings
- **2023-10-02, Juszczyk (dev quote).** "we eventually realized that Frostpunk 1 was not a post-apocalyptic game at all… [it was] a game about surviving the apocalypse as it happened, how a society would be able to make it through that." For FP2, "we thought about what that society would look like after making it, similar to a post-war society, where traditions and customs have been altered because of recent events." — [Game Developer, A. Fillari, 2023-10-02](https://www.gamedeveloper.com/design/frostpunk-2-leans-into-the-human-experience-of-a-city-builder-)
- **2023-10-02, Stokalski (dev quote).** The bleakness "wasn't necessarily a core value of the game, but it did present a good opportunity for us… to examine and look at the idea of a blank slate after the apocalypse." — [Game Developer, 2023-10-02](https://www.gamedeveloper.com/design/frostpunk-2-leans-into-the-human-experience-of-a-city-builder-)
- **2024-04-05, official beta pitch.** Besides the need to survive, "you'll face a new and deadly threat: human nature and its insatiable thirst for power." — [Steam, 2024-04-05](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5756237364311898554)
- **2024-05-28, Stokalski (dev quote).**
  - "Frostpunk 1 was an apocalyptic game, as the world was ending." It was about how to "survive nature."
  - In FP2, "These people, shaped by this ordeal, are now looking to find a future for themselves… they start having different ideas for this future, get pulled apart."
  - Journalist: those differing ideas are built into the faction/community system and follow three binaries: Adaptation vs Progress, Merit vs Equality, Reason vs Tradition.
  - Source: [PC Gamer, J. Wolens, 2024-05-28](https://www.pcgamer.com/games/city-builder/in-frostpunk-2s-post-post-apocalypse-its-not-nature-thats-your-enemy-its-human-nature-and-nothing-proves-that-like-my-doomed-attempt-at-turbo-communism/)
- **2024-05-29, Stokalski (dev quote).**
  - "The question becomes 'Now what?' You've got this blank slate, you've got these traumatized people formed by the ordeal of surviving the end of the world, and they actually start rebuilding now, wanting different things, and having ambitions now."
  - "The Council itself is in the very first build… the way to represent that is through a system like that."
  - "We ended up preferring to worry about being too brave rather than too conservative."
  - Source: [Game Rant, J. Duckworth & G. Johnson, 2024-05-29](https://gamerant.com/frostpunk-2-story-interview/)
- **2024-05-29, Stokalski on the authoritarian option (dev quote).** "There is a way for you to say 'I'm right'… You have the tools to follow your instinct there and make them see your way, but if you don't want to become that type of person, you have to want to make people come together." — [Game Rant, 2024-05-29](https://gamerant.com/frostpunk-2-story-interview/)
- **2024-06-03, Stokalski (dev quote).**
  - "Frostpunk 2 is surviving human nature and its diverging ambitions."
  - In FP1 the survival emergency justified one-sided decisions. When "it's no longer 100% necessary to do this or that, there are different ways of tackling the problems… the differences between the communities can start playing a role."
  - On scale: managing "a metropolis into building a better, brighter future… seeing the clashes and tensions between groups of people rather than individuals."
  - Source: [Screen Rant, L. Faierman, 2024-06-03](https://screenrant.com/frostpunk-2-interview-jakub-stokalski/)
- **2024-07-25, official "City Unbound" Ep. 3, "Negotiating the future."** "As the Steward in Frostpunk 2, you don't wield absolute power. When the people are no longer bound together by the sheer need for survival, they start dividing into communities with different, often conflicting, worldviews. Now the biggest threat is no longer nature but rather human nature." — [Steam, 2024-07-25](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5963413094348379957)
- **2024-08 (published ~08-01, posted on Steam 08-05), "City Unbound" Ep. 4 on the Council Hall and how laws are made and passed.**
  - Official blurb: the Steward is "constantly maneuvering between conflicting interests." — [Steam, 2024-08-05](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5963413728349215085)
  - Secondary paraphrase/translation of Stokalski in the video: the Council seats "representatives of different political parties and social movements." "Every decision made by the player will cause discontent of one of the parties." Leaders pressure the player into decisions that "often… go against the real needs of the population." Civil war is a possible outcome.
  - Source: [gagadget, 2024-08-01](https://gagadget.com/en/484599-political-infighting-is-more-dangerous-than-an-ice-age-frostpunk-2-developers-spoke-about-the-cunning-of-city-council-members-and-the-threat-of-civil-war/). This is a translated summary, not a transcript.
- **2024-09-20, Stokalski (dev quote).**
  - "We are really making an effort to frame all of our political stuff in a way that is speaking to the core of what politics are, which is negotiating a common future." Journalist: as opposed to the technicalities of real parliaments.
  - The team wanted to avoid a "jackass simulator." "No one wants to be an evil person." "You don't set out to do evil things because you want to be evil, you set out to do these things because you are driven by a certain set of values."
  - The Council is what 11 bit is "particularly proud of," a space where "conflicting values directly clash."
  - Source: [Game Developer, B. Francis, 2024-09-20](https://www.gamedeveloper.com/design/frostpunk-2-s-developers-didn-t-want-it-to-be-a-jackass-simulator-)
- **Stokalski, undated, via Wikipedia (aggregator).** "social survival is even more important." "Frostpunk 2 is really about this observation that we can only come together so far to overcome the obstacles in front of us, and that ultimately the biggest enemy is always human nature." Wikipedia also says about 70 people made the game. — [Wikipedia: Frostpunk 2](https://en.wikipedia.org/wiki/Frostpunk_2). I did not check the original source behind this quote.
- **Council structure.** The Council Hall has 100 delegates. Most laws need a simple majority. Laws that give the Steward more power, up to dictatorial authority, need two-thirds. — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- **Official store framing, current page.** "Take the role of a Steward… Navigate through conflicting interests of factions… People of your city want to have a voice in how you run things. Each faction has its own ideology and ideas for the future, yet they also have one thing in common - insatiable thirst for power. Choose your allies in the Council Hall wisely." — [Steam store page](https://store.steampowered.com/app/1601580/Frostpunk_2/)
- **Post-launch continuity, 2025-12-10.** Alex Boiret (Lead Narrative Designer) said Fractured Utopias "logically doubles down on this theme, by giving each faction unique tools leading up to their ideal society." — [Xbox Wire, 2025-12-10](https://news.xbox.com/en-us/2025/12/10/frostpunk-2-fractured-utopias/)
- **Post-launch continuity, 2026-06-23.** Adam Mirkowski (Senior Game Designer, Project Lead on Breach of Trust):
  - "despite amplifying the survival aspect, we also wanted it to be a story about society, as Frostpunk should be."
  - The eruption is "a catalyst that changes the dynamics within a broken nation. It is an event that can either forge unity or destroy society altogether."
  - Source: [Steam, 2026-06-23](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474)

### Inferences
- The stated goal has three parts. The theme is that human nature replaces nature as the main threat. The role is a Steward rather than an all-powerful Captain. The method is value conflict expressed through Council votes and factions. All three have stayed stable from the 2023 previews through the 2026 DLC.
- The developers often point to the Council as the centerpiece: "first build," "particularly proud," "conflicting values directly clash." This supports the "politics as the core loop" framing in substance, although that exact phrase was not found.
- Calling choices "value-driven, not evil" is both a tone rule (no "jackass simulator") and a systems rule. Factions and Zeitgeist are built on values, so harsh choices read as ideological rather than sadistic.

### Gaps
- I did not find the exact phrase "politics as the core loop" in any developer statement.
- A search-engine summary credited Stokalski with the phrases "convenient authoritarianism" (about FP1's Captain) and "axes of values" (about faction design). The likely source is the Epic Games Store interview ([link](https://store.epicgames.com/news/frostpunk-2-exclusive-interview-leave-your-fingerprint-on-a-frozen-world)), but it returned 403 or a JavaScript-only shell, so these phrases are **unverified**.
- Game Rant's 2024-05-28 Council Hall interview ([link](https://gamerant.com/interconnected-systems-frostpunk-2/)) loaded without its article body. Its quotes are not captured.
- The Reddit r/Games AMA with Stokalski and Juszczyk on 2024-09-12 ([thread](https://www.reddit.com/r/Games/comments/1fdimn9/ama_we_are_11_bit_studios_frostpunk_2_game/)) is confirmed by [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076614907521). Reddit blocked retrieval, so the answers are not captured.
- The City Unbound dev-diary videos (Ep. 1–9, Jul 2024 – May 2025) were only available as Steam blurbs. I found no transcripts.

## Q2. Did the developers discuss what they kept or changed from Frostpunk 1's Book of Laws and Hope/Discontent, and why?

### Takeaway
The developers explain the change mainly through the story premise. In FP1, the apocalypse justified a Captain who ruled by decree. In FP2, a society that has survived wants representation, so laws now pass through a 100-seat Council, and the old one-man authority is something you can choose to take back. **I found no developer statement explaining why Hope/Discontent became Trust/Tension, or listing what was kept from the Book of Laws.** Detailed system comparisons come from journalists. The Captain-style route survives as an in-game option (the "Captain's Authority" Rule law and the "Stage Coup" ability), which the patch notes confirm.

### Cited Findings
- **2024-06-03, Stokalski on rule by emergency (paraphrase plus quote).** FP1's survival emergency gave players a convenient justification for one-sided decisions. When "it's no longer 100% necessary… the differences between the communities can start playing a role." — [Screen Rant, 2024-06-03](https://screenrant.com/frostpunk-2-interview-jakub-stokalski/)
- **2024-06-03, Stokalski on the sequel trade-off.** He named the strategy-sequel paradox: make "Frostpunk 1.5" and get called "DLC," or innovate for real. He said FP2 keeps the "mood and tonal pillars" and "choices, and your agency" despite the mechanical changes. — [Screen Rant](https://screenrant.com/frostpunk-2-interview-jakub-stokalski/)
- **2023-10-02, Juszczyk.** FP1 was not post-apocalyptic but about surviving the apocalypse as it happened. FP2 is like "a post-war society." — [Game Developer](https://www.gamedeveloper.com/design/frostpunk-2-leans-into-the-human-experience-of-a-city-builder-)
- **2024-05-28, PC Gamer, journalist's description (not a dev quote).**
  - "In the first game, your authority was pretty much untrammelled. Passing laws was a matter of decree: You waved your hand and whole new social orders sprang into being."
  - In FP2, policies need "a lengthy parley with the city's factions and a tense vote in parliament."
  - The writer's opinion: the politics "feel like a natural evolution of the first-game's comparatively rudimentary Discontent/Hope and Order/Faith systems, forcing you to consider what your citizens want and not just what they need."
  - Source: [PC Gamer, 2024-05-28](https://www.pcgamer.com/games/city-builder/in-frostpunk-2s-post-post-apocalypse-its-not-nature-thats-your-enemy-its-human-nature-and-nothing-proves-that-like-my-doomed-attempt-at-turbo-communism/)
- **2024-08-22, official, on keeping FP1's "human dimension."** City Unbound Ep. 6 covers changes "to ensure smooth gameplay even with the increased city scale and also to better highlight the human dimension that you loved so much from the previous game." — [Steam, 2024-08-22](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5875595438688369903)
- **The Captain route still exists as a mechanic.**
  - Launch-day notes fixed the "trust bar not changing to 'Captain's Authority' if it was force-passed by 'Stage Coup' ability." Once Captain's Authority is in force, it replaces the Trust readout. — [Steam, 2024-09-20](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517)
  - Patch 1.1.0: "The player will no longer be called Steward after becoming a Captain." — [Steam, 2024-10-21](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562)
  - Hotfix 1.2.3: "While Captains Authority is active, Guided Voting will no longer apply." — [Steam, 2025-01-28](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1789580505470820)
  - Power-granting laws need a two-thirds majority. — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- **Trust is a lose condition.** Patch 1.2.0: "Trust Fail game over screen will now pop with a delay rather than right after voting." — [Steam, 2024-11-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832)
- **Tension is the societal-conflict meter.** Fractured Utopias lets you "permanently resolv[e] all the Tension" by completing a faction Utopia. — [Steam store: Fractured Utopias](https://store.steampowered.com/app/2791510/Frostpunk_2_Fractured_Utopias/)
- **Lineage note, 2026-01-14.** 11 bit's remake *Frostpunk 1886*, planned for 2027, keeps FP1's Book-of-Laws-style ideological paths and adds "a completely new Purpose path, alongside the existing Faith and Order paths." The two models (decree with ideological paths vs Council politics) continue as parallel products. — [Steam, 2026-01-14](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1821922921811357)

### Inferences
- The FP1-to-FP2 mapping below is inferred from mechanics and has no developer source.
  - Book of Laws (decree) → Council votes on laws, with "Captain's Authority" as the way back to decree.
  - Hope → Trust in the Steward, a legitimacy meter that ends the game at failure.
  - Discontent → Tension, conflict between groups.
  - Faith/Order paths → value-axis factions and Zeitgeist.
- The developers' rationale is consistently narrative: the context that justified authoritarianism is gone. They did not give a systems rationale such as balance or readability.

### Gaps
- No developer statement explains renaming or redesigning Hope/Discontent into Trust/Tension.
- No developer statement specifically names the Book of Laws as a model kept or rejected.
- The unverified "convenient authoritarianism" phrase may be the closest relevant quote (see Q1 Gaps).
- An older Game Developer write-up of a GDC talk on FP1's systems ([link](https://www.gamedeveloper.com/design/systems-in-games-like-i-frostpunk-i-can-express-personal-ideas-even-unintentionally)) came up in search but was not reviewed. It may cover FP1's Book of Laws intent.

## Q3. Did they discuss trade-offs (abstraction vs intimacy, readability, pacing, difficulty) or the reasons for specific mechanics (council votes, promises, Heatstamps, tension)?

### Takeaway
Yes, for most of the trade-offs:
- **Scale vs intimacy.** Beta players said they "lost attachment to individuals," so 11 bit added Zoom Stories before launch.
- **Readability.** "it's the decisions you should be struggling with, not the interface." Players should never be "doing notes, doing maths on the side."
- **Power fantasy vs politics.** The team avoided a "jackass simulator" and treated choices as values.
- **Emergent variety.** The Zeitgeist system was built so that "variability" comes from inside the system rather than from "whack-a-mole" fixes.
- **Difficulty and complexity.** These were the subject of the GDC 2025 talk.
- **Post-launch.** Stokalski admitted "the factions are the crazy dudes." 11 bit answered with middle-way laws and a no-fervour Serenity mode.

The reasons given for mechanics are stated for Council votes (where values clash), negotiation (it surfaces options), and Tension (Utopias resolve it). No developer rationale for Heatstamps was found.

### Cited Findings
- **Scale vs intimacy, 2024-06-27 (signed "Kuba & Łukasz").** "In the Beta survey, you pointed out that after shifting the game's scale, you lost attachment to individuals. Indeed, Frostpunk 2 plays out on a much larger scale, but we want to give you an opportunity to get close to your citizens as much as possible even in this new frame. That's why we're adding… 'Zoom Stories'." — [Steam, 2024-06-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5842939267309061183)
- **Beta-driven political changes, same post.** The launch was delayed from 2024-07-25 to 2024-09-20 to add, among other things:
  - "Factions' behaviour that is better aligned with their lore"
  - "A more thorough and complex approach to dealing with protests"
  - "More direct-use abilities in the game loop, to allow you to react to crises more dynamically"
  - UI/UX work under the heading "it's the decisions you should be struggling with, not the interface"
  - Source: [Steam, 2024-06-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5842939267309061183)
- **Beta context.** The 2024-04-15–22 beta was a "Utopia Builder Preview," about "40 percent of the full experience" — [Steam, 2024-04-15](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6474562312196299597). The average survey score was 8/10 — [Steam, 2024-05-14](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5768625435413722983).
- **Readability and cognitive load, 2024-05-28.** Stokalski called it a conscious effort to make sure the player is never "doing notes, doing maths on the side just to not die." — [PC Gamer](https://www.pcgamer.com/games/city-builder/in-frostpunk-2s-post-post-apocalypse-its-not-nature-thats-your-enemy-its-human-nature-and-nothing-proves-that-like-my-doomed-attempt-at-turbo-communism/)
- **Systemic variability and Zeitgeist, 2024-09-20.** "It's about making sure whatever is driving the variability in your system is actually built into the system itself, rather than trying to play whack-a-mole." — [Game Developer](https://www.gamedeveloper.com/design/frostpunk-2-s-developers-didn-t-want-it-to-be-a-jackass-simulator-)
- **Power fantasy, same article.** Avoid a "jackass simulator." Choices come from "a certain set of values." — [Game Developer](https://www.gamedeveloper.com/design/frostpunk-2-s-developers-didn-t-want-it-to-be-a-jackass-simulator-)
- **Negotiation as an idea generator, 2024-06-03.** "When you click on these interactions, it will give you three ideas that you actually didn't even think about." — [Screen Rant](https://screenrant.com/frostpunk-2-interview-jakub-stokalski/)
- **Twitch integration as "voice of the people."** It makes "this game an MMO without it being an MMO. Literally, your audience is the voice of the people you have to play with." — [Screen Rant, 2024-06-03](https://screenrant.com/frostpunk-2-interview-jakub-stokalski/). Twitch polling is a real feature: Patch 1.2.0 says "Twitch polling button is now hidden when only one choice is available." — [Steam, 2024-11-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832)
- **Economy as continuous demand, 2024-05-29.** "Most of those are actually supply and demand. It's not all about stockpiling enough firewood to build a tent… the city continuously demands a pool of resources to support the different districts or buildings that you build." — [Game Rant](https://gamerant.com/frostpunk-2-story-interview/)
- **Promises trade commitments for votes.**
  - Patch 1.1.0 blocked contradictory or duplicate promises: no simultaneous pass and repeal quests, no repeat promises on the same law, no promising a policy already on the agenda. It also added consequence arcs for "Repeatedly failing promise quests for a hostile Faction" and "Quelling a protest after negotiating with a Faction and making a promise." — [Steam, 2024-10-21](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562)
  - The 1.3 Hotfix #1: "It is no longer possible to make any Negotiation promise without getting votes as a reward." — [Steam, 2025-05-15](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799817379469768)
- **Difficulty and complexity were the subject of the GDC 2025 talk.** "'Frostpunk 2': Speaking in Systems" covered "practical approaches to managing game complexity and difficulty, illustrating how these elements impact narrative delivery," and "how tuning gameplay to accommodate players' human values can enhance the overall narrative." — [GDC schedule](https://schedule.gdconf.com/session/frostpunk-2-speaking-in-systems/907582). The abstract text comes from the search-result snippet of this official page; a direct fetch returned 403.
- **Post-launch admission about factions, 2025-05-21.**
  - Stokalski: "people like factions and the council system, but obviously, the factions are the crazy dudes, right?"
  - The planned "Spectrum" DLC: "Actually exploring stuff for normal people. If you want to really challenge yourself and this idea of utopia, which inevitably becomes a dystopia for someone else, you could play it and try to keep it 'normal.'"
  - Polish and accessibility "to a larger group of people" mattered more than content.
  - Source: [Game Rant, 2025-05-21](https://gamerant.com/frostpunk-2-dlc-roadmap-future-interview/)
- **Middle-way answer, 2025-12-10.** The free update next to Fractured Utopias "adds thirteen so-called 'moderate laws' for you to try and tread the middle way." — Boiret, [Xbox Wire](https://news.xbox.com/en-us/2025/12/10/frostpunk-2-fractured-utopias/). The Steam notes call them "13 centrist policies." — [Steam, 2025-12-11](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592123014)
- **Tension resolution as an endgame.** Completing a faction's Utopia Tree "solv[es] Tension." — Boiret, [Xbox Wire, 2025-12-10](https://news.xbox.com/en-us/2025/12/10/frostpunk-2-fractured-utopias/). The store page says it binds "your entire society to a single path forward and permanently resolving all the Tension." — [Steam store](https://store.steampowered.com/app/2791510/Frostpunk_2_Fractured_Utopias/)
- **Low-pressure option, 2025-05-08.** Serenity Mode includes "No Fervour system (minimal protests, no faction conflict)." — [Steam, 2025-05-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350). It is for players who want "less pressure… toning down the conflicts inside the city." — [Steam, City Unbound Ep. 9, 2025-05-12](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287959435)
- **Difficulty tuning after launch.** Hotfix 1.0.4 cut Cold growth by 20% on Citizen and 10% on other difficulties, and softened the Prologue so it works as "a small-scale introduction to the challenges of the full complexity of the game." — [Steam, 2024-09-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6339469370185977484)
- **Election mechanic rationale, Breach of Trust, 2026-06-23.** "We also added an election mechanic, giving you a proper entrance onto the political stage and a chance to govern differently than your predecessor." — Mirkowski, [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474)

### Inferences
- The developers' main tension is political pressure as the point of the game versus accessibility. After launch they mostly added ways around the pressure (Serenity's no-fervour mode, centrist laws, readability fixes) rather than weakening the core Council and faction loop in the standard modes.
- Many post-launch fixes punish players who game the system: exploits, promise loops, and promote-then-fund tricks. That fits Stokalski's aim of keeping variability "built into the system."

### Gaps
- **Heatstamps:** no developer statement explaining why this currency exists or how it was designed. It appears only in patch notes, for example as the Beacon of Hope upgrade cost ([Steam, 2025-05-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350)).
- No developer statement on the pacing of Council sessions (recess timing, emergency sessions). Only patch notes exist: Patch 1.2.0 made "Emergency Council Session… available from the Council window when it is in Recess phase" ([Steam, 2024-11-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832)).
- The GDC 2025 talk content itself (recording or slides) was not accessed.

## Q4. How does politics differ between the story campaign and Utopia Builder (and any other modes)?

### Takeaway
Both modes share the political toolkit: Council votes, communities and factions, Trust/Tension, fervour, protests, faction wars and Peace Accords, and Captain's Authority. The differences are these:
- **Story mode** scripts which factions you get, forces you to build the Council early for a vote of no confidence, and runs the narrated Steward story.
- **Utopia Builder (UB)** is an open-ended sandbox ("our frost covered answer to endless mode"). Map, optional Ambitions (goals), difficulty and Tales can be set or randomized. The Council can be skipped entirely. Factions can get "crowded" and "crazy."
- **UB-only options:** Serenity mode, which removes fervour and faction wars, and the paid Fractured Utopias layer, which lets you pick a starting faction and win a faction Utopia that ends Tension.
- **Colonies** have no delegates or votes in either mode.
- **Breach of Trust (2026)** is a new story scenario with its own political rules: a "First Citizen," a periodic Vote of Trust/elections, and diplomacy or conquest with an independent colony.

### Cited Findings
- **Official mode framing.** The story is "a multi-chapter saga… Spanning across the life of the Steward." UB is "the sandbox mode… with infinite play time [that] leaves you room for boundless social and infrastructural experiments." — [Steam store](https://store.steampowered.com/app/1601580/Frostpunk_2/)
- **Hotfix 1.0.4, 2024-09-27.** 11 bit made UB easier to find in the main menu: "For those of you who thought that the Campaign / Story Mode is everything Frostpunk 2 has to offer - we improved visibility of the Utopia Mode which is our frost covered answer to endless mode." — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6339469370185977484)
- **Council requirement differs.**
  - In UB you can choose never to build the Council. In story mode the game "forces you to build it rather quickly so you can hold the vote of no confidence, if you try to hold out, then you'll be met with a game over."
  - A player report: in UB without a Council or faction-aligned research, "radicals just never spawn." Unresolved law questions still drain Trust until "you just lose due to having no trust."
  - Source: [PC Gamer, E. Gould, 2024-09-30](https://www.pcgamer.com/games/city-builder/the-game-gets-weird-frostpunk-2-player-figures-out-that-the-apocalypse-is-easier-without-the-annoying-implications-of-fostering-a-democracy/)
  - Related patch, 2026-02-18: "It is no longer possible to research Criminal Reparation, Guard Immunity, Crime Elimination, Treatment and Housing Distribution policies without a built Council." — [Steam, Patch 1.5.4](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1825093633182133)
- **Faction density.** Stokalski said factions can get "crowded" and "crazy," "particularly outside the game's story mode." — [PC Gamer, 2024-05-28](https://www.pcgamer.com/games/city-builder/in-frostpunk-2s-post-post-apocalypse-its-not-nature-thats-your-enemy-its-human-nature-and-nothing-proves-that-like-my-doomed-attempt-at-turbo-communism/)
- **Story composition example (preview build).** About 10 Stalwarts, about 40 Frostlanders and 50+ New Londoners held the 100 seats. Communities included Frostlanders ("hardcore adapters") and New Londoners ("tech-minded progress types"). The Stalwarts are a faction of the Captain's old hardcore supporters. — [PC Gamer, 2024-05-28](https://www.pcgamer.com/games/city-builder/in-frostpunk-2s-post-post-apocalypse-its-not-nature-thats-your-enemy-its-human-nature-and-nothing-proves-that-like-my-doomed-attempt-at-turbo-communism/)
- **Story factions named officially.** Pilgrims, Faithkeepers, Evolvers and Stalwarts appear in 11 bit's cosplay guides — [Steam, 2025-08-20](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1808601382414775). The Special Edition included a "Faction Patch - either from the Faithkeepers or Stalwarts" — [Steam, 2024-08-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5963414363390615416).
- **Story factions form during play.** Patch 1.1.0 fixed "visible tags on the Council description of independent communities in the main scenario before the second faction forms in the city." — [Steam, 2024-10-21](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562)
- **Choosing starting factions in UB (sources disagree).**
  - Wikipedia says UB lets players "select starting communities, factions, and objectives." — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
  - 11 bit's Fractured Utopias post calls "the ability to force your starting faction" "one of the most requested features," added in Dec 2025. — [Steam, 2025-12-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463)
  - So the base game's UB faction choice was apparently limited or random. The exact pre-DLC options are unconfirmed.
- **UB civil war and Peace Accords.**
  - "Story Arcs and other events are now properly unlocked after finishing a Civil War in Utopia Builder."
  - "Fixed Peace Accords sometimes not being registered as passed in Utopia Builder."
  - "Enclaves are no longer available for construction in colonies under certain conditions in Utopia Builder."
  - Source: [Steam, Patch 1.1.0, 2024-10-21](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562)
- **UB win conditions are optional "Ambitions."**
  - Named Ambitions include "Build a prosperous future" (1.1.0) and "Expansion" (1.1.1).
  - Patch 1.2.0 reworked "Colonise the Frostland" (now 35k population in Colonies and Settlements instead of 3 colonies of 10k each) and "Prosperity" (fuel stockpile 100k→300k, food 100k→200k, goods/materials 100k).
  - Sources: [Steam 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562); [Steam 1.1.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6146943657173899059); [Steam 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832)
- **UB "Tales from the Frostland" (2025-05-08).** These are optional narrative challenges that can be combined: Beacon of Hope, Apocalyptic Whiteout and Depleted Cores. Completing one unlocks a Monument; "failure results in game over!" — [Steam, 2025-05-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350). 11 bit describes Tales as "stories that explore how ideology holds up under extreme pressure." — [Steam, 2025-12-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463)
- **UB-only Serenity mode.**
  - "Relaxed mode with easier start, mild weather, abundant resources, shorter whiteouts and no faction wars," and "No Fervour system (minimal protests, no faction conflict)."
  - A fix was needed for "Serenity mode not using proper fervor setup, so Faction Wars could occur."
  - Source: [Steam, 2025-05-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350)
- **Fractured Utopias (UB-only paid layer, 2025-12-08).**
  - You choose one of 8 existing factions at the start. Each has a Utopia Tree with 12 unlocks (laws, hubs, abilities), traits, a hub, and a housing variant.
  - You advance "by performing actions that earn the favor of your chosen faction." Completing the tree enacts its Utopia and "permanently resolv[es] all the Tension."
  - Sources: [Steam, 2025-10-31](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1815034432904139); [Steam store](https://store.steampowered.com/app/2791510/Frostpunk_2_Fractured_Utopias/)
  - Factions named in official posts and notes: Technocrats, Legionnaires, Venturers, Overseers, Icebloods, Menders, Bohemians. — [Steam, 2025-12-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463); [Hotfix 1.5.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1819386365086607)
  - The 8th faction, "Proteans," appears only in a third-party listing and is **unverified**.
  - "Utopia menus are no longer available for Contained Factions." — [Hotfix 1.5.2, 2025-12-17](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1819386365086607)
- **Political Tales from Fractured Utopias (UB).** In Doomsayers, "A new faction emerges, spreading despair… They will sabotage your city's morale." Plague is the other Tale. — [Steam, 2025-10-31](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1815034432904139)
- **Colonies have no independent politics in either mode.** "there are no independent delegates and votings in the colonies." — [Steam, City Unbound Ep. 8, 2024-09-05](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076596856090)
- **Prologue / tutorial mode.** It is a "small-scale introduction to the challenges of the full complexity of the game" — [Steam, 2024-09-27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6339469370185977484). Patch 1.3 added a midpoint start option — [Steam, 2025-05-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350).
- **Breach of Trust, a story DLC with different political rules (2026-06-23).**
  - You play the "First Citizen" after "the Old Captain [is] deposed." "A periodic Vote of Trust will serve as a tangible check on your approval rating."
  - It adds "5 unique Communities and Factions," "New laws," and an "Independent Colony - navigate relations with the independent colony through peaceful trade, forceful extortion, or total conquest." — [Steam store: Breach of Trust](https://store.steampowered.com/app/4124750/)
  - Mirkowski: trade negotiations "where the stronger side can impose its conditions." A "completely branching middle act" where the cities either coexist or the stronger side wins and chooses "between retaliation or learning to live together." An "election mechanic." — [Steam, 2026-06-23](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474)
  - Hotfix 1.6.1 "Balanced election voting weights" and fixed a bug on the Conquer Aurora path where players "could incorrectly lose the game despite winning the vote of trust." — [Steam, 2026-07-02](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1836506165567957)
  - The official FAQ says Aurora's "Resistance only becomes active after you begin sending food from Aurora to New Edinburgh." — [Steam, 2026-07-10](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1837955055356766)
- **Breach of Trust's free UB spillover.** "Volcano Night in a simplified version for Utopia Builder," an "Aurora map" (the patch notes list a new UB map "Twilight waters" and a challenge "Volcanic night"), and a Fishing Hub. — [Steam, 2026-06-23](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474)

### Inferences
- After launch, UB became the home of faction politics as a playable fantasy (Fractured Utopias). Story content explores new legitimacy mechanics (Breach of Trust's elections, colony diplomacy and conquest).
- Being able to skip the Council in UB, together with the 2026 change requiring a Council for some policy research, suggests 11 bit is quietly limiting the "no-democracy" UB strategy without banning it. This is an inference; the patch notes give no reason.
- Breach of Trust's periodic Vote of Trust turns legitimacy into a recurring scheduled test, which differs from the base game's continuous Trust meter.

### Gaps
- Exact base-game (pre-Dec 2025) UB setup options for communities and factions could not be confirmed. The game-vault wiki ([link](https://frostpunk-2.game-vault.net/wiki/Communities_and_Factions)) returned 403. A search snippet from it said story mode starts with two communities (Frostlanders/Adaptation and New Londoners/Progress, about 45% each) plus one faction (about 10%), while UB starts with three communities. This is **unverified**.
- It is unknown whether the delegate count or voting thresholds differ by mode.
- The 8th Fractured Utopias faction name is unverified.
- Which of the new maps "Forsaken Valley" and "Jagged Bay" ([Hotfix 1.5.3](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1819386365095000)) is the free one and which is the paid one is not stated.
- Fractured Utopias' console release date is not confirmed. Xbox Wire covered it on 2025-12-10 ([link](https://news.xbox.com/en-us/2025/12/10/frostpunk-2-fractured-utopias/)), and Steam announced the PC release on 2025-12-08.
- A third-party guide ([frostpunk2.wiki](https://frostpunk2.wiki/guides/utopia-builder/)) contradicts official notes. For example, it says Serenity "eliminat[es] whiteouts entirely," while official notes say "shorter whiteouts." It should not be used.

## Q5. Post-launch changelog: patches, updates, console releases and DLC that affected political systems (to Oct 2026)

### Takeaway
Most post-launch rebalancing of the base political system happened in the first three months, from launch to Patch 1.2.0 (Sept–Nov 2024):
- Trust and fervour tuning
- New "consequence arcs" and faction events that punish players who game the system
- Rules on promises and negotiations
- Fixes to protests, counterprotests and Peace Accords

Later releases changed politics by adding things rather than retuning:
- 1.3 (May 2025) tied faction negotiations, protests and deaths to district heating, and added Serenity's no-fervour mode.
- 1.4 / consoles (Sept 2025) brought the Council and negotiation UI to controllers.
- Fractured Utopias / 1.5 (Dec 2025) added UB faction Utopias and 13 centrist laws.
- Breach of Trust / 1.6 (June 2026) added a story with elections and a Vote of Trust, plus independent-colony diplomacy and conquest.

The third DLC, codename "Surge," is announced for 2026 but was not released as of the last Steam post (2026-09-22).

### Cited Findings

#### Pre-launch milestones that shaped the political systems
- **2021-08-13**: Announcement trailer — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/4516534149059143884)
- **2024-03-06**: Release date set for 2024-07-25. The Deluxe Edition includes "Three paid post-release DLCs" and 72-hour early story access — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5679673637649312122)
- **2024-04-15 to 04-22**: Beta ("Utopia Builder Preview," about 40% of the game) — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6474562312196299597)
- **2024-06-27**: Delay to 2024-09-20 to fold in beta feedback: "Factions' behaviour that is better aligned with their lore," "A more thorough and complex approach to dealing with protests," more direct-use abilities, UI/HUD clarity, Zoom Stories — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5842939267309061183)
- **2024-09-17**: Advanced Access for Deluxe owners — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6250522009531949947)
- **2024-09-20**: PC launch (Windows/macOS, also PC Game Pass) — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506883148); [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)

#### 2024
- **2024-09-20, launch-day "City Maintenance Report" patch** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517)
  - "Slightly reduced initial Trust across all difficulty levels"
  - "First Faction War spread will now occur after 10 weeks, down from 15"
  - "'Enforce Peace' ability now requires a Prison and no longer removes Faction Fervor"
  - "'Protect People' ability Guards cost changed from 16 to 24"
  - Fixed the Captain's Authority trust bar after "Stage Coup"
  - Fixed Grant Agenda notifications showing the wrong law
  - Fixed a Chapter 5 softlock if the Steward "resorted to radical solutions"
- **2024-09-26, Hotfix 1.0.3**: "Tweaked Peace Accords requirements to remove a possible softblock" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6339469370181879828)
- **2024-09-27, Hotfix 1.0.4**: Cold growth −20% on Citizen and −10% on other difficulties; Prologue softened; UB made more visible in the menu — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6339469370185977484)
- **2024-10-04, Hotfix 1.0.5**: "Districts will no longer remain blocked after the Protest has been resolved through increased relations with a protesting Faction" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6350729003497791230)
- **2024-10-21, Patch 1.1.0 ("Quality of Life Improvements")**, the largest early political patch — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562)
  - "Community Actions will be offered more often in Council negotiations"
  - "Negotiations and Grant Agenda proposals will now be prioritising city needs next faction/community affinity" (sic)
  - New **Consequence Arcs** triggered by:
    - keeping the generator off too long while fuel is available
    - "Promoting a Faction only to Raise Funds afterwards"
    - "Repeatedly failing promise quests for a hostile Faction"
    - "Condemning and promoting the same faction in quick succession"
    - "Failing too many votes after granting an agenda to the same Faction"
    - "Quelling a protest after negotiating with a Faction and making a promise"
  - Promise rules: no simultaneous quests to pass a policy and repeal its opposite; no multiple promises on the same law; no promising a policy already on the next session's agenda; no fuel promises the generator cannot use
  - "Enacting a Cornerstone now adds 2 fervour to the faction that is aligned with the opposed affinity"
  - "Fixed infinite Trust exploit"; fixed a never-expiring negative Trust modifier from "Rush Research"
  - "Factions now provide proper bonuses to the city if the Steward maintains good relations"
  - "Factions will no longer drop their relations from Devoted to Hostile if certain conditions are met"
  - Detainees "will return to the society after serving out their sentence" and can no longer voice opinions
  - Protest fixes: requested protests drop if the requesting faction is gone; protests can't be negotiated while already collapsing from Quell or Counterprotest
  - Faction War softblock fixed; Peace Accords fixes, including in UB
  - "Improved critical faction fervour readability"; "Delegates facts will now be less repetitive"
  - "The player will no longer be called Steward after becoming a Captain"
- **2024-10-31, Hotfix 1.1.1** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6146943657173899059)
  - "Fixed infinite affinity loop exploit"
  - "Moved the faction formation button to a more visible spot"
  - Fixed duplicated delegates in Council seats on faction formation
  - Steam Workshop and mod.io mod support went live
- **2024-11-13, Hotfix 1.1.2**: "Fixed incorrect number of delegates on the gameplay startup" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1783238125182770)
- **2024-11-26, Roadmap**: 2025 plans for a console launch, codenamed DLCs and Free Major Content Updates — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1783872412145784)
- **2024-11-27, Patch 1.2.0** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832)
  - "Improved factions' reactivity to current city status": "Six new events furthering faction conflict when conditions are catastrophic"
  - Two new events reacting to "frequent use of Fund Projects and Promote on Communities not aligned with your Zeitgeist"
  - A new event "when helping pass Law proposed by Community not aligned with your Zeitgeist"
  - New consequences for "Increase Workload on Servants"
  - "Detainees can now be converted to Servants"
  - Counterprotest infinite-protest bug fixed
  - "Trust Fail game over screen will now pop with a delay rather than right after voting"
  - Factions no longer demand consequences for demolishing promised coal buildings after deposits run out
  - "Emergency Council Session is now available from the Council window when it is in Recess phase"
  - UB Ambitions rework and UB map changes
- **2024-11-29, Hotfix 1.2.1**: Emergency Council Session crash fix; "Fixed negotiations not showing the proper outcome" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506359051615)
- **2024-12-12, Hotfix 1.2.2**: "Currently in Force widget is now hidden when voting for Charter Policies"; Emergency Council button fix; Council audio tweaks — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1785774543526761)

#### 2025
- **2025-01-28, Hotfix 1.2.3**: "Guided Voting is no longer a permanent modifier"; "While Captains Authority is active, Guided Voting will no longer apply"; new art for consequence arcs and cornerstones — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1789580505470820)
- **2025-02-27, Roadmap update**: free update on May 8, console port in summer, "Spectrum DLC" in autumn ("may help us learn more about ourselves and the people of our great city") — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1792751526010766)
- **2025-05-02 to 05-05**: 1.3.0 pre-release beta branch; fallback branch "release-1.2.3" kept for mods — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1797820624623396)
- **2025-05-08, Patch 1.3.0 (Free Major Content Update)** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350)
  - Heating reworked to work district by district. Citizens "now react to heating shortages through negotiations, protests, or praise. Deaths are now tied to specific factions and communities."
  - "Every Community and Faction can now occupy an individual district"
  - "1 new law, 5 reworked laws"; laws that used to affect heat demand now relate to Heat Levels
  - "Improved visibility of Hostile relations with Factions and Communities"
  - UB additions: Serenity mode (no Fervour, no faction wars), Tales from the Frostland, and The Pit map
  - Expanded faction/community frontmen art in story mode
  - Frostkit 1.0 modding tools
  - Dev explainer video: [City Unbound Ep. 9, 2025-05-12](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287959435)
- **2025-05-15, 1.3 Hotfix #1** (a "release - 1.3.1" branch is mentioned later): "It is no longer possible to make any Negotiation promise without getting votes as a reward"; faction portrait fix in negotiations; protest tooltip fix — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799817379469768)
- **2025-05-20, Roadmap #2**: each DLC will be preceded by a free major update; DLC 2 "Aurora" moved to 2026 — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799817379627454)
- **2025-05-21, Stokalski interview**: feedback that "the factions are the crazy dudes"; Spectrum is about "normal people" — [Game Rant](https://gamerant.com/frostpunk-2-dlc-roadmap-future-interview/)
- **2025-07-27**: Console release date announced for 2025-09-18 on "PlayStation, Xbox and Xbox Game Pass," with PC controller support the same day — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1806064758720209)
- **2025-08-20, Roadmap #3**: Spectrum later in 2025 alongside a free update; in 2026, "Aurora and 'DLC 3'" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1808601382414775)
- **2025-09-18, console launch (PS5 / Xbox Series X|S) and PC Patch 1.4**
  - Full controller UI, including radial menus, used across Council and negotiation screens
  - Mostly homeless, heat and Prologue balance; no direct Council changes listed
  - Sources: [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811138915391855); console platforms per [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- **2025-10-03, Hotfix 1.4.1**: "Fixed Peace Accords law sometimes not showing up in the Council when playing with a controller"; Trust tutorial prompts; no tooltip on unavailable laws — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811772772511895)
- **2025-10-29, Hotfix 1.4.2**: fervour tutorial trigger fix; "rare case of Council opening without UI"; "promised law highlight VFX" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1814942955104500)
- **2025-10-31**: Fractured Utopias revealed for Dec 8. Closed playtests ran to Nov 3. It answers "feedback about faction playability and the desire for more distinctive experiences" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1815034432904139)
- **2025-12-08, Fractured Utopias DLC (first DLC; likely the "Spectrum" codename, see Inferences) plus free update, Patch 1.5.0** (notes posted 2025-12-11)
  - DLC: 8 faction Utopias with trees, hubs and housing variants, 100+ events, the Doomsayers and Plague Tales, and a map
  - Free: "New 13 centrist policies," a Doomsayers-themed map, a new UI, and "Changes to Appearance of Factions Panels"
  - Sources: [Steam, 2025-12-08](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463); [Steam, 1.5.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592123014)
- **2025-12-12, Hotfix 1.5.1**: "Fixed Council view becoming empty when attempting to vote on Rule laws after the Grand Agenda community action has been used"; crash after removing a faction/community — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592128148)
- **2025-12-17, Hotfix 1.5.2** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1819386365086607)
  - "Enact Utopia" requirement tooltips
  - Utopia menus disabled for Contained Factions
  - "Fixed possibility of Faction War being spawned when any Plague Event is currently active"
  - "Fixed possibility of Faction not being fully dissolved after Faction War"
  - Centrist Laws display fix for older saves
  - Detainees lose the "Promise" action during the Plague Tale
  - "Heat Homes" community action removed for Icebloods
- **2025-12-19, Hotfix 1.5.3**: crash fix for saves on the new Forsaken Valley and Jagged Bay maps — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1819386365095000)

#### 2026 (through 2026-10-05)
- **2026-01-14, year summary**: "The remaining 2 [DLCs] will launch this year!" — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1821922921811357)
- **2026-02-18, Patch 1.5.4** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1825093633182133)
  - Five policies (Criminal Reparation, Guard Immunity, Crime Elimination, Treatment, Housing Distribution) can no longer be researched without a built Council
  - Fixed duplicated Bohemian negotiation options
  - "Doomsayers' Council animation pool was limited to better match their identity"
  - Vaccine Trust modifier now shown in the Trust tooltip
  - Council UI fixes (delegate inspection prompts, chat bubbles after voting, negotiation camera on controller)
- **2026-02-20 to ~04-06, "Great Faction Wars Contest"**: a 7-week community bracket scored from Fractured Utopias telemetry (skill-tree milestones and enacted Utopias). **This was a marketing event, not a gameplay change.** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1825093633187926)
- **2026-04-06, Frostpunk Franchise Fest Showcase**
  - Breach of Trust announced for June 23: New Edinburgh scenario, "First Citizen," "periodic Vote of Trust," 5 communities/factions, Independent Colony, new laws
  - Roadmap gives the third DLC the codename **"Surge"**
  - Sources: [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1828894815565669); [Steam showcase recap](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1828894815565683)
- **2026-04-28 to 05-03**: Breach of Trust playtests — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1830797770245280)
- **2026-06-23, Breach of Trust DLC on "PC and consoles" plus a free update** — [Steam, 2026-06-15](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835236783570402); [Steam, 2026-06-23](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474)
  - Version is presumably 1.6.0, inferred from the next hotfix being 1.6.1
  - DLC: "New laws and political choices… decide how much trust your people are willing to place in you"; an election mechanic; branching coexistence or conquest with Aurora
  - Free update: UB Volcanic Night challenge, Twilight Waters/"Aurora" map, Fishing Hub
  - Balance: weaker "Rush Researches" and Technocrats' "Optimize Research"; lower shelter demand; Frostland outpost rebalance
  - UI: "Radical buildings are now marked in the construction panel"
- **2026-07-02, Hotfix 1.6.1**: "Balanced election voting weights and streamlined multiple occupation story arcs"; Aurora communities/factions now included in research; Aurora counter-offer demand fix; fixed a wrongful game over after winning the vote of trust on the Conquer path; trust-bar controller focus — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1836506165567957)
- **2026-07-10, Breach of Trust FAQ**: strategy for the negotiate-with-Aurora vs conquest paths, and how the Resistance works — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1837955055356766)
- **Status as of the latest Steam announcement (2026-09-22, a LARP promotion)**: no patch after 1.6.1 and no Surge release date in the official feed — [Steam, 2026-09-22](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1844115010504268); [feed](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1601580&count=500&maxlength=0&format=json)
- **Modding context.** FrostKit shipped at launch, Steam Workshop arrived 2024-10-31, Frostkit 1.0 arrived 2025-05-08, and a 2025 modding contest drew "New buildings, new laws, and even multiplayer concepts" — [Steam, 2026-01-14](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1821922921811357)

### Inferences
- **Codename mapping is inferred, not stated.**
  - "Spectrum" = Fractured Utopias. The Aug 2025 roadmap called Spectrum the "first DLC" for later in 2025, and 11 bit called Fractured Utopias "our very first Frostpunk 2 DLC."
  - "Aurora" = Breach of Trust. Its colony is named Aurora and it shipped in 2026 as DLC 2.
  - "Surge" = DLC 3.
- **Spectrum's pitch versus what shipped.** Stokalski pitched Spectrum around "normal people" (May 2025). What shipped split that idea: the free 13 centrist/"moderate" laws carry the "normal" theme, while the paid DLC went the other way, toward maximal faction Utopias. Treat this as interpretation.
- **Patch notes rarely give reasons.** The usual stated reason is "your feedback." The specific reasons in the 1.1.0–1.2.0 political changes are visible only in how they work: anti-exploit arcs, protecting promise integrity, and making factions react to how well the city is doing.

### Gaps
- Surge's content and date are not officially known. Third-party sites speculate about lightning or electrical themes, which is **unverified speculation**.
- Fractured Utopias' console launch date is not confirmed.
- The console-specific patch numbering is unknown (PS/Xbox versions may differ).
- Statistics from "Your Choices in Numbers" (data from more than one million playthroughs, e.g., political choice splits; [Steam, 2025-09-26](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811772772278270)) are published only as images. They were not captured.

## Q6. Developer talks at conferences, dev-diary series, or postmortems about Frostpunk 2's politics

### Takeaway
- **Conference talk:** one confirmed. Jakub Stokalski's GDC 2025 session "'Frostpunk 2': Speaking in Systems" (2025-03-19) covered how complexity, difficulty and "human values" tuning carry the game's narrative.
- **Dev commentary:** most of the official developer commentary is in 11 bit's "City Unbound" video series (2024–2025) and Steam posts.
- **Not found:** a Digital Dragons talk on Frostpunk 2's politics, or a formal written postmortem.

### Cited Findings
- **GDC 2025: "'Frostpunk 2': Speaking in Systems"** — [GDC schedule session](https://schedule.gdconf.com/session/frostpunk-2-speaking-in-systems/907582); [speaker page](https://schedule.gdconf.com/speaker/stokalski-jakub/56147). Details come from search snippets of the official page; direct fetch returned 403.
  - Speaker: Jakub Stokalski.
  - When and where: Wednesday, March 19 (2025), 5:00–6:00 pm, Room 2005, West Hall, Moscone Center.
  - Abstract: how FP2 "balances gameplay and narrative." It covers "practical approaches to managing game complexity and difficulty, illustrating how these elements impact narrative delivery," and "how tuning gameplay to accommodate players' human values can enhance the overall narrative." It uses "concrete examples and design challenges encountered during the development of Frostpunk 2."
- **"City Unbound" official dev-video series.** Hosted by Stokalski and Juszczyk. Ep. 1 aired 2024-07-11 as part of IGF Celebration Days.
  - Ep. 3 "Negotiating the future" (2024-07-25)
  - Ep. 4 on Council and law-making (2024-08-05)
  - Ep. 5 on beta-driven changes (2024-08-08)
  - Ep. 6 "Human Dimension" (2024-08-22)
  - Ep. 8 "Cities and Colonies" (2024-09-05)
  - Ep. 9 on the 1.3 update (2025-05-12)
  - Special episodes for 1.4 / consoles (2025-09) and the Fractured Utopias reveal (2025-12, with commentary from Juszczyk)
  - Sources: [Ep.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5842939267361309703); [Ep.3](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5963413094348379957); [Ep.4](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5963413728349215085); [Ep.6](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5875595438688369903); [Ep.8](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076596856090); [Ep.9](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287959435); [anniversary post](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811138915464344); [FU post](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463)
- **Other studio showcases and conferences.**
  - 11 bit Investor Conference, June 2023 (video only) — [Steam, 2023-06-19](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5896948309853754881)
  - "11 bit studios Digital Showcase," where the Fractured Utopias launch trailer premiered, Dec 2025 — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463)
  - "Frostpunk Franchise Fest Showcase," 2026-04-06 — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1828894815565683)
  - These are marketing showcases, not design talks.
- **Written design commentary closest to a postmortem.**
  - Mirkowski's essay "Chasing the Fire: Bringing a Volcano to Frostpunk 2" (2026-06-23) explains Breach of Trust's political design: two-city conflict, trade-negotiation power imbalance, a branching middle act, and elections — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474)
  - Boiret's Xbox Wire piece on Fractured Utopias (2025-12-10) — [Xbox Wire](https://news.xbox.com/en-us/2025/12/10/frostpunk-2-fractured-utopias/)
- **Reddit r/Games AMA, 2024-09-12, 2 PM CEST, with Stokalski and Juszczyk** — [Steam](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076614907521). Content not captured.

### Inferences
- The GDC title "Speaking in Systems" and its abstract match the interview themes: Zeitgeist "built into the system," values over evil, and tuning difficulty and complexity. Politics is probably a central case study, but this is **unconfirmed** without the recording.

### Gaps
- No GDC Vault recording, slides or press write-up of "Speaking in Systems" was found or accessed.
- No Digital Dragons (Kraków) talk on Frostpunk 2 was found. This could be a search miss rather than proof that none exists.
- No formal written postmortem was found, for example on Game Developer, covering Frostpunk 2's political systems.
- The City Unbound videos (Ep. 3–6 in particular) likely contain the most detailed official explanations of the Council, but no transcripts were found.
