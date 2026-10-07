# Evacuation route continuation

Open `Racoon-city-courier-next-part.rbxlx` in Roblox Studio. The original place file is preserved.

## Enhanced hospital

The hospital now has a supported entrance canopy, medical signage, 53 framed windows, clinical wall panels, roof parapets and ventilation equipment, and 28 visible stair treads with handrails over the original collision ramp. Reception and wards include monitors, IV stands, bed rails, curtains, cabinets, and clearer wayfinding.

The original floor heights, keycard position, pickup positions, locked stair doorway, and specimen location are retained. The revised script compiled and built successfully in Studio. All 12 edit-mode route spherecasts passed, including the entrance, both corridor levels, maternity access, stairs, specimen approach, and courier lane. These checks do not replace a live playtest.

The existing hospital mission now continues after loading the specimen into the courier van:

1. Press **E** at the driver door. Use **W/S** to drive/reverse and **A/D** to steer; **Space** or **E** exits. Touch and gamepad use the normal vehicle controls.
2. Drive to the tunnel. The van stops before the wreckage; continue on foot through the existing mutant ambush and collect the exit key.
3. Unlock and cross the gate, then pass through the glowing electric fence entrance. It removes **20 health**, with a two-second damage cooldown.
4. Enter the ranger house and hold **E** at the ammo crate. It refills reserve ammunition; press **R** to reload. The crate can be reused after eight seconds.
5. A dormant mutant lies on the bedroom bed. Seven seconds after the first refill, a second mutant charges through the bedroom doorway. Body shots do no damage; a direct headshot kills it and completes the chapter.

The weapon remains the existing pistol: aim with **right mouse**, fire with **left mouse**. Checkpoints preserve chapter progress after death. New geometry is built by `EscapeHouseBuilder` when play begins, following the project's existing runtime-built hospital approach.

## Validation performed

- All 17 Studio scripts parsed successfully with Luau `loadstring` (compilation only).
- House, vehicle, and mutant modules loaded in Studio edit mode.
- The house and both mutant models were constructed for visual inspection.
- Cabin entrance and bedroom doorway passed raycast clearance checks.
- Vehicle setup produced the seat, validated input remote, entry prompt, and correct road position; the temporary validation model was removed.
- The packaged file embeds all nine changed/new source files and preserves the original tunnel geometry.

Automatic playtesting was disabled. Driving with an actual seated player, live combat, checkpoint respawns, and the full mission have **not** been playtested.

To rebuild the place file after editing the sources, run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\Roblox-clua\package-next-part.ps1'
```
