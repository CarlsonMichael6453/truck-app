using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;

namespace TruckDemo
{
    /// <summary>
    /// glTF is right-handed, +Z forward. Unity is left-handed. Vertices are
    /// transformed in glTF space, then Z is flipped so the pictures match the
    /// Godot shots. Triangle winding ends up clockwise, which Unity treats as front.
    /// </summary>
    public static class GlbSpace
    {
        public static Vector3 ToUnity(float x, float y, float z) => new Vector3(x, y, -z);

        public static Vector3 ToUnity(Vector3 gltf) => new Vector3(gltf.x, gltf.y, -gltf.z);

        public static float YawDegrees(float gltfRadians) => -gltfRadians * Mathf.Rad2Deg;
    }

    public sealed class GltfPart : MonoBehaviour
    {
        public string NodeName;
        public string MaterialName;
    }

    public static class GlbLoader
    {
        public static GameObject Load(string path)
        {
            var bytes = File.ReadAllBytes(path);
            if (bytes.Length < 20 || bytes[0] != 'g' || bytes[1] != 'l' || bytes[2] != 'T' || bytes[3] != 'F')
                throw new InvalidDataException("Not a GLB: " + path);

            int jsonLength = BitConverter.ToInt32(bytes, 12);
            int jsonType = BitConverter.ToInt32(bytes, 16);
            if (jsonType != 0x4E4F534A)
                throw new InvalidDataException("GLB JSON chunk missing: " + path);
            string json = Encoding.UTF8.GetString(bytes, 20, jsonLength);
            int binStart = 20 + jsonLength;
            int binLength = BitConverter.ToInt32(bytes, binStart);
            int binType = BitConverter.ToInt32(bytes, binStart + 4);
            if (binType != 0x004E4942)
                throw new InvalidDataException("GLB BIN chunk missing: " + path);
            var bin = new byte[binLength];
            Buffer.BlockCopy(bytes, binStart + 8, bin, 0, binLength);

            var root = Json.Parse(json) as Dictionary<string, object>;
            var doc = new Document(root, bin);
            var go = new GameObject(Path.GetFileNameWithoutExtension(path));
            doc.Build(go.transform);
            return go;
        }

        sealed class Document
        {
            readonly Dictionary<string, object> _root;
            readonly byte[] _bin;
            readonly List<object> _accessors;
            readonly List<object> _bufferViews;
            readonly List<object> _meshes;
            readonly List<object> _nodes;
            readonly List<object> _materials;

            public Document(Dictionary<string, object> root, byte[] bin)
            {
                _root = root;
                _bin = bin;
                _accessors = ListOf("accessors");
                _bufferViews = ListOf("bufferViews");
                _meshes = ListOf("meshes");
                _nodes = ListOf("nodes");
                _materials = ListOf("materials");
            }

            List<object> ListOf(string key)
            {
                if (!_root.TryGetValue(key, out var value) || value is not List<object> list)
                    return new List<object>();
                return list;
            }

            public void Build(Transform parent)
            {
                var scenes = ListOf("scenes");
                if (scenes.Count == 0)
                    return;
                var scene = (Dictionary<string, object>)scenes[0];
                if (!scene.TryGetValue("nodes", out var nodes))
                    return;
                foreach (var index in (List<object>)nodes)
                    BuildNode(Convert.ToInt32(index), Matrix4x4.identity, parent);
            }

            void BuildNode(int index, Matrix4x4 parentWorld, Transform parent)
            {
                var node = (Dictionary<string, object>)_nodes[index];
                string name = Str(node, "name");
                if (name.IndexOf("LOD", StringComparison.OrdinalIgnoreCase) >= 0)
                    return;

                var local = LocalMatrix(node);
                var world = parentWorld * local;
                if (node.TryGetValue("mesh", out var meshIndex))
                    BuildMesh(Convert.ToInt32(meshIndex), name, world, parent);
                if (node.TryGetValue("children", out var children))
                {
                    foreach (var child in (List<object>)children)
                        BuildNode(Convert.ToInt32(child), world, parent);
                }
            }

