# Truck App

A mobile-first truck garage for Omnipresent Games. Pick one of four fictional trucks, paint it, bolt on parts, and earn the rest on a short desert trail. The store is a test register: it never charges a card.

The trucks are original meshes built in Blender and exported as glTF. They are not AI-generated, and they are not based on a real brand.

## Run it

```bash
npm install
npm run dev
```

Open the URL Vite prints. The dev server is `http://127.0.0.1:47331`.

```bash
npm test          # economy, trail fairness, payments
npm run build     # typecheck and production bundle in dist/
npm run preview   # serve dist/ on port 47331
```

Progress is saved in `localStorage` under `omnipresent.truck-app.v1`. The store screen can reset that save.

## How to play

- **Garage.** Drag to orbit, pinch or scroll to zoom. Paint and finish are free. Parts have a rarity and a price in coins and in Cores.
- **Play.** Switchback is open immediately. Gulch opens after one finish. Tap the left or right half of the screen to change lanes (arrow keys or A and D on a keyboard). Coins, a clean finish, and distance fill quests and a daily bay reward.
- **Store.** Test mode. Core packs and named kits. Confirming a purchase writes a local receipt and adds the parts. Nothing is sent to Apple or Google.

Every part in a kit also has a coin price in the garage. There are no paid loot boxes.

## Trucks

| Brand | Model | Role |
| --- | --- | --- |
| Ridgehaul | Summit | Half-ton |
| Veldt | Meridian | Desert hauler |
| Northline | Harbor | City utility |
| Kestrel | Talon | Sport truck |

Names, badges, and grilles are invented. Do not swap in a real manufacturer's name, badge, or body.

## What is real, and what is mocked

Working on this device:

- 3D garage with clearcoat paint, chrome, rubber, glass, shadows, and an image-based studio environment
- 32 parts across wheels, tires, lift, bumpers, lights, exhaust, spoilers, and wraps, with common / rare / epic / legendary tiers
- Trail runs, quests, and a daily reward
- Local save of the garage, currencies, and receipts

Mocked:

- Money. `src/game/payments.ts` is a `PaymentProvider`. The default is `createMockPaymentProvider()`, which waits and returns a fake transaction id. Set `VITE_IAP` only when a real provider exists; any other value throws instead of pretending to charge. See `.env.example`.

The paint highlight is a real `MeshPhysicalMaterial` clearcoat. On a phone the bloom pass is skipped so the scene stays lighter on the GPU. Desktop gets a short bloom and vignette.

## Rebuild the meshes

Blender 4 is required. From the repo root:

```bash
blender --background --python tools/build_trucks.py
```

That writes:

- `src/assets/models/trucks/<truckId>.glb`
- `src/assets/models/parts/<partId>.glb`

The script models in meters with **+Y up and +Z forward**, and exports with `export_yup` off so those axes are preserved. Three.js then loads them as a normal Y-up glTF. Wheel GLBs are centered on the hub with the axle along +X. A tire is a torus so the rim stays visible. Bumper, light, exhaust, and spoiler origins are the mount point.

`src/content/fit.ts` repeats the ride height and anchor positions from the script. If you move a wheel arch in Blender, update that file so the rims stay in the wells.

## Drop in a Meshy or Tripo GLB later

The loader already prefers a file on disk. `src/game/modelFiles.ts` picks up every `.glb` under `src/assets/models/` by filename.

1. Export **glTF binary (.glb)**, meters, **Y-up**, facing **+Z**. Meshy and Tripo already export Y-up.
2. Rename paintable meshes or materials so the name contains `Paint`. Use `Glass`, `Chrome`, `Rubber`, `Plastic`, `Light`, and `Tail` for the other slots. The garage replaces those materials at runtime, so the selected color and finish still apply.
3. Leave wheels, bumpers, and the other bolt-ons out of the body file. Those come from `src/assets/models/parts/<partId>.glb`.
4. Save a body as `src/assets/models/trucks/<truckId>.glb`. The id has to match `src/content/catalog.ts` (`ridgehaul-summit`, `veldt-meridian`, `northline-harbor`, `kestrel-talon`).
5. Save a part as `src/assets/models/parts/<partId>.glb` (`wh-five`, `ti-mud`, `bp-tube`, and the rest of the catalog ids).
6. Restart `npm run dev`. Keep a body under about 40k triangles and a part under about 8k so a phone can orbit it smoothly.

Optional empties, if you want the app to find mounts later: `anchor_bumper_front`, `anchor_bumper_rear`, `anchor_lightbar`, `anchor_exhaust`, `anchor_spoiler`. Today the mounts come from `src/content/fit.ts`.

## Wiring real Apple and Google purchases

Digital goods on iOS have to go through StoreKit. Do not drop in Stripe for the kits.

1. Keep the `PaymentProvider` interface in `src/game/payments.ts`.
2. Add `@revenuecat/purchases-capacitor` and implement the same `purchase` and `restore` methods against RevenueCat. Map product ids to the ids in `src/content/products.ts` (`cores_small`, `bundle_trail`, and the rest).
3. Core packs are consumable. Kits are non-consumable. Restore should replay kits only, which `restorePurchases` in `src/game/logic.ts` already does from local receipts.
4. Swap `createPaymentProvider()` so `VITE_IAP=revenuecat` returns the new provider. Until that class exists, the app refuses to boot a non-mock mode rather than fake a charge.
5. Wrap the Vite build with Capacitor when you are ready for the stores:

```bash
npm run build
npx cap add ios
npx cap add android
```

`vite.config.ts` uses a relative `base` for production so the WebView can load `dist/`. Safe areas are already padded. The save is `localStorage`; Capacitor Preferences is the later swap if you want the save to survive a WebView wipe.

Test with sandbox accounts. Keep the rule that every paid part still has a coin price.

## Suggested next steps

- Replace individual part GLBs with higher-detail hero wheels and bumpers, using the same filenames.
- Add camera bookmarks in the bay (front, bed, wheel).
- More hand-authored trails. The current two live in `src/content/tracks.ts`, and a test fails if a cluster blocks every lane.
- Capacitor plus a RevenueCat sandbox, then store listings under Omnipresent Games.
