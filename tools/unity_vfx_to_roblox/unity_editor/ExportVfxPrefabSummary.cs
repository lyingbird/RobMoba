using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class ExportVfxPrefabSummary
{
    [MenuItem("Tools/VFX/Export Selected Prefab Summary")]
    public static void ExportSelectedPrefabSummary()
    {
        var obj = Selection.activeObject;
        if (obj == null)
        {
            Debug.LogError("Select a prefab asset first.");
            return;
        }

        var path = AssetDatabase.GetAssetPath(obj);
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
        if (prefab == null)
        {
            Debug.LogError("Selected object is not a prefab GameObject.");
            return;
        }

        var root = PrefabUtility.LoadPrefabContents(path);
        try
        {
            var summary = BuildSummary(root, path);
            var json = JsonUtility.ToJson(summary, true);
            var exportDir = Path.Combine(Application.dataPath, "..", "Temp", "VfxExports");
            Directory.CreateDirectory(exportDir);
            var outPath = Path.Combine(exportDir, prefab.name + ".json");
            File.WriteAllText(outPath, json);
            Debug.Log("Exported VFX summary to: " + outPath);
        }
        finally
        {
            PrefabUtility.UnloadPrefabContents(root);
        }
    }

    [Serializable]
    public class PrefabSummary
    {
        public string prefabName;
        public string assetPath;
        public List<ParticleSystemSummary> particleSystems = new();
        public List<MeshRendererSummary> meshRenderers = new();
    }

    [Serializable]
    public class ParticleSystemSummary
    {
        public string name;
        public float duration;
        public bool looping;
        public int maxParticles;
        public float startLifetimeMin;
        public float startLifetimeMax;
        public float startSpeedMin;
        public float startSpeedMax;
        public float startSizeMin;
        public float startSizeMax;
        public int renderMode;
        public string materialName;
        public string meshName;
    }

    [Serializable]
    public class MeshRendererSummary
    {
        public string name;
        public string[] materialNames;
        public string meshName;
    }

    private static PrefabSummary BuildSummary(GameObject root, string assetPath)
    {
        var summary = new PrefabSummary
        {
            prefabName = root.name,
            assetPath = assetPath,
        };

        foreach (var ps in root.GetComponentsInChildren<ParticleSystem>(true))
        {
            var main = ps.main;
            var renderer = ps.GetComponent<ParticleSystemRenderer>();
            summary.particleSystems.Add(new ParticleSystemSummary
            {
                name = ps.name,
                duration = main.duration,
                looping = main.loop,
                maxParticles = main.maxParticles,
                startLifetimeMin = main.startLifetime.constantMin,
                startLifetimeMax = main.startLifetime.constantMax,
                startSpeedMin = main.startSpeed.constantMin,
                startSpeedMax = main.startSpeed.constantMax,
                startSizeMin = main.startSize.constantMin,
                startSizeMax = main.startSize.constantMax,
                renderMode = renderer != null ? (int)renderer.renderMode : -1,
                materialName = renderer != null && renderer.sharedMaterial != null ? renderer.sharedMaterial.name : null,
                meshName = renderer != null && renderer.mesh != null ? renderer.mesh.name : null,
            });
        }

        foreach (var mr in root.GetComponentsInChildren<MeshRenderer>(true))
        {
            var filter = mr.GetComponent<MeshFilter>();
            var materialNames = new List<string>();
            foreach (var mat in mr.sharedMaterials)
            {
                materialNames.Add(mat != null ? mat.name : null);
            }
            summary.meshRenderers.Add(new MeshRendererSummary
            {
                name = mr.name,
                materialNames = materialNames.ToArray(),
                meshName = filter != null && filter.sharedMesh != null ? filter.sharedMesh.name : null,
            });
        }

        return summary;
    }
}