            static Matrix4x4 LocalMatrix(Dictionary<string, object> node)
            {
                if (node.TryGetValue("matrix", out var raw))
                {
                    var list = (List<object>)raw;
                    var m = new Matrix4x4();
                    m.m00 = Num(list[0]); m.m10 = Num(list[1]); m.m20 = Num(list[2]); m.m30 = Num(list[3]);
                    m.m01 = Num(list[4]); m.m11 = Num(list[5]); m.m21 = Num(list[6]); m.m31 = Num(list[7]);
                    m.m02 = Num(list[8]); m.m12 = Num(list[9]); m.m22 = Num(list[10]); m.m32 = Num(list[11]);
                    m.m03 = Num(list[12]); m.m13 = Num(list[13]); m.m23 = Num(list[14]); m.m33 = Num(list[15]);
                    return m;
                }

                var t = Vec3(node, "translation", Vector3.zero);
                var s = Vec3(node, "scale", Vector3.one);
                var q = Quat(node);
                float x = q.x, y = q.y, z = q.z, w = q.w;
                float xx = x * x, yy = y * y, zz = z * z;
                float xy = x * y, xz = x * z, yz = y * z;
                float wx = w * x, wy = w * y, wz = w * z;
                var mat = Matrix4x4.identity;
                mat.m00 = (1f - 2f * (yy + zz)) * s.x;
                mat.m10 = (2f * (xy + wz)) * s.x;
                mat.m20 = (2f * (xz - wy)) * s.x;
                mat.m01 = (2f * (xy - wz)) * s.y;
                mat.m11 = (1f - 2f * (xx + zz)) * s.y;
                mat.m21 = (2f * (yz + wx)) * s.y;
                mat.m02 = (2f * (xz + wy)) * s.z;
                mat.m12 = (2f * (yz - wx)) * s.z;
                mat.m22 = (1f - 2f * (xx + yy)) * s.z;
                mat.m03 = t.x;
                mat.m13 = t.y;
                mat.m23 = t.z;
                return mat;
            }

            void BuildMesh(int meshIndex, string nodeName, Matrix4x4 world, Transform parent)
            {
                var meshDef = (Dictionary<string, object>)_meshes[meshIndex];
                var primitives = (List<object>)meshDef["primitives"];
                var inverse = world.inverse.transpose;
                bool negative = LinearDet(world) < 0f;
                int part = 0;
                foreach (var raw in primitives)
                {
                    var prim = (Dictionary<string, object>)raw;
                    var attrs = (Dictionary<string, object>)prim["attributes"];
                    if (!attrs.ContainsKey("POSITION"))
                        continue;
                    var positions = ReadVec3(Convert.ToInt32(attrs["POSITION"]));
                    Vector3[] normals = null;
                    if (attrs.ContainsKey("NORMAL"))
                        normals = ReadVec3(Convert.ToInt32(attrs["NORMAL"]));
                    var verts = new Vector3[positions.Length];
                    var norms = new Vector3[positions.Length];
                    for (int i = 0; i < positions.Length; i++)
                    {
                        var p = world.MultiplyPoint3x4(positions[i]);
                        p.z = -p.z;
                        verts[i] = p;
                        Vector3 n = normals != null ? normals[i] : Vector3.up;
                        n = inverse.MultiplyVector(n);
                        n.z = -n.z;
                        norms[i] = n.sqrMagnitude > 1e-8f ? n.normalized : Vector3.up;
                    }

                    int[] indices;
                    if (prim.TryGetValue("indices", out var indexAccessor))
                        indices = ReadIndices(Convert.ToInt32(indexAccessor));
                    else
                    {
                        indices = new int[verts.Length];
                        for (int i = 0; i < indices.Length; i++)
                            indices[i] = i;
                    }
                    if (negative)
                    {
                        for (int i = 0; i + 2 < indices.Length; i += 3)
                            (indices[i], indices[i + 1]) = (indices[i + 1], indices[i]);
                    }

                    var mesh = new Mesh { name = nodeName };
                    if (verts.Length > 65535)
                        mesh.indexFormat = IndexFormat.UInt32;
                    mesh.vertices = verts;
                    mesh.normals = norms;
                    mesh.SetTriangles(indices, 0, true);
                    if (normals == null)
                        mesh.RecalculateNormals();
                    mesh.RecalculateBounds();

                    var child = new GameObject(primitives.Count == 1 ? nodeName : nodeName + "." + part);
                    child.transform.SetParent(parent, false);
                    var filter = child.AddComponent<MeshFilter>();
                    filter.sharedMesh = mesh;
                    var renderer = child.AddComponent<MeshRenderer>();
                    renderer.shadowCastingMode = ShadowCastingMode.On;
                    var info = child.AddComponent<GltfPart>();
                    info.NodeName = nodeName;
                    info.MaterialName = MaterialName(prim);
                    part++;
                }
            }

