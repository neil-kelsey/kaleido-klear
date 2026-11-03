# What makes a Kaleido Klear level good

Notes from levels that are worth keeping, and from Spare key, which is not. Use this before building another level.

The generator rules (fill every cell, no empty space) make the boring squares that got deleted. Handmade levels can leave space. The circle of thrive is an 18×18 ring with an empty middle, and that empty middle is the point.

## How a move actually works

A piece slides as one solid shape until it hits something. It cannot stop in an open gap.

Only two moves change the board:

- **Leave.** The piece matches the color that edge wants right now, and it is removed.
- **Mix.** It slides into a different primary (red, yellow, or blue) and the two become one piece. Red + yellow = orange, yellow + blue = green, red + blue = purple. A mixed color cannot mix again. The same color cannot mix.

Anything else costs a life and the piece goes back to where it started: bumping a piece you cannot mix with, or leaving through an edge that wants a different color. That is a slap on the wrist, not a wrong path. A wrong path is a move the game accepts, after which the level can never be finished.

The level is finished only when every piece is gone. A mixed piece with no edge that wants it, and nothing left to mix with, is stuck forever.

## Levels that work

### The circle of thrive

A ring of small L shapes on a big board, with a hole in the middle. You can tell what it is before you touch it. The pieces are all primaries, and the edges ask for colors that are not on the board yet: purple on the left, green twice on the top, then orange and purple taking turns on the right. You are mixing as you go around the ring, not walking a single file of blocks off the nearest edge.

### Sea and O

Two rows of chunky blobs that mesh, tooth against tooth. The puzzle is the picture of those pieces sitting in each other. The edges are sequences (green then orange, a purple, then orange / purple / green / purple), so which blob leaves, and which edge it leaves from, matters. The joy is seeing the interlocking shapes, not a clear corridor.

### choose wisely

The board itself is simple: mostly red, with one blue and one yellow in the middle. Every edge looks like a place to dump reds. Each sequence hides one special color partway along (a purple, an orange, or a yellow). Spend the blue or the yellow on the wrong edge, or mix them into the wrong color, and that hidden step can never be satisfied. Several directions are legal. Most of them end the level.

### Antibiotics

A full 8×8 of L shapes, and only the top edge is open. That edge asks for purple, then green, then purple, then green, and so on, and finishes on a single red. The piece you actually need is usually buried. You have to send other pieces off first. Those swipes are not the move that wins. They are the moves you have to make so that the winning move becomes possible.

## Spare key, and why it scored 2/10

The cottage shape is worth keeping. The play is not.

The green chimney has a clear run at the green edge. The purple foundation has a clear run at the left edge. That is two of the five pieces gone on the first swipe, and neither swipe sets anything up. The only real mistake is sending the big roof yellow off the right, which spends the yellow you needed for the orange roof. One trap, and an obvious path around it, is not a puzzle.

It stays in the set, marked Easy.

## Checklist for the next one

- The silhouette should be recognizable: a ring, a gem, a house, a flower. Empty space around and inside it is fine.
- The pieces should read as parts of that shape, and ideally sit in each other the way Sea and O does.
- Nothing should be able to leave on the first swipe. If a piece already matches an open edge and the lane is clear, the level has not started yet.
- The first move that matters should not be the piece that scores. It should move something aside, or mix two pieces, so that a later mix becomes reachable. Antibiotics is the model: a move you do not need for its own sake.
- There should be at least three accepted moves that make the level impossible, the way choose wisely does. Three different pieces, or three different directions, not one bait with two ways to describe it.
- A life-loss bounce is not one of those three. The game has to accept the move.
- Do not build a parking spot. A piece that needs to "wait over there" has to mix into something, or leave.

Length is the piece count. Every mix and every exit removes one piece, so five pieces is a five-move level no matter how the shape is dressed. A hard level needs more pieces, and the later ones have to be locked behind the earlier ones. Three copies of the same latch, solvable in any order, is still one idea.

## Bleeding heart, and why it should work

