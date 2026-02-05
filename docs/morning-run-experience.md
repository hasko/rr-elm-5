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
