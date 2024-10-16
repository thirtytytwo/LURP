using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Test : MonoBehaviour
{
    void Start()
    {
        Mesh mesh = GetComponent<MeshFilter>().mesh;
        Vector3[] normals = mesh.normals;

        HashSet<Vector3> uniqueNormals = new HashSet<Vector3>();

        foreach (Vector3 normal in normals)
        {
            if (!uniqueNormals.Contains(normal))
            {
                uniqueNormals.Add(normal);
            }
        }

        Debug.Log($"不同的法向量为{uniqueNormals.Count}");
    }
}
