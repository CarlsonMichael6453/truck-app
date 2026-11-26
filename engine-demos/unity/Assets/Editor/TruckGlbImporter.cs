using TruckDemo;
using UnityEditor.AssetImporters;
using UnityEngine;

namespace TruckDemo.EditorTools
{
    /// <summary>
    /// Import settings for a truck GLB dropped under Assets. Scale stays 1
    /// (the files are meters). Materials are assigned by mesh and material name
    /// the same way the runtime loader does. The demos read the canonical
    /// files in src/assets/models directly, so nothing has to be copied.
    /// </summary>
    [ScriptedImporter(1, "glb")]
    public sealed class TruckGlbImporter : ScriptedImporter
    {
        public float scale = 1f;

        public override void OnImportAsset(AssetImportContext ctx)
        {
            var root = GlbLoader.Load(ctx.assetPath);
            root.transform.localScale = Vector3.one * scale;
            ctx.AddObjectToAsset("root", root);
            ctx.SetMainObject(root);
            foreach (var filter in root.GetComponentsInChildren<MeshFilter>(true))
            {
                if (filter.sharedMesh != null)
                    ctx.AddObjectToAsset(filter.sharedMesh.name + filter.GetInstanceID(), filter.sharedMesh);
            }
        }
    }
}
