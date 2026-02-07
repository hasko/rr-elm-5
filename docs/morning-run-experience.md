# Morning Run: Player Experience Walkthrough

A moment-by-moment account of what the player sees, does, and feels during the sawmill morning run.

---

## 1. Opening the Game

The player opens the game and sees a top-down view of the sawmill branch line. The track stretches east-west across the screen: a mainline with a single siding curving off to the south. The siding passes a small platform, then a team track area, and ends at a buffer stop. A tunnel portal at the east end is labeled "East Station." The western mainline fades off into the distance, unused.

Everything is still. No trains. The clock reads 06:00. The simulation is paused.

The player's eye is drawn to the siding -- the platform, the team track, the dead-end buffer. This is where the action will happen. The mainline is just a path to get there.

**What the player feels:** Curiosity. "Okay, a small railroad. Simple enough. What am I supposed to do?"

---

## 2. Building the Morning Consist

The player clicks the East Station tunnel portal (or a "Plan" button) and the consist planning screen appears. On the left side, three pieces of rolling stock are available:

- A locomotive (the switcher)
- A passenger coach (for the workers)
- A flatcar (for lumber)

On the right side, an empty consist slot. The player drags cars into the consist to arrange them.

**The puzzle begins here.** The player needs to think: "What order do I need these cars in when they arrive at the sawmill?"

A first-time player might try `[Flatcar] - [Coach] - [Loco]`, thinking the loco should push from the rear. But then they realize: the loco enters from the east, pushes west into the siding. The flatcar needs to end up deepest in the siding (at the team track, closest to the buffer stop), and the coach needs to be at the platform (between the turnout and the team track).

So the correct order, from east to west, is:

```
[Loco] === [Coach] === [Flatcar]
```

The loco leads from the east. The flatcar is at the west end. When the train pushes into the siding (moving west), the flatcar goes in first, the coach follows. The flatcar ends up deepest, the coach at the platform. Perfect.

The player sets the reverser to "Reverse" -- the train will push westward on its first move.

**What the player feels:** A small "aha" moment. The consist order isn't arbitrary -- it determines whether the switching move is even possible. This is the core insight of the puzzle.

---

## 3. Writing the Morning Program

The player opens the programmer panel. A blank list of orders. They need to choreograph every move.

**Order 1: SetSwitch turnout Reverse**

Before the train moves, the turnout needs to be set for the siding. The player selects "Set Switch" and picks the turnout, setting it to Reverse (diverging route). This is like a pre-flight checklist item. Miss it, and the train sails past on the mainline.

**Order 2: SetReverser Reverse**

The loco needs to push (move west). If the reverser was set during consist planning, this might feel redundant -- but it's explicit, and the program should be self-contained.

**Order 3: MoveTo Platform**

The big move. The train will push from the east tunnel, through the turnout, and into the siding until the coach is spotted at the platform. The player types (or selects) "Platform" as the destination.

**Order 4: WaitSeconds 60**

The workers get off the coach. Sixty seconds of game time. The player imagines tiny workers stepping onto the platform, stretching, heading to the sawmill.

**Order 5: MoveTo Team Track**

Push the flatcar further into the siding to spot it at the team track. The coach trails behind, moving past the platform.

**Order 6: Uncouple 1**

Detach the flatcar. Keep the loco and coach, leave the flatcar at the team track for loading during the day.

**Order 7: SetReverser Forward**

Now the loco will pull (move east), dragging the coach back out of the siding.

**Order 8: MoveTo East Station**

Pull the loco and coach back through the turnout and into the east tunnel. Gone. Job done.

**Order 9: SetSwitch turnout Normal**

Good housekeeping. Reset the turnout to the mainline position.

**What the player feels:** Satisfaction at the choreography. Nine orders, each one logical. The program reads like a little story. But also a hint of anxiety: "Did I get the order right? What if I forgot something?"

---

## 4. Hitting Play

The player presses Play. The clock starts ticking. 06:30 arrives.

