# Evacuation route and Raccoon City continuation

Open `Racoon-city-courier-next-part.rbxlx` in Roblox Studio. The original place file is preserved.

## Enhanced hospital

The hospital now has a supported entrance canopy, medical signage, 53 framed windows, clinical wall panels, roof parapets and ventilation equipment, and 28 visible stair treads with handrails over the original collision ramp. Reception and wards include monitors, IV stands, bed rails, curtains, cabinets, and clearer wayfinding.

The original floor heights, keycard position, pickup positions, locked stair doorway, and specimen location are retained. The revised script compiled and built successfully in Studio. All 12 edit-mode route spherecasts passed, including the entrance, both corridor levels, maternity access, stairs, specimen approach, and courier lane. These checks do not replace a live playtest.

The existing hospital mission now continues after loading the specimen into the courier van:

1. Press **E** at the driver door. Use **W/S** to drive/reverse and **A/D** to steer; **Space** or **E** exits. Touch and gamepad use the normal vehicle controls.
2. Drive to the tunnel. The van stops before the wreckage; continue on foot through the existing mutant ambush and collect the exit key.
3. Unlock and cross the gate, then pass through the glowing electric fence entrance. It removes **20 health**, with a two-second damage cooldown.
4. Enter the ranger house and hold **E** at the ammo crate. It refills reserve ammunition; press **R** to reload. The crate can be reused after eight seconds.
5. A dormant mutant lies on the bedroom bed. Seven seconds after the first refill, a second mutant charges through the bedroom doorway. Body shots do no damage; a direct headshot kills it and clears the house.
6. Find the courtyard sedan's ignition keys inside the house. The expanded courtyard is 112 by 120 studs, with a roaming mutant hound, a kennel, a shed, and a rear driveway.
7. Drive toward the rear exit to discover the locked gate. There is no waypoint or objective hint revealing the gate key's location. Exit the car and investigate: holding **E** at its trunk finds the key after the locked gate has been discovered.
8. Unlock the gate and drive onward, or ram it at speed. A collision permanently wedges the sedan in bent railings, disables driving, and leaves pedestrian gaps for the escape on foot.
9. Follow the 640-stud forest road to Raccoon City. A halfway shelter provides a safe respawn checkpoint. The city contains eight surrounding buildings and the 95-stud Butterfly Corps headquarters, with an accessible lobby and reception. Enter its lobby to finish this continuation.

A hulking, 300-health mutant patrols the jungle beside the tunnel approach. It has asymmetrical arms, claws, a hunched back, bone plates, and glowing eyes. The courtyard hound has 120 health. Both patrol, investigate, chase eligible nearby players, and attack; ordinary pistol damage applies to these outdoor creatures. The house attacker retains its headshot-only rule.

The weapon remains the existing pistol: aim with **right mouse**, fire with **left mouse**. Checkpoints preserve chapter progress after death within the current server. New geometry is built by `EscapeHouseBuilder` and `RaccoonCityBuilder` when play begins, following the project's existing runtime-built hospital approach. The open Studio session also has construction previews; the preview car and creatures are removed automatically before the live actors spawn.

## Validation performed

- All 22 Studio scripts parsed successfully with Luau `loadstring` (compilation only).
- Updated house, city, courtyard car, giant, and hound modules loaded and constructed in Studio edit mode.
- Ten expansion checks passed: house entrance, driveway, full car body clearance in the courtyard and along 610 studs of road, both pedestrian gaps around the simulated wreck, headquarters entrance and reception approach, 21 ground samples, and shelter respawn clearance.
- Earlier hospital and cabin route checks remain documented above; those original routes are retained.
- Static reviews covered hidden-key progression, shared vehicle state, on-foot checkpoints, server input validation, creature bounds, blocked patrol recovery, and death cleanup.
- The packaged file embeds and verifies 15 source files under their correct script parents. Its original Workspace subtree, including the tunnel, is preserved. New scenery is generated from those sources at runtime.
- Studio viewport captures returned a blank 3D view, so visual inspection of the new models could not be completed. Temporary inspection lighting and camera changes were restored.

Automatic playtesting was disabled. Driving with an actual seated player, both gate outcomes, live combat, checkpoint respawns, and the full mission have **not** been playtested.

To rebuild the place file after editing the sources, run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\Roblox-clua\package-next-part.ps1'
```
