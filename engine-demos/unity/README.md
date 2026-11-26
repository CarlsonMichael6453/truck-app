# Unity showroom

Unity 6 (6000.0 LTS) project using the Universal Render Pipeline. Press Play in `Assets/Scenes/Showroom.unity`. `Lot.unity` is the two-truck meetup pad. L switches between them. C / R / B / F swap paint, rim, bumper, and finish. WASD drives the Ridgehaul on the lot.

The trucks are the Blender GLBs in `src/assets/models`. Nothing is copied. The loader flips Z because glTF is right-handed and Unity is left-handed, then applies the same flip to the cameras in `engine-demos/shots.json`, so the frames line up with the Godot renders.

Paint is a small clearcoat shader (`Assets/Shaders/TruckClearcoat.shader`): a metallic base plus a second GGX lobe. Glass, chrome, rubber, and the emissive lamps are the same material slots the three.js garage uses. A reflection probe, panoramic studio HDR, soft shadows, ACES tonemapping, bloom, and a vignette are created when the scene starts. The first time the project opens, an editor script creates a URP asset if the pipeline is still the built-in one.

Dropping a `.glb` into `Assets/` uses `TruckGlbImporter` (scale 1, meters, material names kept).

Screenshots, from the editor menu **Truck Demo / Capture Comparison Shots**, or headless:

```bash
Unity -batchmode -projectPath engine-demos/unity \
  -executeMethod TruckDemo.EditorTools.BatchCapture.Run \
  -logFile -
```

That needs a display (or Xvfb) and an activated editor license. Unity Personal is activated in the Hub, not with `-batchmode -createManualActivationFile`. On this machine Unity 6000.0.64f1 reached an OpenGL context and then exited 198 with no entitlement and no access token, so there are no frames. The log is in `../renders/unity/README.md`.

2022.3 LTS can reuse `Assets/` if the URP package is set to 14.x and the project version is 2022.3. `UniversalRenderPipelineAsset.Create` and the shader includes exist on both. This project file is pinned to 6000.0.64f1 so Unity 6 opens it without an upgrade prompt.