An 11×9 heart of 17 interlocking pieces, mostly primaries, with the cleft at the top and the tip at the bottom. Only the top edge is open, the way it is in Antibiotics. It asks for orange, purple ×2, green ×2, blue ×3, orange ×2, purple, blue, and then the two reds at the tip.

- Nothing can leave on the first swipe. The edge wants orange, and the only orange is buried in the middle of the heart. So the first moves are mixes.
- Seventeen pieces is seventeen moves, and nearly every mix is a choice. Most primaries touch two different partners, and only one pairing keeps the colour count right for the sequence. The first position has 23 accepted moves, and 17 of them (on 11 different pieces) make the level impossible. After that, every position on the main line has only one or two moves that still win, against 3 to 13 accepted moves that lose. Across the main line, that is 98 accepted dead-end moves.
- The three blues and the final reds are bookkeeping you can't skip. Spend one blue in a purple or green mix and the B3 step can never be finished. Spend a red, and the tip can't close the level.
- Pieces leave in the order the sequence asks for, so the outer lobes have to clear in the right order to open lanes for the buried centre pieces.

Where it may fall short: the eight-step sequence is long to read, and part of the difficulty is keeping count. The colour assignment came from a solver-guided search over this hand-drawn heart, not from a single idea built by hand.

## Good vs bad: lessons from Bleeding heart and Yellow Core

Measured with a full state-graph BFS (same move rules as `LevelSolver`/`PuzzleSim`: only exits and merges are accepted moves, so every solution is exactly `pieces` moves long). A **trap** is an accepted move from a still-solvable state into a state with no solution.

| Metric | Yellow core (6x6, 12 pcs) | Bleeding heart (11x9, 17 pcs) | Pansy (8x8, 14 pcs) |
|---|---|---|---|
| Reachable states / solvable states | 2380 / 250 | 476 / 39 | 10183 / 331 |
| Distinct solutions (all optimal) | 1,575,968 | 2,432 | 280,799,136 |
| First move: accepted / traps | 33 / 12 | 23 / 17 | 42 / 22 |
| Trap edges out of solvable states | 1,874 | 292 | 2,122 |
| Avg accepted moves / avg winning moves per solvable state | 12.4 / 4.9 | 10.8 / 3.1 | 14.3 / 7.9 |
| Solvable states with an exit available | 207 | 31 | 311 |
| …where only one exit was possible (forced goal step) | 102 (49%) | 27 (87%) | 104 (33%) |
| …where a legal exit is a trap (wrong candidate) | 21 (10%) | **0 (0%)** | 68 (22%) |
| Random-legal-move win chance | 0.02% | ~0% | 0.03% |

**Why Bleeding heart is boring despite many first-move traps:** the difficulty is all in three opening merges; after that, 87% of goal steps offer exactly one legal exit and *no* goal step ever offers a wrong exit. The goal asks for orange and there is exactly one orange, two purples and exactly two exist, and so on. Supply equals demand colour-for-colour, so reading the goal tells you the answer. Its traps are just "don't make a mix you were never asked for", which a player avoids by not merging randomly.

**Why Yellow core is good:** the yellows (the colour you need for both green and orange) are buried in the centre, ringed by blue. Blues are surplus: there are more blues than the blue goal needs, so some must be spent making purple, and *which* blue goes where matters. Green is easy (yellow touches blue everywhere), but orange needs a yellow to travel out to a red corner without touching blue on the way, so you must clear blues out of the way first, usually by turning them into purples for the top goal. Wrong-candidate exits exist (10% of goal steps).

### Rules