            string MaterialName(Dictionary<string, object> prim)
            {
                if (!prim.TryGetValue("material", out var index))
                    return "";
                int i = Convert.ToInt32(index);
                if (i < 0 || i >= _materials.Count)
                    return "";
                return Str((Dictionary<string, object>)_materials[i], "name");
            }

            Vector3[] ReadVec3(int accessorIndex)
            {
                var accessor = (Dictionary<string, object>)_accessors[accessorIndex];
                int count = Convert.ToInt32(accessor["count"]);
                var (data, offset, stride) = View(accessor, 12);
                var result = new Vector3[count];
                for (int i = 0; i < count; i++)
                {
                    int at = offset + i * stride;
                    result[i] = new Vector3(
                        BitConverter.ToSingle(data, at),
                        BitConverter.ToSingle(data, at + 4),
                        BitConverter.ToSingle(data, at + 8));
                }
                return result;
            }

            int[] ReadIndices(int accessorIndex)
            {
                var accessor = (Dictionary<string, object>)_accessors[accessorIndex];
                int count = Convert.ToInt32(accessor["count"]);
                int component = Convert.ToInt32(accessor["componentType"]);
                int width = component == 5125 ? 4 : component == 5123 ? 2 : 1;
                var (data, offset, stride) = View(accessor, width);
                var result = new int[count];
                for (int i = 0; i < count; i++)
                {
                    int at = offset + i * stride;
                    if (component == 5125)
                        result[i] = BitConverter.ToInt32(data, at);
                    else if (component == 5123)
                        result[i] = BitConverter.ToUInt16(data, at);
                    else
                        result[i] = data[at];
                }
                return result;
            }

            (byte[] data, int offset, int stride) View(Dictionary<string, object> accessor, int defaultStride)
            {
                int accessorOffset = accessor.ContainsKey("byteOffset") ? Convert.ToInt32(accessor["byteOffset"]) : 0;
                if (!accessor.TryGetValue("bufferView", out var viewIndex))
                    return (_bin, accessorOffset, defaultStride);
                var view = (Dictionary<string, object>)_bufferViews[Convert.ToInt32(viewIndex)];
                int viewOffset = view.ContainsKey("byteOffset") ? Convert.ToInt32(view["byteOffset"]) : 0;
                int stride = view.ContainsKey("byteStride") ? Convert.ToInt32(view["byteStride"]) : defaultStride;
                return (_bin, viewOffset + accessorOffset, stride);
            }

            static float LinearDet(Matrix4x4 m)
            {
                return m.m00 * (m.m11 * m.m22 - m.m12 * m.m21)
                     - m.m01 * (m.m10 * m.m22 - m.m12 * m.m20)
                     + m.m02 * (m.m10 * m.m21 - m.m11 * m.m20);
            }

