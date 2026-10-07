# Third-party code

`lift_curve.gd` is `core/easy_lift_curve.gd` from Addmix's
[Godot Aerodynamic Physics](https://github.com/addmix/godot_aerodynamic_physics),
revision `4518e64878e5af8548d56c33acc2e1e992642edb`, retrieved 2026-10-07.
Source changes: rename `LiftCurve` to `PaperLiftCurve` to avoid global class
collisions, and normalize trailing whitespace. It is used at runtime, including the stall region.

`paper_flight.gd` adapts the dynamic-pressure lift/drag construction and
`lever_arm.cross(force)` moment calculation from that project's
`ManualAeroSurface3D`. Copyright (c) 2023 Addmix. MIT license: `LICENSE-addmix.txt`.
The Web build also ships this notice and the license outside the packed data.

Rigid crease clipping, hinge rotation, history/undo, mesh generation, surface
coverage sampling and the paper-specific integrator are local implementation.
Origami Simulator was evaluated but is not included or used by this build.
