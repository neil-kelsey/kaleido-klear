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
