using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace TruckDemo.EditorTools
{
    /// <summary>
    /// First open creates a URP asset if the project is still on the built-in pipeline.
    /// Unity 6 (6000.0) and 2022.3 both ship UniversalRenderPipelineAsset.Create.
    /// </summary>
    [InitializeOnLoad]
    public static class EnsureUrp
    {
        static EnsureUrp()
        {
            EditorApplication.delayCall += Setup;
        }

        public static void Setup()
        {
            if (GraphicsSettings.defaultRenderPipeline != null)
                return;
            Directory.CreateDirectory("Assets/Settings");
            var renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
            AssetDatabase.CreateAsset(renderer, "Assets/Settings/UniversalRenderer.asset");
            var pipeline = UniversalRenderPipelineAsset.Create(renderer);
            AssetDatabase.CreateAsset(pipeline, "Assets/Settings/UniversalRenderPipeline.asset");
            GraphicsSettings.defaultRenderPipeline = pipeline;
            QualitySettings.renderPipeline = pipeline;
            EditorUtility.SetDirty(renderer);
            EditorUtility.SetDirty(pipeline);
            AssetDatabase.SaveAssets();
            Debug.Log("Truck demo assigned a Universal Render Pipeline asset.");
        }
    }
}
