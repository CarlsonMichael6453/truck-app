# Godot showroom

Godot 4.5 project. Open `project.godot` and run `scenes/showroom.tscn`. `scenes/lot.tscn` is the two-truck pad. L switches scenes. C / R / B / F cycle paint, rim, bumper, and finish. On the lot, WASD drives the Ridgehaul. H hosts an ENet meetup on port 7777 and J joins `127.0.0.1`.

The trucks are loaded at runtime from `src/assets/models` with `GLTFDocument`. They are not copied into this folder. Wheel and bumper anchors match `src/content/fit.ts`.

The showroom uses the Forward+ renderer: clearcoat paint, a reflection probe, an HDR studio panorama, directional shadows, SSAO, SSR, glow, and ACES. The lot uses a late-afternoon procedural sky and turns SSR off, since the ground is asphalt rather than a polished pad.

Headless frames (Vulkan, including lavapipe if that is the only GPU):

```bash
engine-demos/godot/render.sh
```

`GODOT` overrides the binary. `--xvfb` wraps the run when you have no display. Output is `engine-demos/renders/godot/`.