The tunnel portal at the east end animates -- and the train appears. Three vehicles emerge one by one from the darkness: the locomotive first, then the coach, then the flatcar. They slide into view, already coupled, already moving.

The turnout clicks to the diverging position (Order 1 fires instantly). The reverser is set (Order 2, also instant). The train is pushing westward.

**What the player feels:** Excitement. "Here we go." The train is alive.

---

## 5. Train Moving: East Tunnel to Platform

The train accelerates smoothly out of the tunnel. The locomotive is at the east end, pushing. The flatcar leads, heading west.

The train reaches the turnout and takes the diverging route into the siding. The player watches the cars curve off the mainline one by one -- first the flatcar, then the coach, then the loco.

As the train approaches the platform, it begins to slow. The braking is visible -- the train decelerates gradually, not abruptly. The player can see the speed dropping.

The train eases to a stop with the coach perfectly spotted at the platform.

**Visual feedback:**
- The train's position updates smoothly, frame by frame
- Speed visibly decreases as the train brakes for the platform
- The train stops precisely at the marked spot

**What the player feels:** Relief. "It worked! The coach is at the platform." A small dopamine hit from watching the plan execute correctly.

---

## 6. At the Platform: The Wait

The program reaches WaitSeconds 60. The train sits still. The clock ticks. A timer or status indicator shows the wait counting down.

Sixty seconds of game time pass. (At 1x speed, this is sixty real seconds. At 4x speed, fifteen seconds. The player might want to speed up here.)

Nothing moves. The train is still. The sawmill is being served.

**What the player feels:** Impatience (at 1x speed) or calm anticipation (at higher speed). "Come on, let's go." This is the quiet beat between action sequences. It gives weight to the story -- workers are actually doing something -- but the player is eager for the next move.

---

## 7. Platform to Team Track

The wait ends. The train pushes further into the siding. The flatcar, still at the front, rolls past the platform and toward the team track. The coach follows.

The train slows again, braking smoothly, and stops with the flatcar at the team track.

**What the player feels:** Confidence building. "Two stops down, running like clockwork."

---

## 8. The Uncouple Step

The program reaches `Uncouple 1`. This is the critical switching move -- detach the flatcar, leave it at the team track.

**Current behavior:** The train stops. A status message appears: "Uncouple: not yet supported."

The train halts. The program cannot continue. The simulation is stuck.

**What the player feels:** Frustration, then understanding. This is an unfinished feature. The game can demonstrate movement, switching, and waiting -- but the actual switching puzzle (uncoupling and recoupling cars) isn't wired up yet.

**Is this right?** Yes, as an MVP stopping point. The error message is the "driver asking for instructions" pattern -- the driver encountered something they can't do and is reporting back. The player sees exactly what went wrong and where. But for the full puzzle experience, this is the feature that needs to come next. Without uncouple, the morning run can't complete. Without couple, the evening run can't retrieve the flatcar. These two operations are the heart of the switching puzzle.

---

## 9. What Completion Would Feel Like

If Uncouple were implemented, the rest of the morning run would play out like this:

**Uncouple 1** fires. The flatcar visually separates from the coach. A small gap appears between them. The flatcar stays put at the team track. The train (now just loco + coach) is free to move.

**SetReverser Forward** fires. The loco is now pulling east.

**MoveTo East Station**: The loco pulls the coach back up the siding, through the turnout, and into the east tunnel. The train shrinks into the tunnel portal and vanishes.

**SetSwitch turnout Normal**: The turnout clicks back to the mainline position. The siding is clear except for the lone flatcar sitting at the team track, waiting to be loaded with lumber.

**What the player would feel:** Deep satisfaction. The whole sequence -- nine orders, three stops, one uncouple -- played out exactly as planned. The flatcar is spotted. The workers are delivered. The loco and coach are safely back at East Station. The player watches the last car disappear into the tunnel and thinks: "I did that. I wrote that program. And it worked."

Then they look at the clock and think: "Now I need to write the evening run..."

---

## Summary of Player Emotions