1. **Surplus / decoys.** For each goal colour, give the board more candidate pieces than the goal needs (or several ways to mix it), so that choosing *which* piece satisfies the goal is a real decision. Supply == demand per colour ⇒ forced play.
2. **Bury the key colour.** Put the scarce colour the goals depend on in the middle, surrounded by a colour that spoils it on contact (yellow ringed by blue: any accidental touch turns it green).
3. **Require intermediate mixes.** Make the player spend blockers by mixing them into something a goal *does* want (purples), so clearing a path and scoring are the same action.
4. **Measure, don't guess.** Before shipping, report: trap edges, first-move traps vs winners, % goal steps with a wrong-but-legal exit (aim ≥ 15%), % forced goal steps (aim ≤ 50%), avg winning branch. A level with 0% wrong-exit steps is easy/medium however many opening traps it has.
5. **Plausible-but-wrong first moves.** Count first moves that look productive (merge into a colour that appears in a goal, or an exit of a goal colour) but are traps. These, not random bad merges, are what make a level feel clever.
6. Stored `difficulty_tier` overrides `LevelDifficulty.rate()` (1 easy, 2 medium, 3 hard, 4 very hard, 5 extreme); set it by hand from these numbers.

### Scarab (very hard, Dewfall sort 740) vs Pansy

Scarab (8x8, 17 pieces, min 17 moves, tier 4) is a symmetric blue/yellow beetle. Goals: top `Y1 > B1 > Y1 > B1 > G1 > Y2 > B2`, bottom `G2 > Y2 > B1`.

| Metric | Pansy (hard) | Scarab (very hard) |
|---|---|---|
| Reachable / solvable states | 10183 / 331 (3.3%) | 18381 / 240 (1.3%) |
| Distinct solutions | 280,799,136 | 60,632 |
| First move: accepted / traps | 42 / 22 | 34 / 22 |
| Trap edges out of solvable states | 2,122 | 3,354 |
| Avg accepted / winning moves per solvable state | 14.3 / 7.9 | 17.0 / 2.9 |
| Goal steps with an exit / single-option / wrong-but-legal exit | 311 / 104 / 68 (22%) | 225 / 85 / 64 (28%) |
| Random-legal-move win chance | 0.03% | <0.005% |

What changed: both blue and yellow are surplus (each is needed pure on the top goal *and* as an ingredient of the three required greens), the greens are a required mix whose yellows sit in the wing interior behind blue, and the two goals interleave (the top wants a green mid-sequence, the bottom opens with two greens), so the order in which you spend yellows matters across both edges, not just "keep yellows pure".

## What made Scarab work

Neil's playtest: **visuals 8–9/10, difficulty 8–9/10, "hit the mark perfectly"** (Pansy was visuals 8, difficulty 5.5–6). The formula, now reused for the whole *Nebula Menagerie* chapter (Dewfall, `UI_GROUP_NEBULA_MENAGERIE`):

1. **A creature or object you can name at a glance.** Mirror-symmetric, ~16–17 pieces on 8x8, every piece a meaningful part (head, wing, claw, tentacle). Pick subjects with a strong silhouette: abstract "flowers" read worse than a bug, an owl face or a crab. Check it in a real in-game render: piece outlines separate same-colour neighbours, but large same-colour areas still read as one blob.
2. **Two surplus primaries.** Each is needed pure on one goal *and* as the ingredient of a mix, so choosing which piece to spend is the puzzle.
3. **At least one required secondary whose ingredient is buried** (Scarab: three greens whose yellows sit inside the wings behind blue).
4. **Interlocking goal sequences on two edges.** A mix is wanted mid-sequence on one edge while the other edge opens with it, so the spending order matters across both.
5. **Targets** (measured with the full state-graph analysis): about 15–20 moves; ≤ ~3 winning moves per solvable state; < ~100k distinct solutions; > 25% of goal steps offering a wrong-but-legal exit; most first moves traps.

| Metric | Scarab | Night owl | Moon jelly | Rock crab |
|---|---|---|---|---|
| Pieces / min moves | 17 / 17 | 16 / 16 | 16 / 16 | 16 / 16 |
| Colours | B Y | R B Y | R B Y | R B Y |
| States / solvable | 18381 / 240 | 7089 / 86 | 11859 / 106 | 4965 / 114 |
| Distinct solutions | 60,632 | 2,352 | 13,824 | 40,704 |
| First moves / traps | 34 / 22 | 35 / 23 | 32 / 18 | 28 / 16 |
| Avg winning moves per solvable state | 2.92 | 2.88 | 2.93 | 2.44 |
| Goal steps with wrong-but-legal exit | 28% | 33% | 41% | 32% |