            static string Str(Dictionary<string, object> obj, string key)
            {
                return obj.TryGetValue(key, out var value) ? Convert.ToString(value) : "";
            }

            static float Num(object value) => Convert.ToSingle(value, CultureInfo.InvariantCulture);

            static Vector3 Vec3(Dictionary<string, object> node, string key, Vector3 fallback)
            {
                if (!node.TryGetValue(key, out var raw))
                    return fallback;
                var list = (List<object>)raw;
                return new Vector3(Num(list[0]), Num(list[1]), Num(list[2]));
            }

            static Quaternion Quat(Dictionary<string, object> node)
            {
                if (!node.TryGetValue("rotation", out var raw))
                    return Quaternion.identity;
                var list = (List<object>)raw;
                return new Quaternion(Num(list[0]), Num(list[1]), Num(list[2]), Num(list[3]));
            }
        }
    }

    /// <summary>Enough JSON for a glTF document. Not a general parser.</summary>
    static class Json
    {
        public static object Parse(string text)
        {
            int i = 0;
            return Read(text, ref i);
        }

        static object Read(string s, ref int i)
        {
            Skip(s, ref i);
            if (i >= s.Length)
                return null;
            char c = s[i];
            if (c == '{') return Object(s, ref i);
            if (c == '[') return Array(s, ref i);
            if (c == '"') return String(s, ref i);
            if (c == 't') { i += 4; return true; }
            if (c == 'f') { i += 5; return false; }
            if (c == 'n') { i += 4; return null; }
            return Number(s, ref i);
        }

        static Dictionary<string, object> Object(string s, ref int i)
        {
            var map = new Dictionary<string, object>();
            i++;
            Skip(s, ref i);
            if (s[i] == '}') { i++; return map; }
            while (true)
            {
                Skip(s, ref i);
                string key = String(s, ref i);
                Skip(s, ref i);
                i++;
                map[key] = Read(s, ref i);
                Skip(s, ref i);
                if (s[i] == '}') { i++; return map; }
                i++;
            }
        }

        static List<object> Array(string s, ref int i)
        {
            var list = new List<object>();
            i++;
            Skip(s, ref i);
            if (s[i] == ']') { i++; return list; }
            while (true)
            {
                list.Add(Read(s, ref i));
                Skip(s, ref i);
                if (s[i] == ']') { i++; return list; }
                i++;
            }
        }

        static string String(string s, ref int i)
        {
            i++;
            var sb = new StringBuilder();
            while (i < s.Length)
            {
                char c = s[i++];
                if (c == '"')
                    return sb.ToString();
                if (c == '\\')
                {
                    char e = s[i++];
                    sb.Append(e switch
                    {
                        'n' => '\n',
                        'r' => '\r',
                        't' => '\t',
                        _ => e
                    });
                }
                else sb.Append(c);
            }
            return sb.ToString();
        }

        static object Number(string s, ref int i)
        {
            int start = i;
            if (s[i] == '-') i++;
            while (i < s.Length && (char.IsDigit(s[i]) || s[i] == '.' || s[i] == 'e' || s[i] == 'E' || s[i] == '+' || s[i] == '-'))
            {
                if ((s[i] == '+' || s[i] == '-') && i > start && s[i - 1] != 'e' && s[i - 1] != 'E')
                    break;
                i++;
            }
            string token = s.Substring(start, i - start);
            if (token.Contains('.') || token.Contains('e') || token.Contains('E'))
                return double.Parse(token, CultureInfo.InvariantCulture);
            if (long.TryParse(token, NumberStyles.Integer, CultureInfo.InvariantCulture, out long whole))
                return whole;
            return double.Parse(token, CultureInfo.InvariantCulture);
        }

        static void Skip(string s, ref int i)
        {
            while (i < s.Length && char.IsWhiteSpace(s[i]))
                i++;
        }
    }
}
