using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace TruckDemo
{
    /// <summary>
    /// Body plus wheels and bumpers. Anchors match src/content/fit.ts:
    /// Y-up, +Z forward in the GLB, axle along +X, lip toward +X.
    /// </summary>
    public static class TruckAssembler
    {
        public struct Spec
        {
            public float Wheelbase, Track, FrontOver, RearOver, Clearance;
        }

        static readonly Dictionary<string, Spec> Specs = new Dictionary<string, Spec>
        {
            { "ridgehaul-summit", new Spec { Wheelbase = 3.4f, Track = 1.56f, FrontOver = 0.78f, RearOver = 0.78f, Clearance = 0.26f } },
            { "veldt-meridian", new Spec { Wheelbase = 3.55f, Track = 1.7f, FrontOver = 0.86f, RearOver = 1.15f, Clearance = 0.32f } },
            { "northline-harbor", new Spec { Wheelbase = 3.2f, Track = 1.52f, FrontOver = 0.7f, RearOver = 0.9f, Clearance = 0.28f } },
            { "kestrel-talon", new Spec { Wheelbase = 3.15f, Track = 1.66f, FrontOver = 0.95f, RearOver = 0.58f, Clearance = 0.22f } },
        };

        public struct Finish
        {
            public float Metal, Rough, Coat, CoatRough;
        }

        public static readonly Dictionary<string, Finish> Finishes = new Dictionary<string, Finish>
        {
            { "gloss", new Finish { Metal = 0.12f, Rough = 0.18f, Coat = 1f, CoatRough = 0.06f } },
            { "metallic", new Finish { Metal = 0.86f, Rough = 0.28f, Coat = 0.7f, CoatRough = 0.12f } },
            { "satin", new Finish { Metal = 0.42f, Rough = 0.45f, Coat = 0.32f, CoatRough = 0.24f } },
            { "matte", new Finish { Metal = 0.04f, Rough = 0.82f, Coat = 0.02f, CoatRough = 0.55f } },
        };

        public static string ModelsRoot()
        {
            string repo = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "..", ".."));
            return Path.Combine(repo, "src", "assets", "models");
        }

        public static string EnvironmentRoot()
        {
            string repo = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "..", ".."));
            return Path.Combine(repo, "engine-demos", "godot", "environment");
        }

        public static GameObject Build(Dictionary<string, object> loadout, MaterialLibrary mats)
        {
            string id = System.Convert.ToString(loadout["truck"]);
            var spec = Specs[id];
            float radius = Float(loadout, "tireRadius", 0.38f);
            float lift = Mathf.Max(0f, radius - 0.38f);
            var paint = mats.Paint(ColorFrom(System.Convert.ToString(loadout["paint"])), System.Convert.ToString(loadout["finish"]));
            var rim = mats.Rim(ColorFrom(System.Convert.ToString(loadout["rim"])), Float(loadout, "rimMetal", 1f), Float(loadout, "rimRough", 0.16f));

            var root = new GameObject(id);
            var body = new GameObject("Body");
            body.transform.SetParent(root.transform, false);
            body.transform.localPosition = new Vector3(0f, lift, 0f);

            var bodyGlb = GlbLoader.Load(Path.Combine(ModelsRoot(), "trucks", id + ".glb"));
            bodyGlb.transform.SetParent(body.transform, false);
            Assign(bodyGlb, paint, rim, mats, false);

            string bumperId = System.Convert.ToString(loadout["bumper"]);
            if (!string.IsNullOrEmpty(bumperId))
            {
                string bumperPath = Path.Combine(ModelsRoot(), "parts", bumperId + ".glb");
                Attach(body.transform, bumperPath, BumperFront(spec), Quaternion.identity, paint, rim, mats);
                Attach(body.transform, bumperPath, BumperRear(spec), Quaternion.Euler(0f, 180f, 0f), paint, rim, mats);
            }

            var spins = new List<Transform>();
            float front = spec.Wheelbase * 0.5f;
            float half = spec.Track * 0.5f;
            Vector3[] wheels =
            {
                new Vector3(-half, radius, front),
                new Vector3(half, radius, front),
                new Vector3(-half, radius, -front),
                new Vector3(half, radius, -front),
            };
            string tirePath = Path.Combine(ModelsRoot(), "parts", loadout["tire"] + ".glb");
            string rimPath = Path.Combine(ModelsRoot(), "parts", loadout["wheel"] + ".glb");
            foreach (var wheel in wheels)
            {
                var pivot = new GameObject("Wheel");
                pivot.transform.SetParent(root.transform, false);
                pivot.transform.localPosition = GlbSpace.ToUnity(wheel);
                if (wheel.x < 0f)
                    pivot.transform.localRotation = Quaternion.Euler(0f, 180f, 0f);
                var spin = new GameObject("Spin");
                spin.transform.SetParent(pivot.transform, false);
                var tire = GlbLoader.Load(tirePath);
                var rimGlb = GlbLoader.Load(rimPath);
                tire.transform.SetParent(spin.transform, false);
                rimGlb.transform.SetParent(spin.transform, false);
                Assign(tire, paint, rim, mats, true);
                Assign(rimGlb, paint, rim, mats, true);
                spins.Add(spin.transform);
            }

            var drive = root.AddComponent<SimpleDrive>();
            drive.Spins = spins.ToArray();
            drive.enabled = false;
            return root;
        }

        static void Attach(Transform parent, string path, Vector3 gltfPos, Quaternion rotation, Material paint, Material rim, MaterialLibrary mats)
        {
            var glb = GlbLoader.Load(path);
            var pivot = new GameObject("Part");
            pivot.transform.SetParent(parent, false);
            pivot.transform.localPosition = GlbSpace.ToUnity(gltfPos);
            pivot.transform.localRotation = rotation;
            glb.transform.SetParent(pivot.transform, false);
            Assign(glb, paint, rim, mats, false);
        }

        public static void Assign(GameObject root, Material paint, Material rim, MaterialLibrary mats, bool wheel)
        {
            foreach (var part in root.GetComponentsInChildren<GltfPart>(true))
            {
                string label = (part.NodeName + " " + part.MaterialName).ToLowerInvariant();
                var renderer = part.GetComponent<MeshRenderer>();
                if (label.Contains("lod"))
                {
                    part.gameObject.SetActive(false);
                    continue;
                }
                Material chosen = mats.Plastic;
                if (label.Contains("glass"))
                {
                    chosen = mats.Glass;
                    renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                }
                else if (label.Contains("caliper")) chosen = mats.Caliper;
                else if (label.Contains("rotor")) chosen = mats.Rotor;
                else if (label.Contains("interior")) chosen = mats.Interior;
                else if (label.Contains("rubber")) chosen = mats.Rubber;
                else if (label.Contains("tail")) chosen = mats.Tail;
                else if (label.Contains("light")) chosen = mats.Lamp;
                else if (label.Contains("plate")) chosen = mats.Plate;
                else if (label.Contains("chrome")) chosen = wheel ? rim : mats.Chrome;
                else if (label.Contains("paint") || label.Contains("body") || label.Contains("trim")) chosen = paint;
                else chosen = wheel ? rim : mats.Plastic;
                renderer.sharedMaterial = chosen;
            }
        }

        static Vector3 BumperFront(Spec spec)
        {
            float frontZ = spec.Wheelbase * 0.5f + spec.FrontOver;
            return new Vector3(0f, spec.Clearance + 0.18f, frontZ - 0.02f);
        }

        static Vector3 BumperRear(Spec spec)
        {
            float rearZ = -spec.Wheelbase * 0.5f - spec.RearOver;
            return new Vector3(0f, spec.Clearance + 0.2f, rearZ + 0.04f);
        }

        public static float Float(Dictionary<string, object> obj, string key, float fallback)
        {
            if (!obj.TryGetValue(key, out var value) || value == null)
                return fallback;
            return System.Convert.ToSingle(value, System.Globalization.CultureInfo.InvariantCulture);
        }

        public static Color ColorFrom(string html)
        {
            if (ColorUtility.TryParseHtmlString(html, out var color))
                return color;
            return Color.white;
        }
    }

    public sealed class MaterialLibrary
    {
        public readonly Material Chrome;
        public readonly Material Rubber;
        public readonly Material Plastic;
        public readonly Material Glass;
        public readonly Material Interior;
        public readonly Material Plate;
        public readonly Material Rotor;
        public readonly Material Caliper;
        public readonly Material Lamp;
        public readonly Material Tail;
        readonly Shader _clearcoat;
        readonly Shader _glass;

        public MaterialLibrary()
        {
            _clearcoat = Shader.Find("TruckDemo/Clearcoat");
            if (_clearcoat == null)
                _clearcoat = Shader.Find("Universal Render Pipeline/Lit");
            _glass = Shader.Find("TruckDemo/Glass");
            if (_glass == null)
                _glass = _clearcoat;
            Chrome = Pbr(_clearcoat, new Color(0.835f, 0.867f, 0.902f), 1f, 0.12f, 0.45f, 0.08f);
            Rubber = Pbr(_clearcoat, new Color(0.086f, 0.09f, 0.102f), 0.04f, 0.94f, 0f, 0.5f);
            Plastic = Pbr(_clearcoat, new Color(0.137f, 0.149f, 0.173f), 0.18f, 0.62f, 0.08f, 0.4f);
            Glass = Pbr(_glass, new Color(0.1f, 0.18f, 0.22f, 0.62f), 0f, 0.14f, 0f, 0.2f, 0.62f);
            Interior = Pbr(_clearcoat, new Color(0.102f, 0.071f, 0.055f), 0.04f, 0.78f, 0f, 0.5f);
            Plate = Pbr(_clearcoat, new Color(0.847f, 0.788f, 0.62f), 0f, 0.45f, 0.15f, 0.3f);
            Rotor = Pbr(_clearcoat, new Color(0.553f, 0.573f, 0.596f), 0.85f, 0.42f, 0.1f, 0.3f);
            Caliper = Pbr(_clearcoat, new Color(0.478f, 0.141f, 0.125f), 0.25f, 0.48f, 0.15f, 0.35f);
            Lamp = Pbr(_clearcoat, new Color(1f, 0.973f, 0.933f), 0f, 0.28f, 0.2f, 0.15f);
            Lamp.SetColor("_EmissionColor", new Color(1f, 0.9f, 0.75f));
            Lamp.SetFloat("_EmissionStrength", 2.2f);
            Tail = Pbr(_clearcoat, new Color(1f, 0.29f, 0.29f), 0f, 0.36f, 0.15f, 0.2f);
            Tail.SetColor("_EmissionColor", new Color(1f, 0.14f, 0.14f));
            Tail.SetFloat("_EmissionStrength", 1.8f);
        }

        public Material Paint(Color color, string finishId)
        {
            if (!TruckAssembler.Finishes.TryGetValue(finishId, out var finish))
                finish = TruckAssembler.Finishes["gloss"];
            var mat = Pbr(_clearcoat, color, finish.Metal, finish.Rough, finish.Coat, finish.CoatRough);
            mat.name = "Paint";
            return mat;
        }

        public Material Rim(Color color, float metal, float rough)
        {
            float coat = metal > 0.8f ? 0.4f : 0.1f;
            var mat = Pbr(_clearcoat, color, metal, rough, coat, 0.12f);
            mat.name = "Rim";
            return mat;
        }

        public Material Concrete(Texture2D tex, float rough, float metal, Color tint)
        {
            var mat = Pbr(_clearcoat, tint, metal, rough, 0f, 0.5f);
            if (tex != null)
            {
                mat.SetTexture("_BaseMap", tex);
                mat.SetTextureScale("_BaseMap", new Vector2(6f, 6f));
            }
            return mat;
        }

        public static Material Pbr(Shader shader, Color color, float metal, float rough, float coat, float coatRough, float alpha = 1f)
        {
            var mat = new Material(shader);
            mat.SetColor("_BaseColor", color);
            mat.SetFloat("_Metallic", metal);
            mat.SetFloat("_Roughness", rough);
            mat.SetFloat("_Clearcoat", coat);
            mat.SetFloat("_ClearcoatRoughness", coatRough);
            mat.SetFloat("_Alpha", alpha);
            if (mat.HasProperty("_Smoothness"))
                mat.SetFloat("_Smoothness", 1f - rough);
            return mat;
        }
    }

    public sealed class SimpleDrive : MonoBehaviour
    {
        public Transform[] Spins = System.Array.Empty<Transform>();
        public float Speed;

        void Update()
        {
            if (!enabled)
                return;
            float throttle = 0f;
            if (Input.GetKey(KeyCode.W)) throttle += 1f;
            if (Input.GetKey(KeyCode.S)) throttle -= 1f;
            float steer = 0f;
            if (Input.GetKey(KeyCode.A)) steer += 1f;
            if (Input.GetKey(KeyCode.D)) steer -= 1f;
            Speed = Mathf.MoveTowards(Speed, throttle * 5.2f, Time.deltaTime * 6f);
            if (Mathf.Abs(Speed) > 0.08f)
                transform.Rotate(0f, steer * Mathf.Sign(Speed) * 50f * Time.deltaTime, 0f);
            Vector3 forward = transform.rotation * Vector3.back;
            transform.position += forward * Speed * Time.deltaTime;
            transform.position = new Vector3(Mathf.Clamp(transform.position.x, -16f, 16f), transform.position.y, Mathf.Clamp(transform.position.z, -16f, 16f));
            float spin = Speed / 0.38f * Mathf.Rad2Deg * Time.deltaTime;
            foreach (var hub in Spins)
            {
                if (hub != null)
                    hub.Rotate(-spin, 0f, 0f, Space.Self);
            }
        }
    }
}
