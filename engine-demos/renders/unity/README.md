# Unity frames

No screenshots. The editor was installed and it did start a graphics device, then it stopped on licensing.

Unity 6000.0.64f1 (changeset `5360b7cd7953`) was unpacked from the Linux editor archive and `Editor/Unity -version` printed `6000.0.64f1`. Opening `engine-demos/unity` in batch mode got as far as an OpenGL 4.5 context on llvmpipe (Mesa 25.2.8), then exited with code 198:

```
[Licensing::Client] Error: Code 404 while processing request (status: Found 0 entitlement groups and 0 free entitlements matching requested entitlement ids)
[Licensing::Module] Error: Access token is unavailable; failed to update
[Licensing::Module] Error: 'com.unity.editor.headless' was not found.
No valid Unity Editor license found. Please activate your license.
```

Unity Personal is activated by signing into the Hub. There is no account on this machine, and the manual `.alf` flow does not cover Personal licenses. Nothing was rendered, and these notes are not a stand-in for a picture.

The project itself is complete: scenes, the clearcoat shader, materials, the GLB loader, and `Truck Demo/Capture Comparison Shots` (`TruckDemo.EditorTools.BatchCapture.Run`). A licensed editor on a machine with a GPU can write the same six shots into this folder.