| Moment | Feeling |
|--------|---------|
| Opening the game | Curiosity, survey the layout |
| Building the consist | Puzzling, "aha" when order clicks |
| Writing the program | Craftsmanship, mild anxiety |
| Hitting Play | Excitement, anticipation |
| Train moving | Satisfaction, watching the plan work |
| Platform wait | Impatience or calm (speed-dependent) |
| Uncouple attempt | Frustration (current), triumph (future) |
| Train departing | Deep satisfaction, pride |
| Looking ahead | Motivated to tackle the evening run |

---

## Open Design Questions

1. **Speed controls during wait**: Should the game auto-suggest speeding up during WaitSeconds? Or let the player discover the speed controls naturally?

2. **Visual feedback for uncouple**: When implemented, should the uncouple show an animation (cars separating with a small gap), play a sound (coupling clank), or both?

3. **Error presentation**: The "Uncouple: not yet supported" message is functional but dry. Should stopped trains show a more characterful message? ("Driver radios in: 'Boss, I don't know how to uncouple yet. What do I do?'")

4. **Platform activity**: During the WaitSeconds at the platform, should there be visual feedback of workers boarding/alighting? Or is the still pause enough to convey the story?

5. **Consist order hint**: If a new player gets the consist order wrong, when do they discover the mistake? At program-writing time? At execution time? Should there be an early warning, or is the failure itself the teaching moment?

---

## Wrong Solutions and How They Manifest

The best puzzles teach through failure. Each wrong solution below produces a distinct, visible consequence -- the player sees what went wrong, understands why, and internalizes a rule of railroad operations without being told. No tutorial popups needed. The railroad itself is the teacher.

---

### Mistake 1: Forgot to Set the Switch Before Moving

**What the player did:** Wrote the program starting with `SetReverser Reverse` and `MoveTo Platform` but forgot the `SetSwitch turnout Reverse` order at the top. The turnout is still set to Normal (mainline).

**What they see:** The train emerges from the east tunnel and pushes westward, picking up speed. It reaches the turnout -- and sails straight through. The train continues west along the mainline, past the siding entrance, heading toward the western edge of the map. The platform sits empty to the south. The siding is right there, but the train didn't take it.

The train keeps going. If there's a western boundary or the mainline simply continues off-screen, the train disappears into the distance. The program's `MoveTo Platform` order never completes because the train is on the wrong track entirely -- the platform is on the siding, and the train is on the mainline. The simulation may halt with an error ("Cannot reach destination: Platform is not on current route") or the train may simply keep moving until it runs out of track.

**When they realize the mistake:** Immediately, the moment the train passes the turnout without diverging. The visual is unmistakable -- the train goes straight where it should have turned. The player watches the siding entrance slide past and thinks: "No, no, no -- I forgot the switch!"

**What they learn:** Switches don't set themselves. Every route through a turnout must be explicitly commanded. This is the most fundamental lesson of the game: the railroad requires deliberate, step-by-step instructions. There are no automatic routes, no "the train knows where to go." You are the dispatcher. If you don't throw the switch, nobody will.

**Design note:** This is likely the single most common first-time mistake. The visual of the train sailing past the siding is dramatic and clear. It should feel like watching a car miss its highway exit -- you see it happening, you know it's wrong, but it's too late.

---

### Mistake 2: Wrong Consist Order

**What the player did:** Built the consist as `[Loco] === [Flatcar] === [Coach]` instead of the correct `[Loco] === [Coach] === [Flatcar]`. The flatcar is in the middle, the coach is at the west end.

**What they see:** The train pushes into the siding normally. Everything looks fine at first -- the turnout is set, the train curves into the siding. But when the `MoveTo Platform` order completes and the train stops, the player looks at what's spotted at the platform: it's the flatcar, not the coach. The coach is further down the siding, past the platform, closer to the team track.

