# Frostpunk 2: Council, Voting, Negotiation, Trust/Tension and Steward Removal (Launch Sept 2024 to Oct 2026)

Source-access note, which applies to every section below. The most detailed rules wiki for FP2, frostpunk-2.game-vault.net (the Fandom FP2 page links to it as "Frostpunk 2 Wiki"), returned HTTP 403 (Cloudflare) to both WebFetch and curl. Wayback Machine copies of it exist (Feb–Apr 2026 snapshots), but web.archive.org is blocked by this session's egress policy, so I could not read them. Claims that reached me only as search-engine snippets attributed to game-vault are marked **[snippet-only]** and should be treated as unverified. The Fandom FP2 pages were read through the MediaWiki API, but they are mostly stubs. Official 11 bit Steam announcements and patch notes for app 1601580 were read in full through the Steam News API and are the primary source for version-specific changes.

Version map (official). Advanced Access opened 17 Sep 2024 and full release was 20 Sep 2024 ([Fandom FP2](https://frostpunk.fandom.com/wiki/Frostpunk_2)). Then: launch-day "City Maintenance Report" 20/09/2024. Hotfixes 1.0.2–1.0.5 (Sep–Oct 2024). Patch 1.1.0 (21 Oct 2024). Hotfixes 1.1.1–1.1.2. Patch 1.2.0 (27 Nov 2024). Hotfixes 1.2.1–1.2.3 (to 28 Jan 2025). "Free Major Content Update" = Patch 1.3 (8 May 2025). Patch 1.4 (18 Sep 2025, controller support). Patch 1.5.0 (11 Dec 2025, alongside the *Fractured Utopias* DLC of 8 Dec 2025). Patch 1.5.4 (18 Feb 2026). *Breach of Trust* DLC (23 Jun 2026; its launch patch is presumably 1.6.0, since the next hotfix is labelled 1.6.1). Hotfix 1.6.1 (2 Jul 2026). URLs for each patch are cited where they are used below.

## 1. Council seats: how many, how allocated, recalculation, neutral/undecided bloc

### Takeaway
The Council has a fixed 100 delegates (Steward/First Citizen excluded). Seats go to every community and faction in proportion to its share of the city's population, so the seat map changes whenever group membership changes (Promote, Condemn, Deradicalize, rallies, arrests, deaths, new factions forming). There is no separate neutral party. Instead, each bloc's delegates show as For, Against, or Undecided ("hesitant"), and the undecided ones settle at the moment of the vote. Single-cornerstone *communities* act as the negotiable swing groups; three-cornerstone *factions* act as hardliners.

### Cited Findings
- The Council comprises 100 delegates drawn from the factions and communities, and "the distribution of votes is based on the faction's current popularity rating" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/); "all 100 delegates have a vote" — [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council).
- "A population's votes in the Council are proportional to their percentage of the population." Every citizen belongs to exactly one community or faction, and hovering a group's icon shows its population percentage — [TheGamer, complete faction guide](https://www.thegamer.com/frostpunk-2-complete-faction-guide/).
- "Communities and Factions are granted seats in the council based on percentage of the population each Faction or Community represents" — [Steam guide: All factions and communities](https://steamcommunity.com/sharedfiles/filedetails/?id=3379903271). Each group "by default has a certain number of delegates on the city council, depending on their population" — [Gamepressure, Factions](https://www.gamepressure.com/frostpunk-2/factions/zc113e2).
- **[snippet-only]** game-vault Council page: "The Council is made up of 100 Delegates, with each Faction and Community having a number of Delegates equal to the percentage of the total Population who are members of that Faction or Community" — [game-vault Council (not directly readable)](https://frostpunk-2.game-vault.net/wiki/Council).
- Fandom describes it more vaguely: "Each Faction will have different numbers of delegates depending on their popularity in the city" — [TheGamer, Council guide](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/). The Fandom Council page only says delegates vote and a two-thirds majority is "67 delegates" — [Fandom: The Council](https://frostpunk.fandom.com/wiki/The_Council).
- Recalculation levers:
  - **Promote**: "Faction will gain new members and secure seats in the Council" — [Game8 tips](https://game8.co/games/Frostpunk-2/archives/473193). Promote "causes them to immediately gain new members… even more power (both in the Council and in the streets)" — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
  - **Condemn**: Council-category actions "give a faction more seats on the city council, or… condemn them, reducing the number of seats they have" — [Gamepressure, Factions](https://www.gamepressure.com/frostpunk-2/factions/zc113e2).
  - **Deradicalize** (community action): moves faction members back to the community — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/); [Game8 factions](https://game8.co/games/Frostpunk-2/archives/473462).
  - **Rallies**: long rallies "can start to skew the proportion of individuals in each group" — [TheGamer, Rallies & Riots](https://www.thegamer.com/frostpunk-2-rallies-riots-guide/).
  - **Round Up Faction Members** (prison ability): arrests up to 500 members of a faction over a few weeks — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
  - **Secret Police "Revoke Council Seats"** (authoritarian/Rule path): strips a faction's seats before a vote — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
  - Since Patch 1.3 (8 May 2025), "Deaths are now tied to specific factions and communities" — [Steam: Free Major Content Update](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350).
- Undecided bloc:
  - Delegates have three options: "For, Neutral, and Against" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/).
  - "Hesitant voters will decide on where to vote during the actual vote" — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453).
  - Delegates "may either be in favor of or against the law, or undecided and hesitant" — [GameRant, laws](https://gamerant.com/frostpunk-2-how-propose-negotiate-approve-laws/).
  - The Council UI shows each bloc's delegate count and how it is voting, plus a label such as "mostly hesitant and open to negotiation" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/); [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/).
- Communities vs factions:
  - Communities are aligned to one Cornerstone, "tend not to be hardliners, and can usually be negotiated with". Factions are aligned to three Cornerstones and "will refuse to vote against their beliefs" — [TheGamer, faction guide](https://www.thegamer.com/frostpunk-2-complete-faction-guide/).
  - PC Gamer: factions "won't vote against their worldview, and you won't be able to negotiate with them if they're opposed to the direction of the law" — [PC Gamer, factions (updated 24 Sep 2024)](https://www.pcgamer.com/games/city-builder/frostpunk-2-factions/).
  - Communities are "much larger than factions, so it is easier to negotiate with them and more difficult to radicalize them" — [Gamepressure, Factions](https://www.gamepressure.com/frostpunk-2/factions/zc113e2).
  - Patch notes call some groups "independent communities" in the Council — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
- Colonies: "there are no independent delegates and votings in the colonies"; New London retains control — [Steam: City Unbound Ep. 8 (dev diary, 5 Sep 2024)](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076596856090).
- Patch history affecting seats:
  - Hotfix 1.1.1 "Fixed delegates duplicating… in the Council seats upon forming a new faction" — [Steam: Hotfix 1.1.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6146943657173899059).
  - Hotfix 1.1.2 "Fixed incorrect number of delegates on the gameplay startup on some occasions" — [Steam: Hotfix 1.1.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1783238125182770).
- Starting composition: the story mode starts with two communities and one faction (set by a prologue choice) — [TheGamer, faction guide](https://www.thegamer.com/frostpunk-2-complete-faction-guide/). In Utopia Builder you pick two starting communities — [PC Gamer](https://www.pcgamer.com/games/city-builder/frostpunk-2-factions/). Since *Fractured Utopias* (Dec 2025) you can also force a starting faction — [Steam: Fractured Utopias available](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463).

### Inferences
- Seats appear to be population share rounded to 100. Seat counts are therefore an output of city management (housing, deaths, faction formation, Promote/Condemn), not a separate political stat. "Promote" is effectively a seat-buying action that also lowers that faction's Fervour by one.
- The swing vote is structural. Communities, which are single-axis and negotiable, are where the Steward finds votes. Factions only vote with you when the law matches their axes, or when relations are high enough that their undecided share breaks your way.
- How the game rounds seat shares, and whether seats update continuously or only when a session opens, is not documented anywhere I could read.

### Gaps
- No readable source gives the rounding rule or update timing for seats, or says whether colony populations count toward Council percentages (the dev diary only says colonies have no delegates or votes of their own).
- How undecided delegates resolve at vote time (random draw, a relations-weighted probability, or a fixed split) is undocumented. One player heuristic counts "roughly half of hesitant delegates" — [2UpSkill (low reliability, generic content)](https://2upskill.com/frostpunk-2-breach-of-trust-vote-of-trust-mechanic-explained-complete-strategy-guide/).
- The game-vault Council page, the likely authoritative wording, could not be read (Cloudflare 403; Wayback blocked by egress policy).

## 2. Thresholds to pass; what happens when a vote fails

### Takeaway
Ordinary laws need a simple majority of the 100 delegates (51 votes). Rule-category laws, the ones that centralise the Steward's power, need two-thirds (67). Every vote, passed or failed, is followed by a 10-week Council recess. A failed bill cannot be re-run until the next session. Beyond losing the session, failure carries indirect costs: broken promises if you had promised that law, and, since Patch 1.1.0, consequence events for repeatedly failing granted agendas. I found no documented direct Trust penalty for simply losing a vote.

### Cited Findings
- "At least 51 votes will be required"; Rule-category laws need "2/3 of all delegates" — [Gamepressure, Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb). The 51-vote majority is also stated by [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council), [Dexerto](https://www.dexerto.com/gaming/frostpunk-2-council-best-laws-to-pass-first-2908202/), [GameRant](https://gamerant.com/frostpunk-2-how-propose-negotiate-approve-laws/) and the [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453).
- "In some special cases (such as laws from the Rule category), a Two-Thirds Majority (67 delegates) is required" — [Fandom: The Council](https://frostpunk.fandom.com/wiki/The_Council). **[snippet-only]** game-vault describes Rule laws as those that "increase the personal power of the Steward" and require "a supermajority of 67 votes" — [game-vault Council](https://frostpunk-2.game-vault.net/wiki/Council). GameRant: "The Rules category in the council allows you to centralize power… recruit guard scouts, establish a Bureau of Propaganda, and eventually declare yourself a dictator" — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/).
- After a vote: "Each vote is followed by a 10-week break in the proceedings", and a failed bill: "you won't be able to revive it until the next session" — [Gamepressure, Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb). Dexerto: "After each vote, the Council enters a 10-week recess, during which you cannot propose any new laws" — [Dexerto](https://www.dexerto.com/gaming/frostpunk-2-council-best-laws-to-pass-first-2908202/).
- Official patch confirmations of the recess phase: Patch 1.1.0 "Added audio notification for when HoD recess finishes" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562). Patch 1.2.0 refers to the Council "in Recess phase" — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
- Consequence arcs added in Patch 1.1.0 (21 Oct 2024) fire on "Failing too many votes after granting an agenda to the same Faction" and "Repeatedly failing promise quests for a hostile Faction" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
- Vote results can trigger the end-of-game Trust check. Patch 1.2.0: "Trust Fail game over screen will now pop with a delay rather than right after voting" — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
- Conflicting claim: GameRant says "Once you've passed a law in the council, you'll need to wait two in-game weeks before passing, amending, or repealing a law again" — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/). Every other source says 10 weeks ([TheGamer](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/), [Gamepressure](https://www.gamepressure.com/frostpunk-2/council/zf115fb), [Dexerto](https://www.dexerto.com/gaming/frostpunk-2-council-best-laws-to-pass-first-2908202/), [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council), [Escapist](https://www.escapistmagazine.com/how-to-approve-laws-in-frostpunk-2/)).
- Unanimity is possible. The official achievement "No-brainer: Have 100% of delegates vote in favour of any law" — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements). A guide advises relations "above Supporting", Negotiate, and Guided Voting to get there — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).

### Inferences
- The "two weeks" figure in the GameRant Captain's Rule article is most likely an error, given five independent sources and the official "Recess phase" wording. The 10-week recess is the operative rule.
- Since recess follows every vote, a failed vote mainly costs time (10 weeks), plus any promise or agenda fallout. The 67-vote bar for Rule laws is where Guided Voting and seat-manipulation tools matter most.

### Gaps
- No source specifies a direct Trust or relations hit from losing a vote that you proposed. Whether a failed law gets a per-law lockout beyond "until the next session" is also undocumented.
- Whether the recess length is ever modified by laws or difficulty is undocumented.

## 3. Who proposes; how sessions are scheduled or called; limits on vote frequency

### Takeaway
Normally the Steward proposes one law per session, chosen from laws unlocked by research. Factions and communities get agenda-setting power only when the Steward uses "Grant Agenda" (a community action, and sometimes a negotiation term), which lets that group choose the next law put to vote. Sessions run on a 10-week recess cycle. During recess the "Emergency Council Session" ability can convene the Council immediately, at a relations/Trust cost and with its own cooldown. Since Patch 1.2.0 that ability is reachable from the Council window during recess.

### Cited Findings
- "You have the option to submit one law for each Council session, between which the Council takes recess for ten weeks" — [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council). "You can propose laws about every 10 weeks, between that council will be in recess and unavailable" — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453).
- On timing, TheGamer: "Once you select a law, you can change your proposal or choose to hold a vote immediately. If you don't, voting will happen automatically every ten weeks. Once a law is enacted, the Council goes into recess for ten weeks" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/). Gamepressure: proposals automatically go to vote "in 10 weeks" if not called sooner — [Gamepressure](https://www.gamepressure.com/frostpunk-2/council/zf115fb).
- Uncorroborated claim: "even if you don't propose any new law, a new bill will be presented in the Council every 10 weeks and there will be a vote, whether you like it or not" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/). No other source states this.
- Grant Agenda:
  - "Let them choose the next Law to propose; Relations significantly improve" — [Game8 tips](https://game8.co/games/Frostpunk-2/archives/473193).
  - The granted law still has to pass a vote, and you can negotiate other blocs to defeat it. Trust rises immediately on granting — [Screen Rant](https://screenrant.com/frostpunk-2-how-to-increase-trust/); [Selphie1999](https://selphie1999gaming.com/game-guides/frostpunk-2/frostpunk-2-trust-how-to-become-a-popular-steward/); [Sportskeeda, Trust](https://www.sportskeeda.com/esports/increase-trust-frostpunk-2-promises-agenda-funding-abilities-laws).
  - The faction icon shows "Agenda Granted" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/).
  - "If you grant a Faction the opportunity to propose the next law on the agenda, the law you vote on may already be set for you" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/).
- Grant Agenda patch history:
  - Launch-day notes fixed a notification that "could display a different law than the one offered by Grant Agenda community action" — [Steam: City Maintenance Report 20/09/2024](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517).
  - 1.1.0: "Negotiations and Grant Agenda proposals will now be prioritising city needs next [to] faction/community affinity" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
  - 1.2.0: "New event when helping pass Law proposed by Community not aligned with your Zeitgeist" — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
  - 1.5.1 fixed an empty Council view "when attempting to vote on Rule laws after the Grand [sic] Agenda community action has been used" — [Steam: Hotfix 1.5.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592128148).
- Emergency Council Session:
  - **[snippet-only]** game-vault: the "Emergency Council Session" District Ability "will immediately bring the Council together for a vote while the council is in recess, at the cost of decreasing Trust with all Communities and Factions; the ability resets the recess timer, and itself has a 12-week cooldown" — [game-vault Council](https://frostpunk-2.game-vault.net/wiki/Council).
  - Official: Patch 1.2.0 (27 Nov 2024): "Emergency Council Session is now available from the Council window when it is in Recess phase" — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832). Hotfixes 1.2.1/1.2.2 fixed crashes and missing-button bugs on it — [Steam: Hotfix 1.2.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506359051615); [Steam: Hotfix 1.2.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1785774543526761).
  - "The 10-week cooldown can be bypassed by calling an emergency meeting" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/). GameRant adds "a limit to how many times you can call an emergency council session, and each time you do so, you risk losing trust among the factions" — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/).
- Story-mode first vote: the Council unlocks in Chapter 1 with a "Vote of Confidence" over whether you should "stay Captain or not", which serves as the voting tutorial — [GameRant, laws](https://gamerant.com/frostpunk-2-how-propose-negotiate-approve-laws/); [Escapist](https://www.escapistmagazine.com/how-to-approve-laws-in-frostpunk-2/). Council Hall is a one-off building in the Central District — [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council).
- *Breach of Trust* (DLC, 23 Jun 2026): leadership itself is voted on. "A periodic Vote of Trust will act as a direct measure of your approval" — [Steam: BoT announcement](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1828894815565669). The lead designer says "We also added an election mechanic" — [Steam: BoT available](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474). A player guide reports "Every 100 weeks there will be a Council vote if you will remain the 'First Citizen'" and "the first vote at Week 100" — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).

### Inferences
- The proposing power is asymmetric. Only the Steward initiates by default; factions gain initiative only when the Steward hands it over (Grant Agenda), which makes agenda-setting a currency the Steward spends for relations.
- Effective vote frequency is about one per 10 weeks. Emergency sessions can compress this, but under the [snippet-only] 12-week ability cooldown they cannot be chained continuously.
- The "votes automatically every ten weeks" phrasing in the guides most plausibly refers to the session timer forcing a vote on whatever is on the agenda. Whether the game auto-generates a bill when nothing is proposed is unverified.

### Gaps
- Exact Emergency Council Session numbers come only from the [snippet-only] game-vault text: the 12-week cooldown, which groups are affected (relations versus Trust), and the size of the penalty. Whether there is a hard cap on uses, as GameRant claims, is unconfirmed.
- The *Breach of Trust* election interval of 100 weeks rests on a single player report. The vote threshold and how "election voting weights" work (rebalanced in 1.6.1) are not documented in anything I could read.

## 4. What goes to a vote

### Takeaway
The Council votes on laws/policies in four categories (Survival, City, Society, Rule), including repeals and policy changes. Laws must first be unlocked through the Idea Tree. Research itself is not voted on: it is bought with research time and Heatstamps, although research choices shift faction relations. The story mode adds special Rule-tab votes such as Peace Accords and Captain's Authority. *Breach of Trust* (2026) adds votes on the leader (First Citizen election / Vote of Trust). Colonies have no votes of their own.

### Cited Findings
- Laws can be proposed from four categories: "Survival, City, Society, and Rule". You start limited, and "more options will unlock with research and time" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/). The same four categories appear in [Escapist](https://www.escapistmagazine.com/how-to-approve-laws-in-frostpunk-2/) and [Dexerto](https://www.dexerto.com/gaming/frostpunk-2-council-best-laws-to-pass-first-2908202/).
- Laws can be passed or repealed. Negotiation is used "to pass or repeal a law" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/). Patch 1.1.0 lists law-promise variants as "research, pass, repeal" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
- Research versus laws: "Building research will also cost heatstamps, while Law research are free" — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453). Patch 1.5.4: some policies (Criminal Reparation, Guard Immunity, Crime Elimination, Treatment, Housing Distribution) can no longer be researched without a built Council — [Steam: Patch 1.5.4](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1825093633182133).
- Story Rule-tab votes: Peace Accords (proposed from the Rule tab in the Chapter 5 reconciliation path) — [Sportskeeda, Banish/Reconcile/Enforce](https://sportskeeda.com/esports/banish-opposing-faction-seek-reconciliation-enforce-order-frostpunk-2). Captain's Authority is available only in Chapter 5 when you choose to enforce rule, after passing prerequisite Rule laws — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/). Official achievements reference "Captain's Authority policy" and "Complete the Story without passing any Rule laws" — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements).
- Other named voting items: Patch 1.2.2 mentions "voting for Charter Policies" — [Steam: Hotfix 1.2.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1785774543526761). Patch 1.5.0 added "13 centrist policies" for existing laws (free update) — [Steam: Patch 1.5.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592123014); [Steam: Fractured Utopias available](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818118366183463).
- Colonies: "no independent delegates and votings in the colonies" — [Steam: City Unbound Ep. 8](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6242640076596856090).
- Leadership votes (*Breach of Trust*): "periodic public referendums on their leadership" for the First Citizen — [TechTimes](https://www.techtimes.com/articles/318912/20260623/frostpunk-2-breach-trust-launches-volcanoes-new-city-vote-that-can-end-your-rule.htm). Official achievement: "win the next First Citizen Election" — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements).

### Inferences
- In the base game the Council is strictly a legislature for laws, policies and repeals. Executive actions (research, building, colonisation, abilities) are not voted on, but they feed back into votes through relations and Zeitgeist.
- The 2026 DLC is the first content where the Council (or electorate) votes on the leader periodically. In the base story, removal is driven by Trust/Tension crises instead (see section 7).

### Gaps
- What "Charter Policies" are (possibly a story or Utopia-specific law type) is not explained in any source I could read.
- I found no evidence that colonisation or outpost decisions ever go to a vote.

## 5. Negotiation before a vote: promise types, Heatstamps, other tools, deadlines, broken promises

### Takeaway
After proposing, the Steward can "Negotiate" with each bloc. A bloc that is open to negotiation offers a short menu of terms (typically three) and the Steward accepts one. The terms are: pass, repeal or research a specific law/idea; build or demolish a building; use an action toward a community or faction; sometimes grant them the next agenda; and fuel-related promises. Accepting immediately flips that bloc's hesitant delegates (and sometimes opponents) to your side. Since a 15 May 2025 hotfix, every promise must yield votes. Each promise becomes a timed quest. Missing the deadline damages relations and Trust, and you cannot negotiate again with that bloc while a promise is outstanding. There is no documented Heatstamps-for-votes button in the Council. Heatstamps buy relations outside the Council ("Fund Projects"). The coercive alternative is "pressuring" delegates via the Guided Voting procedure (a Rule law), which raises votes at the cost of relations with every faction.

### Cited Findings
- Negotiation flow:
  - Choose "Negotiate" in the Council menu. Each bloc "will indicate if they are open to negotiation or not – if they're not, it's likely because you've already made them a promise that you haven't yet fulfilled, or because the law goes against their beliefs" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/).
  - "They will offer you terms to agree to – you only have to choose one… Whichever promise you make will sway hesitant delegates in that Faction to your side, and delegates who are in opposition to you may switch sides" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/).
  - "Successful negotiations will instantly turn the votes in your favor" — [Escapist](https://www.escapistmagazine.com/how-to-approve-laws-in-frostpunk-2/).
  - Groups you have bad relations with, or that oppose the law's direction, "will almost always vote against the bill and they won't be open to any negotiations" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/).
- Promise menu (term types by source):
  - TheGamer: "Enact a law", "Research an idea", "Build or destroy a building", "Use an action towards a specific Community or Faction" — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/).
  - Game Voyagers: "Pass a law of their choosing at the next meeting", "Research a new idea that will favor them", "Build or demolish a building of their choice" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/).
  - PCGamesN adds "letting them choose the next law to be voted on" (i.e., an agenda grant as payment) — [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council).
  - Gamepressure lists four types: research, construction/destruction, law passage, "actions against opposing factions" — [Gamepressure, Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb).
  - Promise offers usually come as "three options" — [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust); [Screen Rant](https://screenrant.com/frostpunk-2-how-to-increase-trust/).
- Official patch changes to negotiation and promises:
  - 1.1.0 (21 Oct 2024): "Community Actions will be offered more often in Council negotiations".
  - 1.1.0: "Having multiple promise quests to the same law (research, pass, repeal) will no longer be possible".
  - 1.1.0: "It will not be possible to promise to pass a policy that is already on the agenda for the next Council voting session".
  - 1.1.0: "Promises about fuels won't show up if it's not possible to use them with the current Generator upgrade".
  - 1.1.0: "Fixed some broken promises from being looped" — all from [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
  - 1.2.1: "Fixed negotiations not showing the proper outcome" — [Steam: Hotfix 1.2.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506359051615).
  - Patch 1.3 Hotfix #1 (15 May 2025): "It is no longer possible to make any Negotiation promise without getting votes as a reward" — [Steam: FMCU Hotfix #1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799817379469768).
  - 1.5.4: "Fixed a possibility of duplicated negotiation options for Bohemians"; "softblock when attempting to fulfill the Algorithm promise" (controller) — [Steam: Patch 1.5.4](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1825093633182133).
- Deadlines:
  - "Most of these promises have a time limit… Always monitor the time remaining on the upper left corner of the screen, right under the objectives" — [Dexerto](https://www.dexerto.com/gaming/frostpunk-2-council-best-laws-to-pass-first-2908202/).
  - "Once selected, a timer starts, and you must keep your promise before it runs out" — [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust).
  - Since the Council meets only every 10 weeks, a promised law must fit the recess schedule — [PCGamesN, Council](https://www.pcgamesn.com/frostpunk-2/council).
- Broken promises:
  - "Your relations with the defrauded faction will worsen significantly" — [Gamepressure, Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb).
  - Failing "will result in losing trust from that faction, making it harder for them to vote in your favor in the future" — [Escapist](https://www.escapistmagazine.com/how-to-approve-laws-in-frostpunk-2/).
  - "If you fail on your promise, you will lose favor and trust" — [Screen Rant](https://screenrant.com/frostpunk-2-how-to-increase-trust/).
  - The bloc won't negotiate "the next time" — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/).
  - Trust from a promise is only gained on fulfilment: "it won't [rise] until you keep your promise" — [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust).
  - Reneging after the fact is also punished. Patch 1.2.0: "Factions will no longer demand consequences for demolishing promised Coal extraction buildings after the City coal deposits are depleted", which implies they normally do — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
  - 1.1.0 consequence arcs: "Repeatedly failing promise quests for a hostile Faction" and "Quelling a protest after negotiating with a Faction and making a promise" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
- Negotiating *against* a law: "You can not only negotiate to vote in your favor but also to vote against a certain law" (for example, to sink a granted agenda) — [Game Voyagers](https://gamevoyagers.com/frostpunk-2-ultimate-guide-to-the-council/); [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council).
- Heatstamps:
  - "Fund Projects" pays Heatstamps to improve a group's relations: "Pay Heatstamps; Relations improve" — [Game8 tips](https://game8.co/games/Frostpunk-2/archives/473193). It is "fairly bribe-like, but it does work immediately"; funding the same faction repeatedly makes others notice — [Screen Rant](https://screenrant.com/frostpunk-2-how-to-increase-trust/); [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust).
  - Patch 1.2.0 added "Two new events to react to frequent use of Fund Projects and Promote on Communities not aligned with your Zeitgeist" — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
  - Reverse flow: "Raise Funds" collects Heatstamps (relations drop; larger groups pay more), and "Demand Funds" uses guard units (higher earnings, Trust drop, "drastic relationship drop") — [Gamepressure, Factions](https://www.gamepressure.com/frostpunk-2/factions/zc113e2); [Escapist, Community Actions](https://www.escapistmagazine.com/how-to-enact-community-actions-in-frostpunk-2/).
  - Loose wording: "It's possible to sway faction's relations… It can be heatstamps, promise…" — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453). "The Communities might be bribed to voting in your favour" — [Steam guide: All factions](https://steamcommunity.com/sharedfiles/filedetails/?id=3379903271).
- Pressure / Guided Voting:
  - "You can pressure delegates into voting your way. This always results in increased votes for the policy in question but negatively impacts relations with every Faction. However, it does prevent you from having to make any promises" — [PCGamesN, Council](https://www.pcgamesn.com/frostpunk-2/council).
  - The Guided Voting Rule law "curtails debates and convinces wavering delegates to support the motion" (search snippet of [Neoseeker: Guided Voting](https://www.neoseeker.com/frostpunk-2/law/Guided_Voting), page itself 403).
  - It is used to "push the votes over the winning side" for Peace Accords — [Sportskeeda](https://sportskeeda.com/esports/banish-opposing-faction-seek-reconciliation-enforce-order-frostpunk-2).
  - Official changes in Hotfix 1.2.3 (28 Jan 2025): "Guided Voting is no longer a permanent modifier" and "While Captains Authority is active, Guided Voting will no longer apply" — [Steam: Hotfix 1.2.3](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1789580505470820).
  - In *Breach of Trust* it "can help force a political result, but it usually creates trust or promise debt" — [Whisper of the House (player walkthrough; hedged)](https://www.whisperofthehouse.com/frostpunk-2-breach-of-trust/walkthrough).
- Other pre-vote tools that change the electorate rather than individual votes: Promote/Condemn (seat changes), Secret Police "Revoke Council Seats", and, under Captain's Authority, voting "any Law without any opposition" — [Gamepressure, Factions](https://www.gamepressure.com/frostpunk-2/factions/zc113e2); [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
- Story Chapter 5 variant, "Negotiate Peace Agreement": for each faction choose two actions from three areas (demolish/research/build, pass or repeal a law). "The more you delay, the more your Trust falls" — [Sportskeeda](https://sportskeeda.com/esports/banish-opposing-faction-seek-reconciliation-enforce-order-frostpunk-2).

### Inferences
- Negotiation trades votes now for obligations later. The main constraint is the one-outstanding-promise-per-bloc lock combined with the 10-week session cadence. Patches 1.1.0 and 1.3-HF1 tightened exploits: duplicate law promises, promising what is already on the agenda, and zero-vote promises.
- Guided Voting appears to have been nerfed in Jan 2025. Its relations penalty was apparently permanent before 1.2.3 and temporary after; the exact before/after values are not published.
- "Bribery" in the Council is indirect. Heatstamps raise relations, and relations raise the share of a bloc that votes For. No source documents a direct per-vote Heatstamps price.

### Gaps
- No readable source gives promise deadline lengths in weeks, the size of the relations or Trust hit for a broken promise, or the vote counts each term buys.
- The full official list of negotiation term types (for example, what "Algorithm promise" and fuel promises require) is not documented in anything I could read.
- Exact Guided Voting effects (how many hesitant delegates convert, and the size and duration of the relations penalty) are unpublished. The Neoseeker law page returned 403.

## 6. Faction relations: tiers and their effects

### Takeaway
Relations with each community or faction run on a 7-step scale: Devoted, Supporting, Favourable, Neutral, Sceptical, Opposing, Hostile. Favourable or better unlocks the group's Special/Community Action (and, for communities, the Deradicalize "Fervour action"). Devoted or other high relations enable a Good-Relations perk and rallies. Negative relations bring protests, harder votes and workforce losses. Relations combine with Fervour (0–3) to produce rallies (high fervour + good relations) or protests → riots → civil war (high fervour + bad relations). The sum of relations feeds overall Trust.

### Cited Findings
- Scale, best to worst: "Devoted, Supporting, Favourable, Neutral, Sceptical, Opposing, Hostile" — [Game8, Factions](https://game8.co/games/Frostpunk-2/archives/473462); the same seven appear in [GamerGuides](https://www.gamerguides.com/frostpunk-2/guide/communities-and-factions/overview/communities-and-factions-explained). Official achievement text confirms the "Devoted" and "Sceptical" tier names: "Have 'Devoted' relations with all communities and factions"; "Never have relations worse than Sceptical with any community or faction" — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements).
- Tier effects:
  - Positive relations bring "rallies, greater support for you when signing a new law, or even unlocking special perks and actions". Negative relations bring "protests may occur, signing a new law may be difficult, or their community's workforce may even go down" — [Game8, Factions](https://game8.co/games/Frostpunk-2/archives/473462).
  - "Special Actions are locked behind the Favourable Relations status" — [Game8, Factions](https://game8.co/games/Frostpunk-2/archives/473462). Community Action "(Requires Favourable or better Relations)" — [Fandom: Faithkeepers](https://frostpunk.fandom.com/wiki/Faithkeepers_(Faction)). Faction abilities have "a long cooldown and the faction must have at least a 'favorable' view of you" — [PC Gamer](https://www.pcgamer.com/games/city-builder/frostpunk-2-factions/).
  - Good Relations Perks exist per faction, e.g. Icebloods "Hunting trips: Provides Food" and Faithkeepers "Serenity Sermons (Tension is decreased)" — [Fandom: Icebloods](https://frostpunk.fandom.com/wiki/Icebloods); [Fandom: Faithkeepers](https://frostpunk.fandom.com/wiki/Faithkeepers_(Faction)). Patch 1.1.0: "Factions now provide proper bonuses to the city if the Steward maintains good relations" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
  - Rallies start when Favourable or Devoted and offer choices such as Workforce, Heatstamps or Efficiency (search summary of [GamerGuides](https://www.gamerguides.com/frostpunk-2/guide/communities-and-factions/overview/communities-and-factions-explained)). A rally ends when relations leave the "Gold Zone"; repeated rally choices stack (×2 Heatstamps) — [TheGamer, Rallies & Riots](https://www.thegamer.com/frostpunk-2-rallies-riots-guide/).
- Actions that move relations:
  - Improve: Fund Projects, Make Promise, Grant Agenda ("significantly"), Promote ("greatly"; adds members/seats; lowers fervour). Worsen: Condemn (increases Fervour), Raise Funds, Demand Funds. Game8 lists Promote in both columns, likely because it angers the opposing side — [Game8 tips](https://game8.co/games/Frostpunk-2/archives/473193); [Game8, Factions](https://game8.co/games/Frostpunk-2/archives/473462).
  - Escapist groups community actions into Trust (favours such as passing a law or research), Favours (Raise/Demand Funds: Heatstamps but lower Trust), Fervor (Deradicalise: lowers Fervour "at cost of some Trust"), and Council (Promote/Condemn) — [Escapist, Community Actions](https://www.escapistmagazine.com/how-to-enact-community-actions-in-frostpunk-2/).
  - Relations also track Zeitgeist alignment: "The more you develop the City in the direction they support, the more positively it affects your Relations" — [Fandom: Zeitgeist](https://frostpunk.fandom.com/wiki/Zeitgeist).
- Fervour (radicalisation, 0–3): 0 none; 1 Protests (peaceful district shutdowns, end if you negotiate); 2 Riots (violent, "will not negotiate"); 3 Civil War "if allowed to remain at Fervor 3 for long enough" — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
  - Fervour rises from prolonged red relations or refusing demands. "Ending a protest by acquiescing… or negotiating with them will cause the opposing faction's Fervor to rise." Promote lowers Fervour by one point — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
  - Exception: the Icebloods' trait means "Fervour does not decrease due to the 'Promote' Action" and "Relations-worsening effects are amplified" — [Fandom: Icebloods](https://frostpunk.fandom.com/wiki/Icebloods).
- Fervour, protest and faction-war patch history:
  - Launch-day: "First Faction War spread will now occur after 10 weeks, down from 15"; "'Enforce Peace' ability now requires a Prison and no longer removes Faction Fervor" — [Steam: City Maintenance Report](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517).
  - 1.0.5: districts unblock after a protest is resolved via improved relations — [Steam: Hotfix 1.0.5](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6350729003497791230).
  - 1.1.0: "Enacting a Cornerstone now adds 2 fervour to the faction that is aligned with the opposed affinity"; "Factions will no longer drop their relations from Devoted to Hostile if certain conditions are met"; new consequence arcs for "Promoting a Faction only to Raise Funds afterwards" and "Condemning and promoting the same faction in quick succession" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
  - 1.2.0: "Improved factions' reactivity to current city status"; "Six new events furthering faction conflict when conditions are catastrophic"; infinite-protest fix — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
  - Patch 1.3: Serenity mode has "No Fervour system (minimal protests, no faction conflict)" and "no faction wars"; "Improved visibility of Hostile relations"; citizens now react to heating shortages "through negotiations, protests, or praise" — [Steam: FMCU](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350).
- Story-mode limits: only the two factions in the middle of the relations bar can rally or riot, and protests and riots are locked until Chapter 3 — [TheGamer, Rallies & Riots](https://www.thegamer.com/frostpunk-2-rallies-riots-guide/). Quelling protests too often leads to "more severe actions from factions" — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453).

### Inferences
- In vote terms, relation tier appears to set the default For/Against/Undecided mix of a bloc's delegates. High tiers ("above Supporting") are what make near-unanimous votes possible ([Steam 100% guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381)). Hostile blocs are both closed to negotiation and protest-prone.
- Relations and Fervour are separate dials. Promote is the only single action documented to raise relations, raise seats and lower Fervour at once, which is why it is a key (and exploit-patched, see 1.1.0) tool.

### Gaps
- No readable source gives numeric thresholds for the tiers (bar positions), the exact vote-split per tier, or demand frequency per tier.
- Which tier activates the Good-Relations perk is unclear: one summary says Devoted, the 1.1.0 patch says "good relations", and the official wording is unavailable.
- **[unverified]** A search snippet claims "Raise Funds" can be used "every 40 weeks". I could not confirm the source.

## 7. Trust and Tension: definitions, drivers, thresholds, exile/game-over, term-based decay

### Takeaway
Trust (gold bar, bottom HUD) is the population's faith in the Steward. It is an aggregate built from per-group relations and time-limited Trust modifiers (laws, abilities, promises, deaths, crises). Named levels run from Revered down to Despised (one player cites in-game wiki names; *Breach of Trust* has a "Reviled" level). When Trust bottoms out, a timed Trust crisis/ultimatum begins (reportedly: get from 0% back to 25%). Failing it is a "Trust Fail" game over. Tension (flask/orb, bottom centre) measures unrest from Problems (cold, hunger, disease, squalor, crime), Fervour, bad relations and repression. It escalates through levels up to Severe and Catastrophic; sustained maximum Tension triggers final events and then removal or exile. Captain's Authority (story Rule path) replaces the Trust bar, making Trust effectively permanent. *Breach of Trust* (2026) adds periodic Votes of Trust / First Citizen elections that end the run if lost. I found no documented passive, time-based or "term" Trust decay in the base game.

### Cited Findings
- Trust definition and UI:
  - The Trust bar "at the bottom of the screen… is your overall trust for ALL communities and factions" — [GamerGuides](https://www.gamerguides.com/frostpunk-2/guide/communities-and-factions/overview/communities-and-factions-explained).
  - Hovering the golden bar "highlights all the ways in which you are currently losing and gaining the trust of each faction" — [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust).
  - "Trust is the people's belief in your rule, similar to hope from Frostpunk 1. Reaching trust 0 will end your game as you are forced out of power" — [NoobFeed](https://www.noobfeed.com/articles/frostpunk-2-all-problems,-trust-&-tension-and-how-to-solve-them).
- Trust levels:
  - A Steam commenter: "The trust levels according to in-game wiki are - Revered, Respected, Accepted, Tolerated and Despised"; another: "Reviled is the lowest possible rating… literally 0 trust" — [Steam 100% Achievement Guide (comments)](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
  - Official achievements: "People person: Have maximum trust"; "Comeback Kid: Have 'Reviled' level of Trust and then win the next First Citizen Election" (*Breach of Trust*) — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements).
- Trust drivers:
  - Up: fulfilled promises (only on fulfilment), Grant Agenda (immediate), Fund Projects (immediate), laws favoured by large factions — [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust); [Sportskeeda, Trust](https://www.sportskeeda.com/esports/increase-trust-frostpunk-2-promises-agenda-funding-abilities-laws). Community actions such as Faithkeepers' "Hold Evening Prayers (Increases Trust slightly)" — [Fandom: Faithkeepers](https://frostpunk.fandom.com/wiki/Faithkeepers_(Faction)). The Bureau of Propaganda (Rule) makes "not-so-great choices have less of an impact on Trust" — [Dexerto](https://www.dexerto.com/gaming/frostpunk-2-council-best-laws-to-pass-first-2908202/).
  - Down: broken promises; abilities such as Emergency Shifts and Rush Research (toggling them off "doesn't immediately restore trust"); whiteouts — [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust). "Non-natural deaths, starvation, disease, and crime" — [NoobFeed](https://www.noobfeed.com/articles/frostpunk-2-all-problems,-trust-&-tension-and-how-to-solve-them). Demand Funds and Deradicalize also cost Trust — [Gamepressure, Factions](https://www.gamepressure.com/frostpunk-2/factions/zc113e2); [Escapist, Community Actions](https://www.escapistmagazine.com/how-to-enact-community-actions-in-frostpunk-2/). Emergency Council Session costs Trust **[snippet-only]** — [game-vault Council](https://frostpunk-2.game-vault.net/wiki/Council). Abilities used in colonies affect overall Trust too — [Screen Rant](https://screenrant.com/frostpunk-2-how-to-increase-trust/).
- Trust modifiers are time-limited (official patch evidence):
  - 1.1.0: "Fixed never expiring negative Trust modifier after using 'Rush Research'"; "Fixed infinite Trust exploit"; "Fixed crash related to communities trust modifiers" — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
  - Launch-day: "Slightly reduced initial Trust across all difficulty levels" — [Steam: City Maintenance Report](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517).
  - *Breach of Trust* era: "'Rush Researches' now lasts 20 weeks instead of 30" — [Steam: BoT available](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474).
- Trust crisis and game over:
  - **[snippet-only]** "If Trust falls to Despised you are given an ultimatum quest to earn trust back up from 0% to 25%. Failure to complete this ultimatum quest results in game over" — [game-vault Trust](https://frostpunk-2.game-vault.net/wiki/Trust).
  - Official naming: "Never be in danger of losing your position due to low Trust or high Tension"; "without ever triggering the Tension or Trust crises" — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements). A guide notes that "once you get a prompt that you need to handle either Trust or Tension within certain time", you have entered the crisis — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
  - Patch 1.2.0: "Trust Fail game over screen will now pop with a delay rather than right after voting" — [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
  - Distrusting factions "attempt to vote you out" — [Screen Rant](https://screenrant.com/frostpunk-2-how-to-increase-trust/).
- Tension definition and levels:
  - An orb at bottom centre fills with black liquid; hovering shows severity and contributing factors; "If Tension reaches maximum limit, the City will fall into uncontrollable chaos and it will lead to a game over" — [Game8, Tension](https://game8.co/games/Frostpunk-2/archives/474374).
  - Levels named in sources include "Absent" (achievement "Have Crime and Tension Absent…"), "Severe" and "Catastrophic" — [Steam achievements](https://steamcommunity.com/stats/1601580/achievements); [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/); [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/). A search summary listed Absent, Low, Moderate, High, Severe, Catastrophic, but I could not verify the middle names.
- Tension drivers:
  - Problems (cold, hunger, disease, squalor, crime) plus Fervour; factions "with high Fervour or bad Relations can also cause Tension to rise significantly", so keep relations "Neutral at the very least" — [Game8, Tension](https://game8.co/games/Frostpunk-2/archives/474374); [Gamertweak](https://gamertweak.com/how-to-decrease-tension-in-frostpunk-2/).
  - "Political disruption and unpopular laws" — [NoobFeed](https://www.noobfeed.com/articles/frostpunk-2-all-problems,-trust-&-tension-and-how-to-solve-them).
  - Round Up Faction Members causes "a large increase in your city's Tension" — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/). Condemn "will increase Tension rapidly" — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
  - Tension falls via the Fighting Hub, some laws (e.g., Icebloods' "Honour scars: Tension is slightly decreased"), and perks (Faithkeepers' Serenity Sermons) — [Game8, Tension](https://game8.co/games/Frostpunk-2/archives/474374); [Fandom: Icebloods](https://frostpunk.fandom.com/wiki/Icebloods); [Fandom: Faithkeepers](https://frostpunk.fandom.com/wiki/Faithkeepers_(Faction)).
- Tension crisis and removal:
  - **[snippet-only]** "If high tension will not be reduced final Events will take place giving the Steward a last chance to take Problems under control before being exiled" — [game-vault Tension](https://frostpunk-2.game-vault.net/wiki/Tension).
  - "Spending too long in this state may cause the factions to vote for your removal from office and subsequent banishment (an automatic gameover)" — [TheGamer, Rallies & Riots](https://www.thegamer.com/frostpunk-2-rallies-riots-guide/).
  - At the maximum, "your game will end as you are removed from power" — [NoobFeed](https://www.noobfeed.com/articles/frostpunk-2-all-problems,-trust-&-tension-and-how-to-solve-them).
  - Story Chapter 5 scripted version: Tension escalates "to the catastrophic stage, and you must bring it down to severe levels before time runs out… [or] game over" — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/).
- Captain's Authority (story Rule path):
  - Launch-day fix: "trust bar not changing to 'Captain's Authority' if it was force-passed by 'Stage Coup' ability" — [Steam: City Maintenance Report](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517).
  - "Once the rule is enforced, Trust becomes permanent" — [Sportskeeda](https://sportskeeda.com/esports/banish-opposing-faction-seek-reconciliation-enforce-order-frostpunk-2). "By being Captain, trust will never be an issue" — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
  - Requirements: Captain's Authority needs ≥45 guards plus a prison to "Secure Rule". "Stage Coup" (offered if Captain's Authority is not enacted in time) needs 90 guards — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/).
  - Patch 1.0.4 added "Load Chapter Start" for when a "Steward career ends prematurely" — [Steam: Hotfix 1.0.4](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6339469370185977484).
- *Breach of Trust* (23 Jun 2026):
  - "A periodic Vote of Trust will act as a direct measure of your approval" — [Steam: BoT announcement](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1828894815565669). "Fail to maintain citizen confidence, and you share the fate of the Old Captain who preceded you: removal" — [TechTimes](https://www.techtimes.com/articles/318912/20260623/frostpunk-2-breach-trust-launches-volcanoes-new-city-vote-that-can-end-your-rule.htm).
  - Hotfix 1.6.1 (2 Jul 2026): "Balanced election voting weights"; "Fixed an issue on the Conquer Aurora path where players could incorrectly lose the game despite winning the vote of trust" — [Steam: Hotfix 1.6.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1836506165567957).
  - The interval is reportedly 100 weeks — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
  - Warm districts help Trust and approval — [Whisper of the House (player walkthrough)](https://www.whisperofthehouse.com/frostpunk-2-breach-of-trust/walkthrough).

### Inferences
- Base-game removal has two independent fail routes: a Trust crisis (bottomed-out Trust leads to a timed recovery quest, then Trust Fail) and a Tension crisis (maximum Tension leads to final events, then removal or exile). Both are timed "last chance" states rather than instant losses, apart from scripted story deadlines. Captain's Authority removes the Trust route but not the need to manage unrest.
- The absence of any documented "term" decay is consistent with Trust being computed from current relations and expiring modifiers. *Breach of Trust* adds an explicitly periodic accountability check (election), which the base game lacks.
- "Reviled" (*Breach of Trust* achievement) versus "Despised" (base-game wiki/guides) may be a DLC-specific relabelling or a naming inconsistency. Treat both as the bottom tier.

### Gaps
- The Trust ultimatum's duration in weeks, its exact trigger (0% versus entering "Despised"), and the 25% target rest only on the [snippet-only] game-vault Trust page. No numeric Trust or Tension thresholds for each named level were readable.
- The Tension crisis timer and what the "final events" contain are undocumented beyond the snippet.
- I found no source confirming or denying passive Trust decay over time.
- *Breach of Trust*: the vote threshold, the delegate weighting ("election voting weights"), and whether the 100-week interval is fixed were not found in official text.

## 8. Explicit numbers (consolidated) and launch-vs-patch summary

### Takeaway
The hard numbers that are well corroborated are: 100 delegates; 51 for simple majority; 67 (two-thirds) for Rule laws; a 10-week recess after every vote; one proposal per session; seats equal to population share. Less certain: the Emergency Council Session's 12-week cooldown (snippet-only); the Trust ultimatum 0%→25% (snippet-only); Fervour levels 0–3; 7 relation tiers; Captain's Authority guard thresholds (45 to Secure Rule, 90 for Stage Coup); the *Breach of Trust* election roughly every 100 weeks (single player report). The main rule changes after launch came in 1.1.0 (Oct 2024: negotiation and promise exploits), 1.2.0 (Nov 2024: Emergency Session from the Council window during recess, delayed Trust-fail screen), 1.2.3 (Jan 2025: Guided Voting modifier made non-permanent and disabled under Captain's Authority), 1.3 Hotfix #1 (May 2025: every promise must yield votes), and the 2026 *Breach of Trust* election system.

### Cited Findings
#### Numbers
- 100 delegates; 51 votes; 67 for two-thirds — [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council); [Fandom: The Council](https://frostpunk.fandom.com/wiki/The_Council); [Gamepressure, Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb).
- 10-week recess after each vote; one law per session — [Gamepressure, Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb); [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council). This conflicts with GameRant's "two in-game weeks" — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/).
- Emergency Council Session: 12-week cooldown, resets the recess timer **[snippet-only]** — [game-vault Council](https://frostpunk-2.game-vault.net/wiki/Council).
- 4 law categories (Survival, City, Society, Rule) — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/).
- Negotiation: choose 1 of the offered terms (usually 3 options) — [TheGamer, Council](https://www.thegamer.com/frostpunk-2-council-laws-negotiate-complete-guide/); [PCGamesN, Trust](https://www.pcgamesn.com/frostpunk-2/trust).
- 7 relation tiers — [Game8, Factions](https://game8.co/games/Frostpunk-2/archives/473462). Fervour 0–3 — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
- The first Faction War spreads after 10 weeks (was 15 before the launch-day patch) — [Steam: City Maintenance Report](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517).
- Cornerstone enactment adds +2 fervour to the opposed faction (1.1.0) — [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
- Promote: −1 Fervour — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
- Round Up Faction Members: up to 500 arrests — [TheGamer, Fervor](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/).
- Stalwarts' "Mobilise Enforcers": 5 guard squads (10 with automaton-guard law) — [PC Gamer](https://www.pcgamer.com/games/city-builder/frostpunk-2-factions/); [Game8, Factions](https://game8.co/games/Frostpunk-2/archives/473462).
- Trust ultimatum: from 0% to 25% **[snippet-only]** — [game-vault Trust](https://frostpunk-2.game-vault.net/wiki/Trust).
- Captain's Authority: ≥45 guards plus a prison to Secure Rule; Stage Coup needs 90 guards — [GameRant, Captain's Rule](https://gamerant.com/frostpunk-2-how-enforce-captains-rule/).
- *Breach of Trust*: an election roughly every 100 weeks (player report) — [Steam 100% Achievement Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3336319381).
- Council Hall is buildable around week 35 at the earliest on normal difficulty in the story — [PCGamesN](https://www.pcgamesn.com/frostpunk-2/council).

#### Launch vs patched rules (official patch notes)
- **Launch day (20 Sep 2024):**
  - Initial Trust slightly reduced.
  - Enforce Peace requires a Prison and no longer removes Fervour.
  - Faction War spread starts at 10 weeks (from 15).
  - Stage Coup → "Captain's Authority" trust-bar fix.
  - Grant Agenda notification fix.
  - Source: [Steam: City Maintenance Report](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6341720536506541517).
- **1.1.0 (21 Oct 2024):**
  - Community Actions offered more often in negotiations.
  - No duplicate law promises (research/pass/repeal).
  - Can't promise a policy already on the next agenda.
  - Negotiation and Grant Agenda offers weigh city needs.
  - New consequence arcs: Promote → Raise Funds abuse; failing promise quests for a hostile faction; condemn/promote flip-flops; failing too many votes after granting agenda; quelling a protest after promising.
  - Cornerstone +2 fervour to opposed faction.
  - Devoted → Hostile drop fix.
  - Infinite-Trust exploit fixed.
  - Recess-end audio cue.
  - Source: [Steam: Patch 1.1.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212244583190849562).
- **1.2.0 (27 Nov 2024):**
  - Emergency Council Session available from the Council window during Recess.
  - Trust Fail game-over screen delayed after voting.
  - New faction events (catastrophic conditions; Fund Projects/Promote overuse on non-aligned communities; helping pass a non-aligned community's law).
  - Source: [Steam: Patch 1.2.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1784506358984832).
- **1.2.3 (28 Jan 2025):**
  - "Guided Voting is no longer a permanent modifier."
  - Guided Voting no longer applies under Captain's Authority.
  - Source: [Steam: Hotfix 1.2.3](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1789580505470820).
- **1.3 / Free Major Content Update (8 May 2025):**
  - Serenity mode removes Fervour and faction wars.
  - Heat shortages trigger negotiations and protests.
  - Deaths tied to specific groups.
  - Sources: [Steam: FMCU](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799088287835350). Hotfix #1 (15 May 2025): "no longer possible to make any Negotiation promise without getting votes as a reward" — [Steam: FMCU Hotfix #1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1799817379469768).
- **1.4.x (Sep–Oct 2025):**
  - Controller-era fixes: Peace Accords law visibility, Trust tutorial prompts, fervour tutorial, promised-law highlight VFX.
  - No mechanical rule changes stated.
  - Sources: [Steam: Hotfix 1.4.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1811772772511895); [Steam: Hotfix 1.4.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1814942955104500).
- **1.5.x (Dec 2025 – Feb 2026, *Fractured Utopias*):**
  - Faction utopias and skill trees "earn the favour of your chosen faction".
  - 13 centrist policies (free).
  - "Contained Factions" state.
  - Bohemian duplicate-negotiation fix.
  - Sources: [Steam: Patch 1.5.0](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1818752592123014); [Steam: Hotfix 1.5.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1819386365086607); [Steam: Patch 1.5.4](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1825093633182133).
- **1.6.x (Jun–Jul 2026, *Breach of Trust*):**
  - Periodic Vote of Trust / First Citizen elections in the new New Edinburgh scenario.
  - 1.6.1 rebalanced "election voting weights" and fixed a wrongful loss after winning the vote of trust.
  - Sources: [Steam: BoT available](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1835871199315474); [Steam: Hotfix 1.6.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1836506165567957).
- No official patch note I read changes the 100-delegate size, the 51/67 thresholds, or the 10-week recess. These appear unchanged from launch through 1.6.1 — [all Steam announcements for app 1601580, via the Steam News API listing above].

### Inferences
- The core constitutional numbers (100 / 51 / 67 / 10 weeks) look stable across all versions. Post-launch work concentrated on the *edges*: abuse of promises, agendas and Promote; Guided Voting strength; emergency-session access; and, in 2026, a new electoral layer in one DLC scenario.
- Most third-party guides cited here appear to date from the launch window (PC Gamer's is explicitly updated 24 Sep 2024). Their descriptions of negotiation (for example, promises without votes, permanent Guided Voting penalties) may describe pre-1.1.0 or pre-1.2.3 behaviour.

### Gaps
- No readable source gives numeric values for promise deadlines, Trust or Tension level thresholds, Trust deltas per action, Emergency Session penalty size, Guided Voting conversion rate, or *Breach of Trust* election thresholds.
- The game-vault wiki pages that likely hold several of these (Council, Trust, Tension, Laws, Heatstamps, Factions, Communities) exist with 2026 snapshots on the Wayback Machine, but could not be read from this session (Cloudflare 403 on the live site; web.archive.org blocked by egress policy). A follow-up with browser access to those pages would close most remaining gaps.
