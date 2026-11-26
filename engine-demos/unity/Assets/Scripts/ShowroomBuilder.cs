using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace TruckDemo
{
    /// <summary>
    /// Builds the showroom or the meetup lot at play time, and renders the
    /// shared shot list from engine-demos/shots.json. Coordinates in that file
    /// are glTF / Godot space. GlbSpace.ToUnity mirrors Z.
    /// </summary>
    public sealed class ShowroomBuilder : MonoBehaviour
    {
        public string mode = "showroom";

        Camera _camera;
        MaterialLibrary _mats;
        GameObject _trucks;
        Dictionary<string, object> _shots;
        Dictionary<string, object> _loadout;
        int _paint = 0;
        int _rim = 0;
        int _bumper = 0;
        int _finish = 0;
        float _orbit = 0.62f;
        float _hold = 0f;
        bool _capturing;

        static readonly string[] Paints =
        {
            "#c4622d", "#e6e0d4", "#1b1e26", "#1d6e76", "#c4a56d", "#3d2b58", "#8d2e2e", "#c5d0dc"
        };
        static readonly string[] PaintNames =
        {
            "Kiln Copper", "Bone Ivory", "Night Ink", "Harbor Teal", "Dune Sand", "Signal Violet", "Brake Crimson", "Glacier"
        };
        static readonly string[] Rims = { "wh-five", "wh-aero", "wh-blade", "wh-split", "wh-turbine", "wh-mesh", "wh-deep" };
        static readonly string[] RimHex = { "#d5dde6", "#d7dee6", "#e8eef5", "#f2f5f8", "#e3c07a", "#c9d2dc", "#e7edf4" };
        static readonly float[] RimMetal = { 0.95f, 1f, 1f, 1f, 1f, 1f, 1f };
        static readonly float[] RimRough = { 0.18f, 0.10f, 0.10f, 0.07f, 0.14f, 0.12f, 0.08f };
        static readonly string[] RimNames = { "Five-Spoke", "Aero Lattice", "Vector Blade", "Split Dish", "Solar Turbine", "Forged Mesh", "Deep Lip" };
        static readonly string[] Bumpers = { "bp-factory", "bp-tube", "bp-winch", "bp-pre" };
        static readonly string[] BumperNames = { "Factory Bar", "Tube Guard", "Winch Plate", "Prerunner Hoop" };
        static readonly string[] Finishes = { "gloss", "metallic", "satin", "matte" };

        void Awake()
        {
            if (!Application.isPlaying)
                return;
            _shots = ReadShots();
            _mats = new MaterialLibrary();
            _loadout = Copy((Dictionary<string, object>)((List<object>)_shots["shots"])[0]);
            BuildWorld(mode);
            EnsureCamera();
            if (mode == "lot")
                SpawnLot(true);
            else
                SpawnTruck(_loadout, Vector3.zero, 0f, "Hero");
            FrameOrbit(true);
        }

        void Update()
        {
            if (!Application.isPlaying || _capturing || _camera == null)
                return;
            _hold = Mathf.Max(0f, _hold - Time.deltaTime);
            var player = _trucks != null ? _trucks.transform.Find("Player") : null;
            bool driving = player != null && player.GetComponent<SimpleDrive>() is SimpleDrive drive && Mathf.Abs(drive.Speed) > 0.2f;
            if (_hold <= 0f && !driving)
            {
                _orbit += Time.deltaTime * 0.16f;
                FrameOrbit(false);
            }
            if (Input.GetMouseButton(0))
            {
                _orbit -= Input.GetAxis("Mouse X") * 0.15f;
                _hold = 1.2f;
                FrameOrbit(false);
            }
            if (Input.GetKeyDown(KeyCode.C)) { _paint = (_paint + 1) % Paints.Length; ApplyCycle(); }
            if (Input.GetKeyDown(KeyCode.R)) { _rim = (_rim + 1) % Rims.Length; ApplyCycle(); }
            if (Input.GetKeyDown(KeyCode.B)) { _bumper = (_bumper + 1) % Bumpers.Length; ApplyCycle(); }
            if (Input.GetKeyDown(KeyCode.F)) { _finish = (_finish + 1) % Finishes.Length; ApplyCycle(); }
            if (Input.GetKeyDown(KeyCode.L))
                SceneManager.LoadScene(mode == "showroom" ? "Lot" : "Showroom");
        }

        void OnGUI()
        {
            if (!Application.isPlaying || _capturing)
                return;
            string where = mode == "lot" ? "Meetup lot" : "Showroom";
            var style = new GUIStyle(GUI.skin.label) { fontSize = 18, normal = { textColor = new Color(0.96f, 0.94f, 0.9f) } };
            GUI.Label(new Rect(24, 18, 1200, 28), where + "    " + PaintNames[_paint] + " " + Finishes[_finish] + "    " + RimNames[_rim] + "    " + BumperNames[_bumper], style);
            GUI.Label(new Rect(24, 46, 1200, 24), "C paint   R rim   B bumper   F finish   L lot   WASD drive", style);
        }

        public void CaptureAll(string outDir)
        {
            _capturing = true;
            Directory.CreateDirectory(outDir);
            _shots = ReadShots();
            _mats = new MaterialLibrary();
            int width = System.Convert.ToInt32(_shots["width"]);
            int height = System.Convert.ToInt32(_shots["height"]);
            var rt = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
            var tex = new Texture2D(width, height, TextureFormat.RGB24, false);
            EnsureCamera();
            _camera.targetTexture = rt;
            int index = 0;
            foreach (var raw in (List<object>)_shots["shots"])
            {
                var shot = (Dictionary<string, object>)raw;
                string scene = System.Convert.ToString(shot["scene"]);
                ClearTrucks();
                BuildWorld(scene);
                if (scene == "lot")
                    SpawnLot(false);
                else
                    SpawnTruck(shot, Vector3.zero, 0f, "Hero");
                Aim(Vec(shot["eye"]), Vec(shot["target"]), TruckAssembler.Float(shot, "fov", 32f));
                var probe = Object.FindObjectOfType<ReflectionProbe>();
                if (probe != null)
                    probe.RenderProbe();
                _camera.Render();
                RenderTexture.active = rt;
                tex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
                tex.Apply();
                string path = Path.Combine(outDir, shot["id"] + ".png");
                File.WriteAllBytes(path, tex.EncodeToPNG());
                Debug.Log("captured " + path);
                index++;
            }
            _camera.targetTexture = null;
            RenderTexture.active = null;
            rt.Release();
            Debug.Log("Unity capture wrote " + index + " shots to " + outDir);
        }

        void ApplyCycle()
        {
            _loadout["paint"] = Paints[_paint];
            _loadout["paintName"] = PaintNames[_paint];
            _loadout["finish"] = Finishes[_finish];
            _loadout["wheel"] = Rims[_rim];
            _loadout["rim"] = RimHex[_rim];
            _loadout["rimMetal"] = RimMetal[_rim];
            _loadout["rimRough"] = RimRough[_rim];
            _loadout["bumper"] = Bumpers[_bumper];
            _loadout["truck"] = "ridgehaul-summit";
            if (mode == "lot")
            {
                var player = _trucks.transform.Find("Player");
                Vector3 pos = player != null ? player.position : Vector3.zero;
                float yaw = player != null ? player.eulerAngles.y : 0f;
                if (player != null)
                    Destroy(player.gameObject);
                var truck = SpawnTruck(_loadout, Vector3.zero, 0f, "Player");
                truck.transform.position = pos;
                truck.transform.rotation = Quaternion.Euler(0f, yaw, 0f);
                truck.GetComponent<SimpleDrive>().enabled = true;
            }
            else
            {
                ClearTrucks();
                SpawnTruck(_loadout, Vector3.zero, 0f, "Hero");
            }
        }

        GameObject SpawnTruck(Dictionary<string, object> loadout, Vector3 gltfPos, float gltfYaw, string name)
        {
            if (_trucks == null)
            {
                _trucks = new GameObject("Trucks");
            }
            var truck = TruckAssembler.Build(loadout, _mats);
            truck.name = name;
            truck.transform.SetParent(_trucks.transform, false);
            truck.transform.position = GlbSpace.ToUnity(gltfPos);
            truck.transform.rotation = Quaternion.Euler(0f, GlbSpace.YawDegrees(gltfYaw), 0f);
            return truck;
        }

        void SpawnLot(bool drivable)
        {
            bool first = true;
            foreach (var raw in (List<object>)_shots["lot"])
            {
                var entry = (Dictionary<string, object>)raw;
                var pos = EntryVec(entry["position"]);
                float yaw = TruckAssembler.Float(entry, "yaw", 0f);
                var truck = SpawnTruck(entry, pos, yaw, first ? "Player" : "Talon");
                var drive = truck.GetComponent<SimpleDrive>();
                drive.enabled = drivable && first;
                first = false;
            }
        }

        void ClearTrucks()
        {
            if (_trucks != null)
                DestroyImmediate(_trucks);
            _trucks = new GameObject("Trucks");
        }

        void BuildWorld(string kind)
        {
            var old = GameObject.Find("World");
            if (old != null)
                DestroyImmediate(old);
            var world = new GameObject("World");
            if (kind == "lot")
                LotSet(world.transform);
            else
                ShowroomSet(world.transform);
            Post(world.transform, kind == "lot");
        }

        void ShowroomSet(Transform world)
        {
            var concrete = LoadPng(Path.Combine(TruckAssembler.EnvironmentRoot(), "concrete.png"));
            var floorMat = _mats.Concrete(concrete, 0.62f, 0.06f, new Color(1.35f, 1.35f, 1.4f));
            var floor = Primitive(PrimitiveType.Plane, "Floor", world, new Vector3(2.2f, 1f, 2.2f), GlbSpace.ToUnity(0f, 0f, 0f), floorMat);
            floor.isStatic = true;

            var padMat = _mats.Concrete(null, 0.32f, 0.18f, new Color(0.42f, 0.43f, 0.46f));
            Primitive(PrimitiveType.Cylinder, "Pad", world, new Vector3(7.2f, 0.012f, 7.2f), GlbSpace.ToUnity(0f, 0.02f, 0.15f), padMat);

            var wall = _mats.Concrete(null, 0.78f, 0.04f, new Color(0.18f, 0.185f, 0.2f));
            Primitive(PrimitiveType.Cube, "Back", world, new Vector3(16f, 4.6f, 0.16f), GlbSpace.ToUnity(0f, 2.3f, -6.2f), wall);
            Primitive(PrimitiveType.Cube, "Left", world, new Vector3(0.16f, 4.6f, 14f), GlbSpace.ToUnity(-7.2f, 2.3f, -1.2f), wall);
            Primitive(PrimitiveType.Cube, "Right", world, new Vector3(0.16f, 4.6f, 14f), GlbSpace.ToUnity(7.2f, 2.3f, -1.2f), wall);
            Primitive(PrimitiveType.Cube, "Ceiling", world, new Vector3(16f, 0.16f, 14f), GlbSpace.ToUnity(0f, 4.6f, -1.2f), wall);

            Panel(world, new Vector3(3.2f, 0.1f, 0.18f), new Vector3(0f, 3.35f, -6.02f), new Color(1f, 0.96f, 0.9f), 2.2f);
            Sun(world, new Vector3(6.2f, 8.4f, 4.6f), new Vector3(0f, 0.7f, 0.2f), new Color(1f, 0.95f, 0.86f), 1.15f, true);
            Sun(world, new Vector3(-6.5f, 3.4f, -2.2f), new Vector3(0f, 0.8f, 0f), new Color(0.62f, 0.74f, 1f), 0.42f, false);
            Spot(world, new Vector3(1.2f, 4.2f, 2.6f), new Vector3(0f, 0.7f, 0.4f), new Color(1f, 0.97f, 0.92f), 3.2f);

            var sign = Quad(world, Path.Combine(TruckAssembler.EnvironmentRoot(), "sign.png"), new Vector2(3.4f, 0.85f), new Vector3(0f, 2.55f, -6.05f));
            sign.transform.rotation = Quaternion.Euler(0f, 180f, 0f);

            var probeGo = new GameObject("Probe");
            probeGo.transform.SetParent(world, false);
            var probe = probeGo.AddComponent<ReflectionProbe>();
            probe.mode = ReflectionProbeMode.Realtime;
            probe.refreshMode = ReflectionProbeRefreshMode.ViaScripting;
            probe.size = new Vector3(16f, 8f, 16f);
            probe.resolution = 128;
            probe.boxProjection = true;
            probe.renderDynamicObjects = true;

            var hdr = LoadHdr(Path.Combine(TruckAssembler.EnvironmentRoot(), "studio.hdr"));
            if (hdr != null)
            {
                var sky = new Material(Shader.Find("Skybox/Panoramic"));
                sky.SetTexture("_MainTex", hdr);
                sky.SetFloat("_Mapping", 1f);
                sky.SetFloat("_Exposure", 0.55f);
                RenderSettings.skybox = sky;
                RenderSettings.ambientMode = AmbientMode.Skybox;
                RenderSettings.ambientIntensity = 0.7f;
            }
        }

        void LotSet(Transform world)
        {
            var asphalt = LoadPng(Path.Combine(TruckAssembler.EnvironmentRoot(), "asphalt.png"));
            var groundMat = _mats.Concrete(asphalt, 0.86f, 0.02f, new Color(1.1f, 1.05f, 0.95f));
            groundMat.SetTextureScale("_BaseMap", new Vector2(12f, 12f));
            Primitive(PrimitiveType.Plane, "Ground", world, new Vector3(4.8f, 1f, 4.8f), Vector3.zero, groundMat);
            var pad = _mats.Concrete(LoadPng(Path.Combine(TruckAssembler.EnvironmentRoot(), "concrete.png")), 0.72f, 0.04f, Color.white);
            Primitive(PrimitiveType.Cube, "Pad", world, new Vector3(12.5f, 0.04f, 8.5f), GlbSpace.ToUnity(0f, 0.02f, 0.2f), pad);
            var stripe = MaterialLibrary.Pbr(Shader.Find("TruckDemo/Clearcoat") ?? Shader.Find("Universal Render Pipeline/Lit"), new Color(0.92f, 0.9f, 0.84f), 0f, 0.6f, 0f, 0.5f);
            Primitive(PrimitiveType.Cube, "StripeL", world, new Vector3(0.1f, 0.02f, 5.4f), GlbSpace.ToUnity(-1.7f, 0.05f, 0.2f), stripe);
            Primitive(PrimitiveType.Cube, "StripeR", world, new Vector3(0.1f, 0.02f, 5.4f), GlbSpace.ToUnity(1.7f, 0.05f, 0.2f), stripe);
            var poleMat = _mats.Concrete(null, 0.4f, 0.6f, new Color(0.35f, 0.37f, 0.4f));
            Primitive(PrimitiveType.Cylinder, "Pole", world, new Vector3(0.14f, 2.1f, 0.14f), GlbSpace.ToUnity(-8.5f, 2.1f, -3.5f), poleMat);
            Panel(world, new Vector3(0.7f, 0.08f, 0.35f), new Vector3(-8.5f, 4.15f, -3.5f), new Color(1f, 0.93f, 0.75f), 3f);
            var sign = Quad(world, Path.Combine(TruckAssembler.EnvironmentRoot(), "lot-sign.png"), new Vector2(3.6f, 0.9f), new Vector3(0f, 2.4f, -5.6f));
            sign.transform.rotation = Quaternion.Euler(0f, 180f, 0f);
            var sun = Sun(world, new Vector3(18f, 11f, 8f), new Vector3(0f, 0.6f, 0f), new Color(1f, 0.86f, 0.68f), 1.35f, true);
            Sun(world, new Vector3(-10f, 6f, -6f), new Vector3(0f, 1f, 0f), new Color(0.55f, 0.68f, 1f), 0.35f, false);
            RenderSettings.sun = sun;
            var sky = new Material(Shader.Find("Skybox/Procedural"));
            sky.SetColor("_SkyTint", new Color(0.45f, 0.58f, 0.82f));
            sky.SetColor("_GroundColor", new Color(0.45f, 0.32f, 0.2f));
            sky.SetFloat("_AtmosphereThickness", 1.15f);
            sky.SetFloat("_Exposure", 1.05f);
            sky.SetFloat("_SunSize", 0.04f);
            sky.SetFloat("_SunSizeConvergence", 2f);
            RenderSettings.skybox = sky;
            RenderSettings.ambientMode = AmbientMode.Skybox;
            RenderSettings.ambientIntensity = 0.85f;
        }

        void Post(Transform world, bool lot)
        {
            var host = new GameObject("Post");
            host.transform.SetParent(world, false);
            var volume = host.AddComponent<Volume>();
            volume.isGlobal = true;
            var profile = ScriptableObject.CreateInstance<VolumeProfile>();
            volume.sharedProfile = profile;
            var bloom = profile.Add<Bloom>(true);
            bloom.intensity.Override(lot ? 0.12f : 0.22f);
            bloom.threshold.Override(1.15f);
            var tone = profile.Add<Tonemapping>(true);
            tone.mode.Override(TonemappingMode.ACES);
            var color = profile.Add<ColorAdjustments>(true);
            color.contrast.Override(8f);
            color.saturation.Override(6f);
            var vignette = profile.Add<Vignette>(true);
            vignette.intensity.Override(0.24f);
            vignette.smoothness.Override(0.4f);
        }

        void EnsureCamera()
        {
            _camera = Camera.main;
            if (_camera == null)
            {
                var go = new GameObject("Main Camera");
                go.tag = "MainCamera";
                _camera = go.AddComponent<Camera>();
                go.AddComponent<AudioListener>();
            }
            _camera.clearFlags = CameraClearFlags.Skybox;
            _camera.nearClipPlane = 0.06f;
            _camera.farClipPlane = 80f;
            _camera.allowMSAA = true;
            var extra = _camera.GetUniversalAdditionalCameraData();
            extra.renderPostProcessing = true;
            extra.antialiasing = AntialiasingMode.SubpixelMorphologicalAntialiasing;
        }

        void FrameOrbit(bool snap)
        {
            Vector3 target = mode == "showroom" ? new Vector3(0f, 0.9f, 0.1f) : new Vector3(0.1f, 0.85f, 0.1f);
            float dist = mode == "showroom" ? 7.4f : 12.5f;
            float height = mode == "showroom" ? 1.85f : 2.6f;
            var eye = target + new Vector3(Mathf.Sin(_orbit) * dist, height, Mathf.Cos(_orbit) * dist);
            Aim(eye, target, mode == "showroom" ? 32f : 36f);
        }

        void Aim(Vector3 eyeGltf, Vector3 targetGltf, float fov)
        {
            _camera.transform.position = GlbSpace.ToUnity(eyeGltf);
            _camera.transform.LookAt(GlbSpace.ToUnity(targetGltf), Vector3.up);
            _camera.fieldOfView = fov;
        }

        static GameObject Primitive(PrimitiveType type, string name, Transform parent, Vector3 scale, Vector3 position, Material mat)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localScale = scale;
            go.transform.position = position;
            var collider = go.GetComponent<Collider>();
            if (collider != null)
                DestroyImmediate(collider);
            go.GetComponent<MeshRenderer>().sharedMaterial = mat;
            return go;
        }

        static void Panel(Transform parent, Vector3 size, Vector3 gltfPos, Color color, float energy)
        {
            var shader = Shader.Find("TruckDemo/Clearcoat") ?? Shader.Find("Universal Render Pipeline/Lit");
            var mat = MaterialLibrary.Pbr(shader, color, 0f, 0.4f, 0f, 0.5f);
            mat.SetColor("_EmissionColor", color);
            mat.SetFloat("_EmissionStrength", energy);
            Primitive(PrimitiveType.Cube, "Panel", parent, size, GlbSpace.ToUnity(gltfPos), mat);
        }

        static Light Sun(Transform parent, Vector3 from, Vector3 to, Color color, float intensity, bool shadows)
        {
            var go = new GameObject(shadows ? "Key" : "Fill");
            go.transform.SetParent(parent, false);
            var light = go.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = color;
            light.intensity = intensity;
            light.shadows = shadows ? LightShadows.Soft : LightShadows.None;
            go.transform.position = GlbSpace.ToUnity(from);
            go.transform.LookAt(GlbSpace.ToUnity(to), Vector3.up);
            return light;
        }

        static void Spot(Transform parent, Vector3 from, Vector3 to, Color color, float intensity)
        {
            var go = new GameObject("Spot");
            go.transform.SetParent(parent, false);
            var light = go.AddComponent<Light>();
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = 14f;
            light.spotAngle = 76f;
            light.shadows = LightShadows.None;
            go.transform.position = GlbSpace.ToUnity(from);
            go.transform.LookAt(GlbSpace.ToUnity(to), Vector3.up);
        }

        static GameObject Quad(Transform parent, string path, Vector2 size, Vector3 gltfPos)
        {
            var tex = LoadPng(path);
            var shader = Shader.Find("TruckDemo/Clearcoat") ?? Shader.Find("Universal Render Pipeline/Lit");
            var mat = MaterialLibrary.Pbr(shader, Color.white, 0.05f, 0.55f, 0f, 0.5f);
            mat.SetTexture("_BaseMap", tex);
            mat.SetTextureScale("_BaseMap", Vector2.one);
            mat.SetColor("_EmissionColor", Color.white);
            mat.SetFloat("_EmissionStrength", 0.35f);
            var go = Primitive(PrimitiveType.Quad, "Sign", parent, new Vector3(size.x, size.y, 1f), GlbSpace.ToUnity(gltfPos), mat);
            return go;
        }

        static Texture2D LoadPng(string path)
        {
            if (!File.Exists(path))
                return null;
            var tex = new Texture2D(2, 2, TextureFormat.RGBA32, true);
            tex.LoadImage(File.ReadAllBytes(path));
            tex.wrapMode = TextureWrapMode.Repeat;
            return tex;
        }

        static Texture2D LoadHdr(string path)
        {
            if (!File.Exists(path))
                return null;
            var bytes = File.ReadAllBytes(path);
            int line = 0;
            int width = 0, height = 0, data = 0;
            while (line < bytes.Length)
            {
                int end = line;
                while (end < bytes.Length && bytes[end] != '\n')
                    end++;
                string text = Encoding.ASCII.GetString(bytes, line, end - line).Trim();
                if (text.StartsWith("-Y ", System.StringComparison.Ordinal))
                {
                    var parts = text.Split(' ');
                    height = int.Parse(parts[1], CultureInfo.InvariantCulture);
                    width = int.Parse(parts[3], CultureInfo.InvariantCulture);
                    data = end + 1;
                    break;
                }
                line = end + 1;
            }
            var colors = new Color[width * height];
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int p = data + ((y * width) + x) * 4;
                    float scale = bytes[p + 3] == 0 ? 0f : Mathf.Pow(2f, bytes[p + 3] - 128 - 8);
                    int flipped = (height - 1 - y) * width + x;
                    colors[flipped] = new Color(bytes[p] * scale, bytes[p + 1] * scale, bytes[p + 2] * scale, 1f);
                }
            }
            var tex = new Texture2D(width, height, TextureFormat.RGBAFloat, false, true);
            tex.SetPixels(colors);
            tex.Apply(false, false);
            tex.wrapMode = TextureWrapMode.Clamp;
            return tex;
        }

        static Dictionary<string, object> ReadShots()
        {
            string path = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "..", "shots.json"));
            return (Dictionary<string, object>)Json.Parse(File.ReadAllText(path));
        }

        static Dictionary<string, object> Copy(Dictionary<string, object> source)
        {
            return new Dictionary<string, object>(source);
        }

        static Vector3 Vec(object value)
        {
            var list = (List<object>)value;
            return new Vector3(ToFloat(list[0]), ToFloat(list[1]), ToFloat(list[2]));
        }

        static Vector3 EntryVec(object value) => Vec(value);

        static float ToFloat(object value) => System.Convert.ToSingle(value, CultureInfo.InvariantCulture);
    }
}
