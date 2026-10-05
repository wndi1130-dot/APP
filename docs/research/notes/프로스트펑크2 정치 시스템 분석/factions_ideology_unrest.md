# Frostpunk 2 Political Model: Factions, Communities, Ideology, Demands and Unrest (launch Sept 2024 to Oct 2026)

Evidence tags used below:
- **[Official]** means 11 bit studios copy or official patch notes (mirrored on GOG DB).
- **[Guide]** means a full page I fetched from a press or Steam guide.
- **[Snippet]** means the text came only from a search-result summary, because the page itself was blocked (HTTP 403) or not fetched. Treat these as plausible but unverified.
- **[Low-reliability]** means an SEO-style site whose content conflicts with better sources.

The Game Vault wiki (frostpunk-2.game-vault.net), NamuWiki, Neoseeker, DotEsports, Sportskeeda, Twinfinite and PC Gamer all returned 403 or empty pages, so I could not verify them in full.

## 1. Factions vs. communities: formation, growth, radicalization, merging, and what triggers a new faction

### Takeaway
Communities are single-Cornerstone population blocs. Their delegates can be bargained with in the Council. Factions are organized parties holding three Cornerstones, one on each axis. They will not vote against their beliefs, and they carry Fervor (radicalization), so they are the ones that rally, protest, riot or go to civil war. A faction crystallizes out of the city's own ideological drift: once the city has moved toward a Cornerstone on all three axes, a faction forms around the three leading Cornerstones. It recruits from communities that share its beliefs, and its members flow back to those communities when it shrinks. In Utopia Builder, the second faction is always the exact ideological opposite of the first.

