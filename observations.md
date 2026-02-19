
## Completed
- ~~The buffer stop is wrongly displayed.~~ FIXED (orientation now perpendicular)
- ~~Mouse wheel zoom on the map canvas.~~ DONE
- ~~Horizontal panning of the consist in the consist builder window.~~ DONE
- ~~Time speed controls (1x, 2x, etc.) in the header bar.~~ DONE
- ~~The clock is not updating when the sim is running.~~ VERIFIED WORKING
- ~~Turnout clicking / routing verification.~~ VERIFIED WORKING
- ~~Buffer stop braking verification.~~ VERIFIED WORKING
- ~~Game designer agent: wrong solutions + scenario 2 walkthrough.~~ DONE (docs/morning-run-experience.md)
- ~~East/West station names swapped.~~ FIXED
- ~~Trains in curves: verified acceptable (max 0.14m deviation on R=170m).~~ NO FIX NEEDED
- ~~Unavailable stock shown with 0 count and dashed outline.~~ DONE (provisional field + groupAndCountStock)
- ~~MoveTo supports car-specific spotting (SpotTarget: TrainHead | SpotCar).~~ DONE
- ~~data-testid attributes added to all UI elements.~~ DONE

## Next Sprint: Bug Fixes
- When trains "move to" a spawn point, they are only considered to have arrived after the last car disappeared in the tunnel. Needs verification after program execution is implemented.

## After Bug Fixes: Coupling/Uncoupling
- Coupling/uncoupling mechanics: Uncoupling is available while a train is stopped and executing a program (spotted). The player specifies which coupling to break (between two adjacent cars or loco and adjacent car). Manual coupling is only available when the train is under manual control (not executing a program).
- Two fundamental train states: (1) Executing a program, (2) Manually controlled. Under manual control: uncoupling, changing reverser, moving to a reachable spot, and "execute program" are available. While executing a program: only "emergency stop" is available as manual override. Both emergency stop and "driver needing guidance" (program error) transition the train to manual control.

## Future
- Decompose Types.elm files (Planning/Types.elm, Programmer/Types.elm, Train/Types.elm) — move types closer to where they're used instead of centralizing them in Types modules.
- Tracks should be reserved when a train wants to enter them. Signals define blocks.
- Put rolling stock types into a JSON file, e.g. locos, cars, maybe composite track types like turnouts, crossings with no, single, and double slip, turntables
- More scenarios. (POSTPONED - do not implement automatically)
- Make scenarios selectable (e.g. dropdown or menu). Scenario 2: same as scenario 1 but adds a passenger train (1 loco + 2 passenger cars) going west-to-east at 7:00, and returning east-to-west at 9:00 (loco flipped, cars not flipped).
- Multiple trains.