## Structural levels

Neil's geometric levels (towers, pyramids, stamps, ladders), measured the same way as the creature levels. Levels too big for a full search got 1,500 random-legal-move playouts instead: "mc" is the share of random players who win, and "branch" is the average number of accepted moves.

| Level | Size / pieces | States / solvable | Solutions | 1st moves / traps | Avg accepted / winning | Forced exits | Wrong-exit | Verdict |
|---|---|---|---|---|---|---|---|---|
| Block tower | 8x8 / 16 | 14392 / 3536 | 1.7e10 | 50 / 6 | 14.4 / 9.7 | 89% | 6% | Great silhouette, loose play: one edge, almost any order works |
| connected blocks 2 | 8x8 / 8 | 181 / 19 | 20 | 28 / 18 | 14.2 / 1.6 | 82% | 5% | Tight but short; supply equals demand |
| Pyramid scheme (10x8) | 10x8 / 8 | 376 / 120 | 37k | 32 / 16 | 10.4 / 5.6 | 29% | 14% | Best of the small ones: four short goal lists, real choices, too short |
| Stampers | 12x15 / 12 | 881 / 204 | 1.4e7 | 46 / 19 | 15.2 / 9.5 | 77% | 11% | Readable stamps; too many winning options |
| Step to the H | 12x12 / 9 | 354 / 186 | 2.9e5 | 32 / 9 | 7.6 / 5.4 | 66% | 0% | Easy: no wrong exits |
| Building blocks | 8x8 / 7 | 19 / 13 | 9 | 3 / 1 | 1.5 / 1.4 | 58% | 8% | Standard blocks that cannot mix; 67% random win |
| Step 2 | 16x16 / 17 | too big | – | – | branch 16.5 | – | – | mc 9.5%: big, but forgiving |
| Block party v2, Square doubles (+squared), Cut a path | 16–19 wide / 24–25 | too big | – | – | branch 21–26 | – | – | mc 0–0.3%: hard by size and bookkeeping (P7, P8, P5 runs) |
| Pyramid scheme (16x16), The striped Pyramid, Quatterns | 16x16 / 36–52 | too big | – | – | branch 40–45 | – | – | mc 0%: huge, not clever |
| Block shot | 8x8 / 64 | too big | – | – | branch 5 | – | – | 64 non-mixing singles, four 7–19-step lists: pure sequencing |

**What works:** a deliberate, symmetric shape that reads instantly (Block tower, Stampers, the small Pyramid scheme), and more than one open edge with short goal lists.

**What doesn't:**
- Single-edge towers whose goal accepts nearly any order (Block tower has 9.7 winning moves per position and only 6% wrong exits).
- Supply that exactly equals demand (connected blocks 2).
- Giants whose difficulty is long repeated counts like "P8" and a huge state space rather than decisions. The extreme giants feel long, not clever.
- Standard (non-mixing) blocks, which remove the colour decisions altogether.

### Ziggurat (Rift Geometry, last level; tier 4)

A stepped pyramid with the Scarab formula applied. The gold core and inner gold blocks are ringed by blue pillars, posts and a blue base; two red steps make the purples. Goals: top P1 > Y1 > B2, bottom G1 > B2 > Y1 > B1 > P1 > Y2 > B2.

| Metric | Ziggurat | Scarab |
|---|---|---|
| Pieces / min moves | 17 / 17 | 17 / 17 |
| States / solvable | 9555 / 508 | 18381 / 240 |
| Distinct solutions | 8,712,704 | 60,632 |
| First moves / traps | 26 / 16 | 34 / 22 |
| Avg accepted / winning per solvable state | 9.4 / 3.06 | 17.0 / 2.92 |
| Goal steps with wrong-but-legal exit | 44% | 28% |

The colours and goals came from a solver-guided climb over a hand-drawn, mirror-symmetric ziggurat. The colours are kept symmetric so the pattern stays deliberate. The large solution count comes mostly from the mirror (the left and right halves are interchangeable) and from independent moves that can be played in either order.