The workers would have to walk along the track to reach the coach, or climb onto an empty flatcar. Neither makes sense. The program continues to `MoveTo TeamTrack`, pushing deeper, but now the coach ends up at the team track and the flatcar is somewhere in between. Nothing is where it should be. When `Uncouple 1` fires, it detaches the wrong car. The whole sequence unravels.

**When they realize the mistake:** At the first stop. The moment the train halts at the platform and the player sees the wrong car spotted there, they understand. "The flatcar is at the platform? That's not right. The coach should be there." They trace the problem back: the cars went in the order they were coupled, and the order was wrong from the start.

**What they learn:** Consist order isn't cosmetic -- it determines which car ends up where. In a dead-end siding, the first car in is the deepest car. The last car before the loco is the one closest to the turnout. Planning the consist is planning the entire switching move in reverse. This is the core insight of the puzzle, and getting it wrong once makes it click permanently.

**Design note:** This mistake is educational gold. The player has to mentally simulate the train entering the siding and reason about which end goes in first. Getting it wrong and seeing the result makes the spatial logic visceral rather than abstract.

---

### Mistake 3: Forgot to Set the Reverser

**What the player did:** Set up the consist correctly as `[Loco] === [Coach] === [Flatcar]` and wrote the program with `SetSwitch turnout Reverse` and `MoveTo Platform`. But they forgot the `SetReverser Reverse` order. The reverser defaults to Forward (or was left in Forward from a previous program).

**What they see:** The switch clicks to the diverging position. Then the train starts to move -- but in the wrong direction. Instead of pushing westward toward the siding, the locomotive pulls eastward, dragging the consist deeper into the east tunnel. The train moves away from the sawmill, retreating back the way it came.

If the east tunnel is a spawn point with an off-map destination, the train might simply vanish back into the tunnel. The `MoveTo Platform` order will fail -- the platform is to the west, and the train is heading east. The simulation halts. The siding sits empty. The switch is set for a train that never comes.

**When they realize the mistake:** Almost immediately. The train moves and the player sees it going the wrong way. "Wait -- it's going backward! I need it to push west, not pull east!" The motion is clearly in the opposite direction from what was intended. There's no ambiguity.

**What they learn:** The reverser controls which direction the locomotive moves, and it must be set deliberately. "Forward" and "Reverse" are relative to the locomotive's orientation, not to the map. If the loco faces east, Forward means east, Reverse means west. The player must think about which way the loco is pointing and which way the train needs to go. This is a real operational concept -- engineers always know which end of the loco is the "front."

---

### Mistake 4: Wrong MoveTo Order (Team Track Before Platform)

**What the player did:** Wrote the program with `MoveTo TeamTrack` as the first movement order, before `MoveTo Platform`. Their logic was: "I need the flatcar at the team track, so I'll move there first."

**What they see:** The train pushes deep into the siding. It passes the platform without stopping -- the coach flies past the platform mark, the train keeps pushing. It finally stops with the flatcar at the team track, but the coach has overshot the platform. It's somewhere between the platform and the team track, or right behind the flatcar.

Now the player is stuck. The workers can't board at the platform because the coach isn't there. If the player then tries to uncouple the flatcar and pull back to spot the coach at the platform, they might be able to recover -- but the original program didn't account for this. The sequence is broken. The player wrote a program that physically works (the train moved, nothing crashed) but logistically fails (cars aren't at the right spots).

**When they realize the mistake:** When the train stops at the team track and the player sees that the coach has passed the platform. "Oh -- the coach went past the platform! I should have stopped there first." The visual tells the story: the coach is in the wrong place because the train didn't stop early enough.

