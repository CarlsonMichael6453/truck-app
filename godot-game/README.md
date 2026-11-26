# Truck App for Godot

A portrait-and-landscape Godot 4.5 game for phones. It is the native companion to the Vite garage in this repo. The web app is unchanged. Trucks, parts, paints, trails, quests, and the test register follow that catalog. Every name is fictional.

The phone renderer is **Mobile** (Godot 4.5.2, the same editor line as `engine-demos/godot` on the engine-demo branch). Clearcoat, chrome, rubber, and a reflection probe stay on. Screen-space reflections and ambient occlusion stay off so a phone can hold 60 fps on one truck. The windshield uses `shaders/windshield.gdshader`, which ignores the key light and caps its brightness. That is the fix for the showroom demo, where clearcoat glass turned white against the key light.

## Open and run

Install Godot **4.5.x** (this project was checked with 4.5.2). Open `godot-game/project.godot` and press F5.

```bash
godot --path godot-game --rendering-method mobile
```

The project file already asks for the Mobile renderer. Pass the flag on the command line as well. A plain `godot --path` launch on this 4.5.2 build came up in Forward+ unless the flag was set. The editor's Play button follows the project setting.

Drag to orbit the turntable. Pinch, or the mouse wheel, zooms. The bottom bar is Garage, Play, and Store. Switchback is open immediately. Gulch opens after one finish. On a trail, tap the left or right half of the screen (or A and D) to change lanes. Three hits ends the run.

Progress is `user://truck_bay.json` (on a phone that is the app sandbox, on desktop it is Godot's user data folder). The store can reset it.

Headless import and a logic check:

```bash
godot --headless --path godot-game --import
godot --headless --path godot-game -- --self-check
godot --headless --path godot-game --quit-after 90
```

`SELF_CHECK_OK` means the four trucks assemble, the glass shader is on the windshield, the trail steps, and the test register refuses anything that is not the mock.

Frames for the bay, a customized truck, the store, and a trail:

```bash
godot-game/tools/render_shots.sh --xvfb
```

`GODOT` overrides the binary. Output defaults to `/opt/cursor/artifacts`.

## What you can change

Paint and finish are free. Gloss, metallic, matte, and satin are clearcoat `StandardMaterial3D`. Pearl adds a rim so it reads without a second shader. Parts use the same prices, rarities, and blurbs as the web catalog, including the four sleek rims: Aero Lattice, Vector Blade, Split Dish, and Monoblock.

Meshes are copies of `src/assets/models` so an export packs them. After `blender --background --python tools/build_trucks.py`, copy the new files:

```bash
cp src/assets/models/trucks/*.glb godot-game/models/trucks/
cp src/assets/models/parts/*.glb godot-game/models/parts/
```

Anchors match `src/content/fit.ts`.

## Store

The store is a **test register**. Confirming a purchase writes a local receipt and adds coins, Cores, or a fixed kit. Nothing is sent to Apple or Google. There are no paid loot boxes. Every kit part still has a coin price in the garage.

`scripts/payments.gd` is the only billing door. `ProjectSettings` `truck/billing/provider`:

| Value | What it does |
| --- | --- |
| `test` | Default. `Billing.Mock` waits in the dialog, then returns `test_<product>_<n>`. |
| `storekit` | Looks for the Godot iOS singleton `InAppStore`. If the plugin is missing, or present but not connected, the purchase fails and nothing is granted. |
| `play` | Looks for `GodotGooglePlayBilling`. Same fail-closed rule. |

The hook methods `StoreKit.integration_notes` and `PlayBilling.integration_notes` name the calls to add when a sandbox build should talk to the stores for real: product info, purchase, consume for coin packs and Core packs, acknowledge for kits, restore for kits only. Do not point consumable goods at a card form. Digital goods on iOS go through StoreKit.

## Export for iPhone and Android

Presets live in `export_presets.cfg`. The bundle id and the Android package are `com.omnipresentgames.truckapp`. No keystore, provisioning profile, or password is in the repo. `package/signed` is false until you add your own keystore locally and do not commit it.

Godot 4.5.2 export templates have to be installed (`Editor → Manage Export Templates`, or the 4.5.2 `.tpz`).

iPhone (needs a Mac, Xcode, and an Apple developer account):

1. Open the project in Godot on the Mac.
2. **Project → Export → iOS**. Leave the team id and profiles empty until you fill in the ones from your account. Do not commit them.
3. Export an Xcode project. Open it in Xcode, set the signing team, and run on a device.
4. The game rotates with the phone (`sensor` orientation). Portrait and landscape both lay out the bay.

Android:

1. Install a JDK and the Android SDK (Godot's export dialog has the paths).
2. **Project → Export → Android**. Arm64 only. Debug export runs without a release keystore.
3. For a Play upload, create a keystore on your machine, set it in the preset locally, and keep the file out of git. The `.gitignore` already ignores `*.keystore` and `*.jks`.

A web preview is possible and does not touch the Vite GitHub Pages site. Godot's web export cannot run the Mobile renderer, so the project setting `rendering/renderer/rendering_method.web` is Compatibility. Clearcoat is thinner there. The phone build is the one that matches these screenshots.

```bash
mkdir -p godot-game/build/web
godot --headless --path godot-game --export-release Web godot-game/build/web/index.html
```

`godot-game/build/` is gitignored. The Pages workflow still publishes the Vite `dist/` only.

## Performance

One truck, one directional shadow, one reflection probe updated once, MSAA 2x, glow with a high threshold. The trail turns glow off and uses a short fog. VRAM compression is off so the small studio textures stay simple; turn on `rendering/textures/vram_compression/import_etc2_astc` before a store build if you want ETC2/ASTC.

## Fonts

Oswald and Figtree are under the SIL Open Font License. See `fonts/OFL.txt` and `fonts/COPYRIGHT.txt`.
