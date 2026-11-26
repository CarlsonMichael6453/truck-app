using System.IO;
using UnityEditor;
using UnityEngine;

namespace TruckDemo.EditorTools
{
    public static class BatchCapture
    {
        [MenuItem("Truck Demo/Capture Comparison Shots")]
        public static void Menu()
        {
            RunInternal(false);
        }

        public static void Run()
        {
            RunInternal(true);
        }

        static void RunInternal(bool exit)
        {
            EnsureUrp.Setup();
            if (UnityEngine.Rendering.GraphicsSettings.defaultRenderPipeline == null)
            {
                Debug.LogError("URP pipeline was not created. Open the project once in the editor, or check the URP package resolved.");
                if (exit)
                    EditorApplication.Exit(1);
                return;
            }
            var host = new GameObject("Capture");
            var builder = host.AddComponent<TruckDemo.ShowroomBuilder>();
            string dir = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "..", "renders", "unity"));
            builder.CaptureAll(dir);
            Object.DestroyImmediate(host);
            if (exit)
                EditorApplication.Exit(0);
        }
    }
}