**What they learn:** Order of stops matters. In a dead-end siding, you must make stops in order from the turnout inward: platform first (it's closer to the turnout), then team track (deeper in). You can't skip ahead to the deep end and then come back, because pushing deeper moves everything deeper. The siding is a one-way funnel, and the program must respect the geography.

**Design note:** This mistake reveals the spatial constraint of dead-end sidings. The player learns to read the track layout and translate physical order into program order.

---

### Mistake 5: Forgot to Reset Switch After Entering Siding (Matters in Scenario 2)

**What the player did:** Omitted the `SetSwitch turnout Normal` order at the end of the morning program. The turnout is left in Reverse (diverging to the siding) after the train completes its work and returns to the east tunnel.

**What they see in Scenario 1:** Nothing bad happens. In the basic scenario, there is no mainline traffic. The switch sits in Reverse all day. Nobody cares. The flatcar is at the team track, the loco and coach are back at East Station. The puzzle is solved despite the sloppy housekeeping.

**What they see in Scenario 2:** Disaster. At 07:00, the passenger train enters from the west, heading east on the mainline. It reaches the turnout -- and the turnout is still set to Reverse. The passenger train diverts into the siding instead of continuing east on the mainline. It plows into the siding where the flatcar is parked at the team track. Collision. Simulation halts. Failure.

Or, if the passenger train enters from the east: it reaches the turnout from the east side, and depending on turnout behavior for trailing-point moves, the train may either force through or derail. Either way, the player's switching train is now blocking the siding, and the passenger train can't proceed. A timetable delay occurs.

**When they realize the mistake:** In Scenario 1, they might never realize it -- the puzzle still completes. The lesson comes in Scenario 2, when the passenger train hits the misaligned switch. The player thinks: "Why did the passenger train go into the siding? Oh -- I left the switch set to Reverse!" The consequence is dramatic and the cause is immediately traceable.

**What they learn:** Good operating practice matters even when it seems unnecessary. Resetting switches after use is not pedantic -- it protects against unexpected traffic. This is a real railroad principle: always leave the mainline clear. What seems like a "nice to have" in Scenario 1 becomes a hard requirement in Scenario 2. The game rewards disciplined operations.

---

### Mistake 6: Forgot to Set Switch Back Before Leaving the Siding

**What the player did:** After uncoupling the flatcar at the team track, they set the reverser to Forward and issued `MoveTo EastStation` -- but forgot to set the switch back to Reverse for the siding (or, more precisely, the switch is still set to Reverse from entry, which is actually correct for exiting the siding).

Let's consider the more realistic version: the player changed the switch to Normal mid-program (perhaps out of confusion, or trying to "clear the mainline" too early) and then tried to pull the loco and coach out of the siding. The switch is set to Normal (mainline), but the train is on the siding.

**What they see:** The loco and coach start to pull east, heading back toward the turnout. They reach the turnout from the siding side. The switch is set for the mainline (Normal) -- which means from the siding side, the route through the turnout is misaligned. The train reaches the turnout and cannot proceed. It's facing a switch set against it. The simulation halts with a routing error: the train's path through the turnout doesn't connect to the siding track.

The train sits at the turnout, stuck. The loco is running, the reverser is set, but the switch is blocking the exit. The coach is stranded halfway up the siding. Nothing moves.

**When they realize the mistake:** When the train stops at the turnout and won't go through. "Why isn't it moving? Oh -- the switch! It's set for the mainline but I'm on the siding. The train can't exit." The player traces the logic: to exit the siding, the turnout must be set to Reverse (which routes from the siding to the mainline). They set it to Normal too early, locking themselves in.

**What they learn:** The switch must be set correctly not just for entering the siding but for leaving it. Reverse isn't just "go into the siding" -- it's "connect the siding to the mainline." Normal means "the mainline goes straight through" -- which disconnects the siding. The player develops a mental model of how turnouts work from both directions. This is a genuine "aha" moment about turnout geometry.

**Design note:** This is a subtle but important lesson. Many players assume "Normal = default = good" and try to reset the switch as quickly as possible. Learning that they need the switch set to Reverse to exit the siding challenges that assumption and deepens their understanding of turnout routing.

---

### Summary: What Each Mistake Teaches

| Mistake | Core Lesson |
|---------|-------------|
| Forgot switch before moving | Switches must be set explicitly. Nothing is automatic. |
| Wrong consist order | Car order determines spotting positions. Plan backward from the end state. |
| Forgot reverser | The reverser controls direction. Know which way the loco faces. |
| Wrong MoveTo order | Geography constrains program order. Stop at closer spots first. |
| Forgot to reset switch (Scenario 2) | Good housekeeping prevents collisions. Leave the mainline clear. |
| Set switch wrong while still on siding | Turnouts connect tracks. Understand the geometry from both sides. |

---

## Scenario 2: Morning Run with Passenger Train Constraint

Scenario 2 is Scenario 1 (the morning lumber run) with one addition: a passenger train on the mainline. The player's switching operations are unchanged, but they must now be choreographed around a fixed timetable constraint. The mainline is no longer an empty highway -- it's shared infrastructure.

---

### The Passenger Train

- **Consist:** 1 locomotive + 2 passenger coaches
- **Eastbound run:** Departs from the west at 07:00, passes the sawmill turnout heading east toward East Station
- **Westbound return:** Departs from the east at 09:00, passes the sawmill turnout heading west
- **The locomotive is flipped for the return trip** (turned at a wye off-map), but the coaches stay in the same order
- **This train is immutable.** The player cannot control it, modify it, or delay it. It runs on the timetable, period. It is a fact of the world, like gravity.

The critical constraint: **the turnout must be set to Normal (mainline) before the passenger train passes through.** If the turnout is set to Reverse when the passenger train arrives, the passenger train will divert into the siding. At best, this causes a delay. At worst, it causes a collision with the flatcar parked at the team track.

---

### The New Timeline

```
06:00  Game starts. Clock is paused. Player plans.
06:30  Player's switching train departs East Station, heading west.
~06:35 Train enters siding, begins switching work.
06:55  DEADLINE: Turnout must be set to Normal before 07:00.
07:00  Passenger train passes eastbound on mainline.
       (Player's train should be safely inside the siding by now.)
07:00+ Player continues switching work inside the siding.
08:55  DEADLINE: Turnout must be Normal before 09:00.
09:00  Passenger train passes westbound on mainline (return trip).
09:00+ Player can resume any remaining mainline operations.
```

---

### Player Journey: Scenario 2, Moment by Moment

#### Phase 1: Reading the Timetable (06:00, Paused)

The player opens the game. Same layout as Scenario 1 -- but now there's a timetable panel visible, or a schedule overlay on the screen. It shows:

```
07:00  Passenger Express  WEST -> EAST  (mainline)
09:00  Passenger Express  EAST -> WEST  (mainline)
```

The player reads this and immediately understands: "I have mainline traffic. I need to be out of the way by 07:00."

They look at the clock: 06:00. Their switching train departs at 06:30. That gives them 30 minutes of game time (06:30 to 07:00) to get the switching train off the mainline and into the siding, and to reset the turnout to Normal.

**What the player feels:** A tightening of focus. Scenario 1 was leisurely -- no time pressure, work at your own pace. Scenario 2 has a deadline. "I need to be quick. Or at least, I need to not waste time."

---

#### Phase 2: Planning the Consist (06:00, Paused)

The consist is identical to Scenario 1: `[Loco] === [Coach] === [Flatcar]`. Nothing changes here. The passenger train doesn't affect car order.

But the player is already thinking ahead: "After I enter the siding, I need to set the switch back to Normal before 07:00. That means I need a SetSwitch order in my program at the right moment."

---

#### Phase 3: Writing the Program (06:00, Paused)

The player writes the morning program, but with a critical addition:

```
 1. SetSwitch turnout Reverse        -- Align for siding entry
 2. SetReverser Reverse              -- Push westward
 3. MoveTo Platform                  -- Push into siding, coach at platform
 4. SetSwitch turnout Normal         -- CLEAR THE MAINLINE for passenger train
 5. WaitSeconds 60                   -- Workers disembark
 6. MoveTo TeamTrack                 -- Push flatcar to team track
 7. Uncouple 1                       -- Detach flatcar
 8. SetReverser Forward              -- Prepare to pull east
 9. WaitUntil 09:05                  -- Wait for westbound passenger train to pass
10. SetSwitch turnout Reverse        -- Align turnout for siding exit
11. MoveTo EastStation               -- Pull coach back to tunnel
12. SetSwitch turnout Normal         -- Clear mainline (good housekeeping)
```

The key differences from Scenario 1:

- **Order 4 (new):** `SetSwitch turnout Normal` immediately after entering the siding. The entire train is inside the siding, clear of the turnout. The turnout is reset to Normal so the mainline is clear. This must happen before 07:00.
- **Order 9 (new):** `WaitUntil 09:05` -- the player cannot pull back onto the mainline while the passenger train is using it. The 09:00 westbound service must pass the turnout before the switching train can exit the siding. The player adds a 5-minute buffer for safety.
- **Order 10 (new):** `SetSwitch turnout Reverse` -- after the passenger train has passed at 09:00, the player resets the turnout to Reverse so the siding is reconnected and the switching train can exit.

**What the player feels:** The program is longer. More complex. The player is now juggling two concerns: the switching task (same as before) and the timetable constraint (new). They feel the tension between "do my work" and "stay out of the way." This is a real railroad operations feeling.

---

#### Phase 4: Hitting Play (06:00 -> 06:30)

The player presses Play. The clock ticks forward. At 06:30, the switching train emerges from the east tunnel, pushing westward. Same as Scenario 1.

But now the player is watching the clock. 06:30. 06:32. 06:35. The train reaches the turnout and curves into the siding. The turnout is Reverse. The train pushes along the siding toward the platform.

**What the player feels:** Urgency. "Come on, get into the siding. The passenger train is coming at 07:00."

---

#### Phase 5: Entering the Siding and Clearing the Mainline (06:35 - 06:45)

The train brakes and stops with the coach at the platform. Order 3 completes. Now Order 4 fires: `SetSwitch turnout Normal`. The turnout clicks from Reverse to Normal. The mainline is clear.

The player glances at the clock: 06:45. Fifteen minutes to spare before the 07:00 passenger train. The turnout is Normal. The switching train is safely inside the siding, completely off the mainline.

**What the player feels:** Relief. "Made it. The mainline is clear." A small exhale. The first deadline is met. The player didn't even cut it close -- but they felt the pressure anyway. That's good design.

---

#### Phase 6: Working in the Siding (06:45 - 07:00)

Order 5: `WaitSeconds 60`. Workers disembark at the platform. The clock ticks: 06:45... 06:46... 06:50...

Then, at 07:00, the passenger train appears. It enters from the west edge of the map -- a locomotive and two coaches, moving briskly eastbound on the mainline. The player watches it approach the turnout. The switch is Normal. The passenger train sails straight through on the mainline, never slowing, never deviating. It passes the siding entrance and continues east toward the tunnel portal, vanishing into the east tunnel. Gone.

The switching train sits motionless at the platform, inside the siding, untouched. The two trains were never in conflict. The turnout did its job.

**What the player feels:** A thrill. "There it goes! And I'm safely in the siding." Watching the passenger train blast through the turnout -- the same turnout the player's train used just minutes ago -- is a visceral demonstration of why the switch needed to be reset. The player set up the conditions for this moment to work, and seeing it play out is deeply satisfying.

---

#### Phase 7: Completing the Switching Work (07:00 - 08:00)

The wait ends. Order 6: `MoveTo TeamTrack`. The train pushes the flatcar deeper into the siding. Order 7: `Uncouple 1`. The flatcar detaches. Order 8: `SetReverser Forward`. The loco is ready to pull east.

But the player can't leave yet. The 09:00 westbound passenger train is coming. If the player pulls the loco and coach onto the mainline and the passenger train arrives, there could be a conflict. The program has `WaitUntil 09:05`.

**What the player feels:** Anticipation mixed with mild frustration. The switching work is done, but the train is stuck in the siding, waiting. The clock reads maybe 07:10 or 07:15. There's almost two hours to kill. "I finished the work but I can't leave. The passenger train has me trapped in here."

This is the new challenge of Scenario 2: time management. The player might reach for the speed controls -- crank up to 4x or 8x to fast-forward through the wait. The game should support this gracefully.

---

#### Phase 8: The Second Passenger Train (09:00)

At 09:00, the westbound passenger train appears from the east tunnel. It's the same train, returning: locomotive (now facing the other direction, turned at a wye off-map) and two coaches. It moves westward on the mainline, passing the siding turnout (still set to Normal), and disappears off the western edge.

The player watches it pass. "There it goes. Now I can leave."

**What the player feels:** Impatience resolving into action. "Finally! My window is open."

---

#### Phase 9: Exiting the Siding (09:05+)

The `WaitUntil 09:05` completes. Five minutes after the passenger train, just to be safe. Order 10: `SetSwitch turnout Reverse`. The turnout reconnects the siding to the mainline. Order 11: `MoveTo EastStation`. The loco pulls the coach east, through the turnout, and into the east tunnel. Order 12: `SetSwitch turnout Normal`. Housekeeping -- mainline clear.

The siding is empty except for the flatcar at the team track. The loco and coach are back at East Station. The turnout is Normal. The mainline is clear.

**What the player feels:** Accomplishment, with an edge. The puzzle was harder this time. The switching work was the same, but the scheduling was new. The player had to think about windows of time, not just sequences of moves. "I solved it, but it was tighter. What happens when there are more trains?"

---

### Scenario 2: The Mistakes That Hurt More

Everything from the "Wrong Solutions" section still applies, but Scenario 2 amplifies certain mistakes:

**Forgot to reset the switch after entering the siding (Mistake 5):** In Scenario 1, this was invisible. In Scenario 2, the 07:00 passenger train diverts into the siding and collides with the switching train. The consequence jumps from "sloppy but harmless" to "catastrophic." The player who got away with it in Scenario 1 gets punished in Scenario 2. This is excellent difficulty progression -- the same mistake, but higher stakes.

**Took too long entering the siding:** If the player's switching work is slow (long wait times, many moves before clearing the mainline), the 07:00 deadline approaches. The player watches the clock and the train simultaneously, willing the consist to move faster. If they don't clear the turnout in time -- collision. The time pressure transforms a relaxed switching exercise into a race.

**Forgot the WaitUntil before exiting:** If the player exits the siding at, say, 08:50, they pull onto the mainline just as the 09:00 westbound passenger train approaches. The two trains are now on the same track heading toward each other (or one is stationary while the other approaches). Collision or emergency stop. The player learns: "I can't just leave whenever I want. I have to check the timetable."

**Set the switch to Reverse too early for exit:** If the player sets the turnout to Reverse before the 09:00 passenger train passes, the westbound passenger train diverts into the siding. Same consequence as Mistake 5 but at a different time. The player learns that every switch change must be timed against the timetable.

---

### Scenario 2: New Design Questions

6. **Timetable visibility:** How prominently should the passenger train schedule be displayed? A persistent sidebar? Markers on a timeline? Warning indicators near the turnout?

7. **Collision handling:** When the passenger train hits a misaligned switch, what does the player see? An instant halt with an error overlay? An animation of the passenger train entering the siding? The severity of the visual feedback affects how seriously the player takes the constraint.

8. **Speed controls during long waits:** The gap between 07:10 (switching work done) and 09:00 (passenger train passes) is nearly two hours of game time with nothing happening. The game must have speed controls by Scenario 2, or this wait is unbearable. Consider: should the game auto-fast-forward when the next event is far away? Or does the player need to manage time speed manually?

9. **Passenger train preview:** Should the player be able to see the passenger train's path on the map before pressing Play? A ghost/preview of the passenger train's route could help the player understand the constraint spatially, not just temporally.

10. **Difficulty curve:** Scenario 2 adds one constraint (mainline traffic) and one new order type (`WaitUntil`). Is this the right step up from Scenario 1? Or should there be an intermediate scenario (e.g., one passenger train instead of two)?