### Cited Findings
**Definitions**
- Communities are "everyday civilian groups aligned to a single Cornerstone" and make up most of the population. Their delegates usually vote by their principle but "can usually be negotiated with" to vote against it. [Guide] — [TheGamer: Complete Faction Guide](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Factions are "organized political parties aligned to three Cornerstones". They "refuse to vote against their beliefs, and can't be negotiated with in the Council", and they "organize rallies or protests based on their relations with the Steward." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Partial conflict on negotiation: other guides say you can "negotiate with the faction to earn their votes" [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453). Gamepressure also describes pre-vote negotiation with factions [Guide] — [Gamepressure: Council](https://www.gamepressure.com/frostpunk-2/council/zf115fb). Most likely reading: factions can be bargained with on laws that do not contradict their Cornerstones, but not into voting against them.

**How factions form and grow**
- Factions form "once your city has made steps toward a Cornerstone on all three axes." The faction adopts "whichever three principles are currently ahead." Choosing laws and ideas carefully lets the player influence which factions appear. [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Membership flow, quoted from TheGamer [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/):
  - "When a faction gains members, they will be drawn from a community that shares that faction's beliefs."
  - "When a faction loses members, they will return to their original community."
- Utopia Builder (UB) second faction: it arrives "a short while later" and is "always the faction with the exact opposite Cornerstones as the first one." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- UB start: the city "always starts with three communities and no factions." Two of these communities have opposite Cornerstones and the third is random. [Snippet] — [PC Gamer](https://www.pcgamer.com/games/city-builder/frostpunk-2-factions/). TheGamer says the three are "player-selected or random." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)

**Story mode**
- Story mode starts with two communities: New Londoners (Progress) and Frostlanders (Adaptation). The first ("primary") faction is "determined by prologue choice": Stalwarts or Faithkeepers. The opposition factions (Pilgrims or Evolvers) "emerge later." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Patch 1.1.0 (21 Oct 2024) confirms that communities are "independent" before a second faction appears: "Visible tags on the Council description of independent communities in the main scenario before the second faction forms in the city." [Official] — [GOG DB release notes](https://www.gogdb.org/product/1728870436/releasenotes)
- "You start with 2 Communities, those are population groups that follows specific zeitgeist ideology." Their "basic ideology presets will define the way they react to decisions." Also: "As gameplay progresses, Factions will start to form. Different research, laws, event decisions will make factions like or dislike you." [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453). The guide links "zeitgeist" to a Game Vault "Zeitgeist" page, which suggests "Zeitgeist" is the game's term for the city's ideological balance (not verified).

**Seats, fervor and deradicalization**
- Council seats: "A population's votes in the Council are proportional to their percentage of the population." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/). There are 100 delegates. [Guide] — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- Radicalization is a faction-level property: "when a faction feels ignored or becomes too unhappy, they can gain something called Fervor" (max 3 levels, shown as a diamond-shaped fist icon). [Guide] — [GameRant: Deradicalize guide](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/)
- Deradicalization runs back through communities. ScreenRant: you can convince faction members to "return to their communities" if you have good relations with those communities. [Guide] — [ScreenRant: Faction riots](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/). GameRant gives the cost and effect [Guide] — [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/):
  - It requires Favorable-or-better relations.
  - It damages relations with both groups.
  - The faction loses members.
  - Fervor drops by one full level.
- The Deradicalize action sits "under the Fervor tab (the fist icon) when you select a community." [Snippet] — [TheGamer: Fervor guide](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/)
- Patch 1.3 (May 2025): "Every Community and Faction can now occupy an individual district." [Official, via press] — [GamingBolt](https://gamingbolt.com/frostpunk-2-update-adds-new-sandbox-map-overhauls-heating-serenity-mode-and-more)

### Inferences
- The opposition is produced by the player. Every law and idea pushes the city's Cornerstone balance, and the balance decides which faction crystallizes. Factions are mirrors of the Steward's cumulative choices, not fixed starting actors.
- Factions grow by draining like-minded communities. As factions expand, the pool of negotiable community delegates shrinks, so the Council should get harder to bargain with over time. This is consistent with the rules but not stated by any source.
- Each community holds only one Cornerstone, so one community can feed several factions. For example, Foragers (Adaptation) can feed Bohemians, Icebloods, Menders or Proteans. This makes communities a shared recruiting pool and the target of the "send them back to their community" deradicalization route.

### Gaps
- No source gives numbers for how far the city must move toward a Cornerstone before a faction spawns, or for faction growth rates.
- It is unclear whether communities themselves can gain Fervor. Sources only describe Fervor for factions.
- The exact story-mode prologue choice that yields Stalwarts vs. Faithkeepers, and the chapter in which each opposition faction appears, could not be confirmed. The Game Vault, NamuWiki and DotEsports pages were blocked.

## 2. Ideological axes and where each faction and community sits

### Takeaway
The three axes are verified:
- **Progress vs. Adaptation**
- **Equality vs. Merit**
- **Tradition vs. Reason**

These give six Cornerstones. Each community holds one. Each faction holds one per axis, so there are 2³ = 8 possible factions. Utopia Builder uses all eight, arranged as four opposite pairs. Story mode uses four.

### Cited Findings
- The six Cornerstones form three opposing axes: Progress vs. Adaptation, Equality vs. Merit, Tradition vs. Reason. [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Korean localization: per NamuWiki, the official Korean standard renders the axes as "progress↔adaptation, equality↔profit [Merit], reason↔tradition." The exact Korean words were not retrieved. [Snippet] — [NamuWiki: 프로스트펑크 2/세력](https://en.namu.wiki/w/%ED%94%84%EB%A1%9C%EC%8A%A4%ED%8A%B8%ED%8E%91%ED%81%AC%202/%EC%84%B8%EB%A0%A5)

**Story mode** [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/); cross-checked with [GameRant: All factions](https://gamerant.com/frostpunk-2-all-factions-communities-motivation-explained/)

| Group | Type | Cornerstones | Ability |
|---|---|---|---|
| New Londoners | Community | Progress | — |
| Frostlanders | Community | Adaptation | — |
| Stalwarts | Faction ("primary", prologue-dependent) | Progress, Merit, Reason | Recruit Enforcers (extra Guard Squads) |
| Faithkeepers | Faction ("primary", prologue-dependent) | Progress, Equality, Tradition | Evening Prayers (increases Trust) |
| Pilgrims | Faction (opposition) | Adaptation, Equality, Tradition | Deploy Guides (faster expeditions) |
| Evolvers | Faction (opposition) | Adaptation, Merit, Reason | Enhance Workers (production efficiency) |

- Pilgrims are the exact opposite of Stalwarts, and Evolvers are the exact opposite of Faithkeepers. This matches the opposite-pair rule.
- Flavour text [Snippet] — [Game8: List of All Factions](https://game8.co/games/Frostpunk-2/archives/473462) / [DotEsports](https://dotesports.com/frostpunk/news/all-factions-and-communities-in-frostpunk-2-explained):
  - Pilgrims are "bound by tradition."
  - Stalwarts are "strict disciples of the late Captain."
  - Faithkeepers are "religious followers who seek ascension via technology."
  - Evolvers are "calculating individualists who oppose religious fanaticism."
- Wikipedia labels the story factions "Stalwarts (Order), Faithkeepers (Faith)". [Guide] — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)

**Utopia Builder communities** [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/); [GameRant](https://gamerant.com/frostpunk-2-all-factions-communities-motivation-explained/)

| Community | Cornerstone | Opposite community |
|---|---|---|
| Foragers | Adaptation | Machinists |
| Machinists | Progress | Foragers |
| Labourers | Equality | Merchants |
| Merchants | Merit | Labourers |
| Lords | Tradition | Thinkers |
| Thinkers | Reason | Lords |

- Naming conflict: TheGamer's faction guide calls the Tradition community "Nobles". GameRant, the search snippet and TheGamer's own Idea-tree article ([TheGamer: Best ideas](https://www.thegamer.com/frostpunk-2-best-ideas-research-first/)) call it "Lords". "Lords" is probably the in-game name.

**Utopia Builder factions** [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/); abilities cross-checked with [GameRant](https://gamerant.com/frostpunk-2-all-factions-communities-motivation-explained/)

| Faction | Cornerstones | Exact opposite | Ability (TheGamer / GameRant) |
|---|---|---|---|
| Bohemians | Adaptation, Equality, Reason | Overseers | Mindshaping (Trust) / improves Trust and community relations |
| Overseers | Progress, Merit, Tradition | Bohemians | Overdrive Output (production) / production up, crime down |
| Icebloods | Adaptation, Merit, Tradition | Technocrats | Volunteer Expeditions (+80 food) / food production |
| Technocrats | Progress, Equality, Reason | Icebloods | Optimize Research / research speed |
| Legionnaires | Progress, Equality, Tradition | Proteans | Raise Prefabs (instant Prefabs) / "instant Prefabs and additional Guard Squads" |
| Proteans | Adaptation, Merit, Reason | Legionnaires | Coordinate Patient Care / reduces disease |
| Menders | Adaptation, Equality, Tradition | Venturers | Rescue Operations (population) / rescues survivors |
| Venturers | Progress, Merit, Reason | Menders | **Conflict:** "Finance Mercenaries (Guard Squads)" (TheGamer) vs. "Increases Heatstamp income" (GameRant) |

- Official DLC flavour for the eight factions, quoted from 11 bit / dlcompare [Official] — [11 bit studios](https://11bitstudios.com/frostpunk-2s-first-dlc-reforges-the-utopia-builder-mode/); [Snippet] — [dlcompare](https://www.dlcompare.com/gaming-news/frostpunk-2-expansion-ideological-conflict-in-the-frostland):
  - "The old-world Overseers uphold order through industry, clashing with the provocative art and drug-fueled rebellion of the Bohemians."
  - "The Icebloods demand survival through strength, while the Technocrats advocate for cold, algorithmic efficiency."
  - "The adaptive Proteans reshape body and purpose, as the Legionnaires march in disciplined unison."
  - "The extravagant Ventures profit off chaos, while the collectivist Manders bear their burdens – together."
  - The official copy spells "Ventures" and "Manders", most likely typos for Venturers and Menders.

**Breach of Trust DLC (23 June 2026)**
- It adds "five new communities and factions … each with distinct backgrounds, ideologies, and demands." The article does not name them. [Guide] — [TechTimes](https://www.techtimes.com/articles/318912/20260623/frostpunk-2-breach-trust-launches-volcanoes-new-city-vote-that-can-end-your-rule.htm)
- Group names appearing in patch notes [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes):
  - "Brokers 'Mediate' capability"
  - "the Aurora Spongers story arc"
  - "Aurora's communities/factions"
  - "the Herders" (listed under a Fractured Utopias fix in 1.5.4)

**Source quality**
- [Low-reliability] — [frostpunk2.wiki](https://frostpunk2.wiki/factions/) (titled "September 2026"):
  - Its communities page calls Pilgrims, Stalwarts, Faithkeepers and Evolvers "communities." [frostpunk2.wiki communities](https://frostpunk2.wiki/factions/communities/)
  - Its UB faction blurbs (for example "Bohemians boost culture, morale…") conflict with the ability lists above.
  - Do not use it.

### Inferences
- Opposite pairs differ on all three axes. Any law tied to one Cornerstone therefore pleases one side of every pair and angers the other. The axes create structural bipolarity rather than shifting coalitions.
- Each faction shares exactly one Cornerstone with each of the six communities' poles. Every faction can win support from three communities and is opposed by the other three.
- Brief Frostpunk 1 contrast: the story factions labelled "Order" (Stalwarts) and "Faith" (Faithkeepers) echo FP1's Order/Faith purpose paths. Frostpunk 2 turns those paths into factions that fight each other within a multi-axis system. This reading is based on the Wikipedia labels.

### Gaps
- Names and Cornerstones of the five Breach of Trust groups were not found.
- No source said whether UB players can pick which three starting communities they get. TheGamer says "player-selected or random"; the PC Gamer snippet says two are opposite and one is random.
- The Venturers' and Legionnaires' guard-related abilities conflict between sources and were not verified in game.

## 3. How the Idea tree and laws feed politics

### Takeaway
Research is political. Most ideas come in competing variants proposed by groups with different Cornerstones, and picking one pleases its backers and upsets the others. Laws must first be unlocked in the Idea tree, then passed in a 100-delegate Council. Ordinary laws need 51 votes; laws that expand the Steward's power need two-thirds. Laws and ideas move the city's Cornerstone balance, and that balance decides which factions form. Enacting a full Cornerstone grants a strong ability but adds +2 Fervor to the opposing faction (since patch 1.1.0). Fractured Utopias (Dec 2025) added per-faction "Utopia trees" in Utopia Builder.

### Cited Findings
**Idea tree**
- "The Idea Tree allows players to explore different ideas proposed by the game's various factions to solve a problem. Adopting a faction's idea may upset other factions and communities." [Guide] — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- "The Communities and Factions will have their own say on what they value more (usually between Progress or Adaptation) and will offer different solutions for the policies/buildings you can construct." Fully embracing one ideal grants "a powerful Cornerstone ability, such as Automation Primacy from the Progress route", which "will massively decrease Squalor." [Guide] — [GamerGuides: Idea Tree](https://www.gamerguides.com/frostpunk-2/guide/construction/buildings/research-institute-and-the-idea-tree-explained)
- Example variants with their supporters (Logistics Bay) [Guide] — [TheGamer: Best ideas to research first](https://www.thegamer.com/frostpunk-2-best-ideas-research-first/):
  - **Vanguard Logistics Bay:** 120 Heatstamps, 20 Scouts. Supported by Thinkers, Lords, Frostlanders, Pilgrims, Proteans, Foragers.
  - **Automated Logistics Bay:** 120 Heatstamps, 15 Scouts. Supported by Stalwarts, New Londoners, Machinists, Merchants.
  - Oddity: the Vanguard list contains both Thinkers (Reason) and Lords (Tradition), which are opposites. Either the variant carries several tags or the article is wrong.
- Other research and policy effects [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-best-ideas-research-first/):
  - Researching Merit-Based Housing "will help increase trust further among factions" once the required law passes.
  - Teaching Hospitals can "slightly increase tension."
- Watchtower variants: "the Stalwarts faction wants Surveillance Watchtowers, the Pilgrims want Patrol Watchtowers, and the New Londoners and Frostlanders want simple Watchtowers." Faction variants are "usually … better than basic ones." [Snippet] — likely [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453) or [Game Vault: Idea Tree](https://frostpunk-2.game-vault.net/wiki/Idea_Tree); not confirmed on the full page.
- Tree structure [Snippet] — [Game Vault: Idea Tree](https://frostpunk-2.game-vault.net/wiki/Idea_Tree) / [GamerGuides](https://www.gamerguides.com/frostpunk-2/guide/construction/buildings/research-institute-and-the-idea-tree-explained):
  - The tree has six tabs: Heating, Resources, Frostland, City, Society, Hubs.
  - It is accessible only while a Research Institute is active.
  - "Building research will also cost heatstamps, while Law research are free." The 1.3 heating overhaul may have changed this.

**Laws and the Council**
- Laws must be researched before they can be voted on. Patch 1.5.4 (18 Feb 2026): "It is no longer possible to research Criminal Reparation, Guard Immunity, Crime Elimination, Treatment and Housing Distribution policies without a built Council." [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
- Council rules: "100 members of the community, each representing a certain faction, will cast votes on laws proposed by the player." Laws need "simple 51-vote majorities for most laws and two-thirds for anything that may grant the Steward more power." [Guide] — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- Law categories: Survival, City, Society and Rule. Rule laws concentrate the Steward's authority and need "2/3 of all delegates." "Each vote is followed by a 10-week break." [Guide] — [Gamepressure](https://www.gamepressure.com/frostpunk-2/council/zf115fb). The Steam guide also says "about every 10 weeks." [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453)

**Cornerstones and patch changes**
- Patch 1.1.0 (21 Oct 2024), quoted [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes):
  - "Enacting a Cornerstone now adds 2 fervour to the faction that is aligned with the opposed affinity."
  - "Cornerstone messages should no longer appear for opposite affinity."
- Patch 1.3 (May 2025): "a new law, five reworked laws", nine new research topics and three revamped technologies. Laws and research that "previously affected Heat demand, now relate to Heat Levels." [Official, via press] — [GamingBolt](https://gamingbolt.com/frostpunk-2-update-adds-new-sandbox-map-overhauls-heating-serenity-mode-and-more)

**Example laws and their political charge**
- Family Apprenticeship appeases the Pilgrims. [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- "Sterilization or Human Experimentation" are "extreme laws". "Peace Accords" and "Captain's Authority" (a two-thirds Rule law) appear in the story finale. [Guide] — [GameRant: Chapter 5](https://gamerant.com/frostpunk-2-banish-seek-reconciliation-enforce-order-decisions/)
- "Martial Law" (Fractured Utopias) lowers the Guard Squad cost of the "Organise Filtration Posts" ability. [Official] — [GOG DB 1.5.4](https://www.gogdb.org/product/1728870436/releasenotes)
- "Extreme law" is tied to Faction War, per patch 1.1.0: "Fixed possible Faction War softblock if Steward repealed extreme law and enacted it again." [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)

**Fractured Utopias (UB DLC, 8 Dec 2025)** [Official] — [11 bit studios](https://11bitstudios.com/frostpunk-2s-first-dlc-reforges-the-utopia-builder-mode/)
- Each faction gets "a defined ideological Utopia – represented by a skill-tree powered by affinities."
- Gaining trust "unlock[s] specialized laws, buildings, and abilities." There are 12 unique unlocks per faction.
- "Unlock every tier, and a singular vision may be enacted – binding the entire city to one future, and promising to resolve all Tension… permanently."

### Inferences
- The political loop runs in five steps:
  1. A problem appears (heat, food, crime).
  2. Competing idea variants are offered by groups with different Cornerstones.
  3. Researching a variant pleases its backers and upsets the others.
  4. Passing the matching laws moves the Cornerstone balance (the "zeitgeist").
  5. The balance decides which factions form and which grow. Completing a Cornerstone gives an ability but radicalizes the opposite faction (+2 Fervor since Oct 2024).
- Technology choices are therefore never neutral.
- The 2/3 rule for Rule laws builds in a structural check on authoritarian drift. An authoritarian Steward needs either a broad coalition or prior groundwork with Propaganda/Rule laws (see Q5).

### Gaps
- No source gave per-vote relation deltas, a full law list with Cornerstone tags, or the exact Cornerstone-progress thresholds for enacting a Cornerstone.
- The tab list and "law research is free" are snippet-level only.

## 4. Faction demands: kinds, deadlines, and the consequences of meeting or ignoring them

### Takeaway
Demands mostly come through Council negotiation (promises in exchange for votes) and through faction "promise quests". They fall into four kinds:
- research or block ideas
- pass or repeal laws
- build or demolish structures
- act against rival factions

Heatstamp payments are an alternative currency. Promises are timed. Broken promises "significantly" worsen relations, and repeated failures trigger scripted "consequence arcs" (since patch 1.1.0). Ignored or unhappy factions gain Fervor.

### Cited Findings
**Kinds of promises and demands**
- Negotiation promises include research commitments, building or demolishing, passing specific laws, and "actions against rival factions." "You must convince them of your idea." [Guide] — [Gamepressure](https://www.gamepressure.com/frostpunk-2/council/zf115fb)
- You can improve standing by "offering them something. It can be heatstamps, promise to build some building or push the law of faction's ideology, promise to get rid of buildings and laws." [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453)
- "If you're lacking the necessary 51 votes, you can negotiate … This might include researching certain ideas, passing other laws they support, or building or destroying specific structures." [Snippet] — [Game Vault: Council](https://frostpunk-2.game-vault.net/wiki/Council) / [Digital Trends](https://www.digitaltrends.com/gaming/frostpunk-2-tips-beginners-guide/)

**Deadlines**
- "Most of these promises have a time limit, meaning the faction won't wait forever." A timer sits "on the upper left corner of the screen, right under the objectives." [Snippet] — [Digital Trends](https://www.digitaltrends.com/gaming/frostpunk-2-tips-beginners-guide/)
- Breach of Trust patch 1.6.1 (2 July 2026): "Quest to build barracks timeout increased." This confirms timed quests. [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)

**Consequences**
- Breaking promises: "your relations with the defrauded faction will worsen significantly." [Guide] — [Gamepressure](https://www.gamepressure.com/frostpunk-2/council/zf115fb)
- Ignoring factions: "when a faction feels ignored or becomes too unhappy, they can gain … Fervor." [Guide] — [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/)
- Good relations now give city bonuses: "Factions now provide proper bonuses to the city if the Steward maintains good relations with those factions." [Official] — [GOG DB 1.1.0](https://www.gogdb.org/product/1728870436/releasenotes)

**Patch 1.1.0 (21 Oct 2024) rules on promises and negotiation** [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
- No simultaneous quests to pass a policy and to repeal its opposite.
- No multiple promise quests on the same law (research, pass or repeal).
- You cannot promise a policy that is already on the next session's agenda.
- "Community Actions will be offered more often in Council negotiations."
- "Negotiations and Grant Agenda proposals will now be prioritising city needs next faction/community affinity."
- "Ending a Protest will be no longer negotiable if one is already collapsing due to Quell or Counterprotest."

**Patch 1.1.0 consequence arcs** [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes). New "Consequence Arcs" fire when the Steward does any of the following:
- keeps the generator off too long when fuel is available
- promotes a faction "only to Raise Funds afterwards"
- repeatedly fails "promise quests for a hostile Faction"
- condemns and promotes the same faction "in quick succession"
- fails "too many votes after granting an agenda to the same Faction"
- quells "a protest after negotiating with a Faction and making a promise"

**Steward actions toward factions**
- Action names confirmed in official notes: Promote, Condemn, Raise Funds, Grant Agenda, Requested Protests, Quell, Counterprotest, Round Up, Enforce Peace. [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
- Promote "drop[s] their Fervor by one point, stopping active riots." [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- "Make Promises" builds "bonus faction points to tax them later for even more heat stamps." This is a player strategy, not a stated rule. [Snippet] — [Steam guide: Optimal start, hardest difficulty](https://steamcommunity.com/sharedfiles/filedetails/?id=3337132852)

### Inferences
- Demands work as a currency system. Votes and calm are bought with future commitments (research, laws, buildings) or Heatstamps. Defaulting converts directly into worse relations and, over time, Fervor.
- The 1.1.0 consequence arcs show the designers penalizing cynical patterns: promote-then-tax, condemn/promote whiplash, and negotiate-then-crush. Faction trust has memory beyond single transactions.
- "Grant Agenda" hands a faction the next Council slot. Failing those votes repeatedly is itself punished, so granting an agenda you cannot pass is a trap.

### Gaps
- No source gave exact deadline lengths, numeric relation penalties, or the full relation scale. Only "Hostile", "Favorable" and "Devoted" are attested: [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes); [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/).
- The effects of Condemn, Raise Funds and "Requested Protests" are attested by name only. Their mechanics are unverified.

## 5. Unrest escalation: forms, thresholds, triggers, and suppression and its costs

### Takeaway
Unrest is driven by two variables:
- **Fervor** (0–3): how intense a faction is.
- **Relations**: which direction that intensity points.

High Fervor with good relations produces rallies. High Fervor with poor relations produces protests (Fervor 1), riots (Fervor 2) and civil war or "Faction War" (Fervor 3). City-wide Tension and Trust in the Steward sit above this. Losing Trust or maxing Tension can end the run. Endgame resolutions include banishment, reconciliation, enforced order, relocation to enclaves and, in Utopia Builder, faction dissolution. Suppression is possible through Guard Squads, prisons (round-ups) and authoritarian laws, but it costs Trust or Tension and provokes harder backlash. The Steward can also ease Fervor without force by promoting, funding or appeasing a faction, or by sending its members back to their communities.

### Cited Findings
**Escalation tiers**
- The three Fervor tiers [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/):
  - "1 Fervor: Triggers protests"
  - "2 Fervor: Starts riots"
  - "3 Fervor: Civil war"
- Riots need both conditions: "When a Faction has high Fervor and poor relations with you, they'll riot." [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- In story mode, "Riots can't trigger in Story Mode until the third chapter." [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- Rallies are the mirror image: "high Fervor, but the Faction is on good terms with you." They "increase Tension with other Factions and shouldn't last long." [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/). Factions with high or low relations "organize rallies or protests respectively." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Per-tier detail [Snippet] — [TheGamer: Fervor guide](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/) / [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/):
  - Fervor shows as red diamonds above the faction icon.
  - Level 1 protests "peacefully shut down districts" and end peacefully if you negotiate.
  - Level 2 protests "turn violent, injuring or killing bystanders" and stop only "if their demands are met or the riot is forced to shut down."
  - Level 3 left long enough leads to "open rebellion with riots escalating into battles between factions in the streets."

**Effects on districts**
- "Protests will render districts useless and can be very dangerous for City economy." [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453)
- Patch 1.0.5 (4 Oct 2024): "Districts will no longer remain blocked after the Protest has been resolved through increased relations with a protesting Faction." [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)

**Trust and Tension (city-level)** [Snippet] — [Game Vault: Trust](https://frostpunk-2.game-vault.net/wiki/Trust); [Twinfinite](https://twinfinite.net/guides/frostpunk-2-tension-explained-how-to-decrease-tension-what-it-does/); [NoobFeed](https://www.noobfeed.com/articles/frostpunk-2-all-problems,-trust-&-tension-and-how-to-solve-them)
- Tension rises from loss of Trust, failed Council votes, unpopular laws still in force, resource scarcity, and high Disease, Hunger, Cold, Squalor and Crime.
- Trust runs from 0 to 100 and can go negative. Its labels are Revered, Respected, Accepted, Tolerated (default) and Despised.
- Trust at 0, or Tension at maximum, risks removal from power (game over).
- Named Tension levels include "Severe" and "Catastrophic". [Guide] — [GameRant: Chapter 5](https://gamerant.com/frostpunk-2-banish-seek-reconciliation-enforce-order-decisions/)

**Story finale (Chapter 5)** [Guide] — [GameRant](https://gamerant.com/frostpunk-2-banish-seek-reconciliation-enforce-order-decisions/)
- Trigger: "one of the two factions is completely radicalized." It escalates through "protests, taking hostages, and launching riots", and Tension reaches Catastrophic.
- **Banish:** drops Tension from Catastrophic to Severe. You must explore the Frostland for a settlement site and supply "fuel, shelter, food, and materials."
- **Seek Reconciliation:** GameRant calls it "the best ending." It requires:
  - negotiating with each faction
  - repealing extreme laws such as "Sterilization or Human Experimentation"
  - deploying "about 40–60 guards" to end district protests
  - passing Peace Accords
- **Enforce Order:** GameRant calls it "the worst ending." It requires:
  - passing Captain's Authority with a two-thirds majority, after prerequisite Rule or Propaganda laws
  - keeping at least 45 spare guards
  - building two isolation districts with watchtowers
  - or, as an alternative, a coup with a 200-guard army

**Utopia Builder civil war, Faction War, relocation and banishment** [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes); [mp1st: Hotfix 1.5.2](https://mp1st.com/title-updates-and-patches/frostpunk-2-hotfix-1-5-2-patch-1-000-011)
- Patch 1.1.0 (Oct 2024):
  - "Story Arcs and other events are now properly unlocked after finishing a Civil War in Utopia Builder."
  - "Enclaves and Watchtowers built in them cannot be demolished or deactivated after the relocation of Faction has been completed."
  - "Factions will no longer drop their relations from Devoted to Hostile if certain conditions are met."
- Hotfix 1.5.2 (17 Dec 2025) [Snippet]:
  - prevents Faction Wars during Plague Events
  - fixes "factions not being fully dissolved after Faction War"
  - prevents "Proteans from returning after being banished from the city"

**Suppression tools and their costs**
- Guard Squads can "quell" protests, but "Quelling the protests too often will lead to more severe actions from factions." [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453)
- Prisons and "Round Up Faction Members": "guards will arrest Faction members over a few weeks, lowering Fervor but raising Tension." [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- GameRant on prisons [Guide] — [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/):
  - Round-ups are the "Largest Reduction" in Fervor.
  - They need workforce for guards and create a prisoner group with its own needs.
  - "Isolation Prisons" "only slightly reduce Trust."
  - "Punitive Prisons" "increase Tension at a constant rate."
- Patch 1.1.0 prison rules [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes):
  - "Detainees will return to the society after serving out their sentence."
  - Detainees "are no longer able to express their feelings about the City's situation."
  - "Enforce Peace ability can no longer be used when Prisons are disabled."
  - "Fixed Round Up ability consequences appearing too late."
- An active prison can "round up all protestors", but "you will lose a significant amount of Trust if you abuse this power too much." [Snippet] — [TheGamer: Fervor guide](https://www.thegamer.com/frostpunk-2-how-to-deradicalize-factions/)

**Non-coercive Fervor reducers**
- Project funding: "Large amounts of Heatstamps"; quick but temporary. [Guide] — [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/)
- Improving relations: a small, continuous reduction. [Guide] — [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/)
- Promote: −1 Fervor, which stops active riots. [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- Appeasing laws, for example Family Apprenticeship for the Pilgrims. [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- Meeting basic needs (heat, food, health) to lower tension. [Snippet] — [Twinfinite](https://twinfinite.net/guides/frostpunk-2-tension-explained-how-to-decrease-tension-what-it-does/)

**Opting out and DLC variants**
- Serenity Mode (patch 1.3, May 2025) removes the Fervor system: "an easier start, mild weather, abundant resources, shorter whiteouts and no faction wars." A fix addressed it "not using proper fervor setup, so Faction Wars could occur." [Official, via press] — [GamingBolt](https://gamingbolt.com/frostpunk-2-update-adds-new-sandbox-map-overhauls-heating-serenity-mode-and-more)
- Breach of Trust (23 June 2026):
  - A recurring "Vote of Trust" referendum ends the run if citizen confidence in the "First Citizen" falls "below threshold — through mismanaged crises, unpopular laws, or failed diplomacy with the colony of Aurora." [Guide] — [TechTimes](https://www.techtimes.com/articles/318912/20260623/frostpunk-2-breach-trust-launches-volcanoes-new-city-vote-that-can-end-your-rule.htm)
  - On the conquest path, "a new Resistance mechanic … with ongoing citizen unrest, sabotage and violence interrupting your economy." [Guide] — [CogConnected](https://cogconnected.com/review/frostpunk-2-breach-of-trust-review/)
  - Patch 1.6.1 (2 July 2026) [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes):
    - "Enforce Military Zone - weapon cost decreased from 75 to 50. Force Takeover - weapon cost decreased from 200 to 120."
    - "Balanced election voting weights."
    - Fixed losing "despite winning the vote of trust" on the Conquer Aurora path.

### Inferences
- The escalation ladder is a 2-D state:
  - **Fervor** sets how strongly a faction acts.
  - **Relations** set the direction: rally or protest/riot.
  - **City-wide Tension and Trust** set whether the Steward survives.
- Suppression trades one meter for another. Round-ups lower Fervor but raise Tension or cost Trust. Overused quelling escalates factions. Negotiating and then crushing triggers a consequence arc.
- Story mode's "best" and "worst" endings, as GameRant labels them, map onto reconciliation vs. authoritarian enforcement. The game's framing rewards de-escalation.
- Enclaves, "relocation of Faction" and Chapter 5's "isolation districts with watchtowers" probably refer to the same segregation mechanic. No source states this directly.

### Gaps
- No exact Tension or Trust thresholds per level, and no time-at-Fervor-3 needed to trigger civil war.
- No exact definitions of Quell, Counterprotest, Enforce Peace or Requested Protests.
- The Trust and Tension details are snippet-level. The Game Vault and Twinfinite pages were blocked.
- Breach of Trust's Vote of Trust threshold, election mechanics and Resistance triggers are not detailed in any accessible source.

## 6. Faction-specific buildings and hubs, and how city space relates to faction power

### Takeaway
In the base game, factions mainly express themselves spatially through ideologically flavoured variants of shared buildings (for example watchtower variants), through protests that shut down districts, and through relocation of a faction into Enclaves. Since patch 1.3 (May 2025), each community and faction can occupy its own district. Fractured Utopias (Dec 2025) added true faction architecture to Utopia Builder: one Hub and one housing-district variant per faction, unlocked through each faction's Utopia tree.

### Cited Findings
- Faction-specific variants of shared buildings: Surveillance Watchtowers (Stalwarts), Patrol Watchtowers (Pilgrims) and basic Watchtowers (New Londoners, Frostlanders). [Snippet] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453) / [Game Vault: Idea Tree](https://frostpunk-2.game-vault.net/wiki/Idea_Tree)
- Logistics Bay: the Automated variant (Progress-side backers) vs. the Vanguard variant (Adaptation-side backers). [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-best-ideas-research-first/)
- Protests block districts. Patch 1.0.5 made blocked districts reopen when relations resolve the protest. [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes); [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453)
- Enclaves and their Watchtowers become permanent after "the relocation of Faction has been completed." Enclaves were also restricted in UB colonies. [Official] — [GOG DB 1.1.0](https://www.gogdb.org/product/1728870436/releasenotes)
- Patch 1.3: "Every Community and Faction can now occupy an individual district." [Official, via press] — [GamingBolt](https://gamingbolt.com/frostpunk-2-update-adds-new-sandbox-map-overhauls-heating-serenity-mode-and-more)
- Fractured Utopias content [Official] — [11 bit studios](https://11bitstudios.com/frostpunk-2s-first-dlc-reforges-the-utopia-builder-mode/):
  - "8 unique faction hubs (one per faction)"
  - "8 faction-specific housing district variants"
  - "12 unique unlocks per faction (laws, new HUBs, abilities, etc.)"
  - Release on 8 Dec 2025 is also confirmed by [Gematsu](https://www.gematsu.com/2025/12/frostpunk-2-dlc-fractured-utopias-now-available).
- Faction hubs react to Tension: hotfix 1.5.2 fixed "Proteans Hub Windows emissives during high Tension." [Snippet] — [mp1st](https://mp1st.com/title-updates-and-patches/frostpunk-2-hotfix-1-5-2-patch-1-000-011)
- Fractured Utopias faction abilities and units named in patch 1.5.4 [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes):
  - Bohemians' "Wine and Dine" ability, tied to "Troupes"
  - "Organise Filtration Posts", which uses Guard Squads
  - "IEC sites can no longer be given to the Herders." This suggests Frostland sites can be assigned to groups.
- Breach of Trust adds Barracks, soldiers and Heavy Weaponry for the conquest route, and Fishery Hubs via negotiation with Aurora. [Guide] — [Whisper of the House](https://www.whisperofthehouse.com/frostpunk-2-breach-of-trust)

### Inferences
- Space is a political resource. Protests take districts offline, enclaves physically segregate factions, and post-1.3 districts can be tied to a single group.
- With Fractured Utopias, building a faction's Hub or housing variant is itself a vote for that faction's future.
- One finding cuts against the idea that pre-DLC factions had dedicated buildings: Fractured Utopias was marketed as adding faction hubs. A press headline called it the DLC that "Finally Adds True Faction Play" ([FinalBoss](https://finalboss.io/frostpunk-2s-first-dlc-fractured-utopias-finally-adds), opinion).

### Gaps
- No source describes what each Fractured Utopias Hub does.
- No source quantifies how district ownership affects faction size or Council seats.
- Whether story mode has faction-dedicated buildings beyond variants and enclaves is unconfirmed.

## 7. Systemic interactions, polarization dynamics, and patch/DLC timeline

### Takeaway
The system is built to polarize. The second faction is the exact opposite of the first. Completing a Cornerstone radicalizes the opposite faction. Rallies of a favoured faction raise Tension with the others. Every idea or law pleases some groups by displeasing others. Fractured Utopias makes this explicit: the only permanent end to Tension is to enact one faction's Utopia and silence dissent. Breach of Trust shifts pressure from faction management to a recurring Vote of Trust and occupation resistance.

### Cited Findings
**Polarization mechanics**
- Opposite-faction emergence in Utopia Builder: the second faction is "always the faction with the exact opposite Cornerstones." [Guide] — [TheGamer](https://www.thegamer.com/frostpunk-2-complete-faction-guide/)
- Cornerstone backlash: +2 Fervor to the opposing faction (since 1.1.0). [Official] — [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
- Rallies "increase Tension with other Factions." [Guide] — [ScreenRant](https://screenrant.com/frostpunk-2-how-to-stop-faction-riots/)
- "Adopting a faction's idea may upset other factions and communities." [Guide] — [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- "Balancing faction relations will be one of the main challenges of your playthrough and usually it's pretty hard to please everyone." [Guide] — [Steam Beginners Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3332925453)
- Community-route deradicalization damages relations with both parties. [Guide] — [GameRant](https://gamerant.com/frostpunk-2-deradicalize-factions-guide-tips/)
- Consequence arcs punish inconsistent treatment of factions: promote/condemn whiplash, promote-then-tax, negotiate-then-quell. [Official] — [GOG DB 1.1.0](https://www.gogdb.org/product/1728870436/releasenotes)

**Fractured Utopias framing**
- "Each faction in Frostpunk 2 envisions a future, but every vision meets resistance." Enacting a fully unlocked Utopia promises "to resolve all Tension… permanently." [Official] — [11 bit studios](https://11bitstudios.com/frostpunk-2s-first-dlc-reforges-the-utopia-builder-mode/)
- "The only way to permanently resolve the city's political tension is to bind the populace to a single faction's Utopia Tree, thereby silencing all opposing dissent." [Snippet] — [dlcompare](https://www.dlcompare.com/gaming-news/frostpunk-2-expansion-ideological-conflict-in-the-frostland)

**Breach of Trust framing**
- TechTimes says the Vote of Trust makes players "continuously earn their governing mandate" rather than manage factional resistance. The moral core is "trust or force, unity or control." Aurora stances are "peaceful trade, forcible extortion, or outright conquest." [Guide] — [TechTimes](https://www.techtimes.com/articles/318912/20260623/frostpunk-2-breach-trust-launches-volcanoes-new-city-vote-that-can-end-your-rule.htm)

#### Patch/DLC timeline relevant to politics
- **2024-09-20:** PC launch. [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- **1.0.5 (2024-10-04):** districts unblock when a protest is resolved via relations. [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
- **1.1.0 (2024-10-21):** [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
  - Cornerstone enactment gives +2 Fervor to the opposing faction.
  - Promise-quest constraints.
  - Consequence Arcs.
  - Detainees now return to society after their sentence.
  - Enforce Peace requires prisons.
  - UB Civil War and Enclave fixes.
  - Good-relation faction bonuses fixed.
- **1.3 (May 2025):** [GamingBolt](https://gamingbolt.com/frostpunk-2-update-adds-new-sandbox-map-overhauls-heating-serenity-mode-and-more)
  - Serenity Mode (no Fervor, no Faction Wars).
  - Heating overhaul (laws and research re-pointed to Heat Levels).
  - One new law and five reworked laws.
  - Individual districts per community or faction.
- **2025-09-18:** PS5 / Xbox Series release. [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2)
- **2025-12-08:** Fractured Utopias DLC adds faction Utopia trees, 8 hubs, 8 housing variants, 100+ events, the Tales "Doomsayers" and "Plague", and one map. [11 bit studios](https://11bitstudios.com/frostpunk-2s-first-dlc-reforges-the-utopia-builder-mode/). A search-result summary dated it "December 2024"; that is contradicted by 11 bit, [Gematsu](https://www.gematsu.com/2025/12/frostpunk-2-dlc-fractured-utopias-now-available) and [Wikipedia](https://en.wikipedia.org/wiki/Frostpunk_2).
- **1.5.2 hotfix (2025-12-17):** no Faction Wars during Plague events; full faction dissolution after Faction War; banished Proteans no longer return. [mp1st](https://mp1st.com/title-updates-and-patches/frostpunk-2-hotfix-1-5-2-patch-1-000-011)
- **1.5.4 (2026-02-18):** crime and justice policies need a built Council before research; Fractured Utopias ability and law fixes (Martial Law, Bohemians, Herders). [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
- **1.6 / Breach of Trust (2026-06-23):** New Edinburgh and the Aurora colony, Vote of Trust, five new communities and factions, Resistance, elections. [TechTimes](https://www.techtimes.com/articles/318912/20260623/frostpunk-2-breach-trust-launches-volcanoes-new-city-vote-that-can-end-your-rule.htm); [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
  - A 2025 headline said the "Aurora DLC" was delayed to 2026. [GamingBolt](https://gamingbolt.com/frostpunk-2s-aurora-dlc-delayed-to-2026-more-free-content-updates-coming)
- **1.6.1 (2026-07-02):** Resistance weapon-cost cuts, election weight balancing, Vote of Trust loss bug fixed. [GOG DB](https://www.gogdb.org/product/1728870436/releasenotes)
  - GOG DB writes the date as "02-07-2026". Version 1.6 is dated 23-06-2026, so this is 2 July. A search summary misread it as 7 Feb.

### Inferences
- The design loop is player choices → Cornerstone drift → opposite factions → Fervor → unrest. This means the Steward's ideological consistency is what creates the opposition.
- Fractured Utopias makes the authoritarian "end of politics" (one Utopia) an explicit, rewarded win path. The base story labels enforced order as the worst ending, which is a notable design tension worth discussing.
- "Aurora DLC" is likely an earlier working name for Breach of Trust, since it is set around the Aurora colony.

### Gaps
- No patches or DLC after 1.6.1 (July 2026) were found up to Oct 2026, so the current state is assumed to be 1.6.1 plus later hotfixes, if any.
- No developer diary text explaining the design intent of the axes or polarization was retrieved. Steam news for app 1601580 and official YouTube videos were not reached within the research budget.
- Patch 1.2 contents (if any) could not be checked against the politics systems.
