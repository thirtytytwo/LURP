using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShowMeshInfo : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        Mesh mesh = GetComponent<MeshFilter>().mesh;
        MeshInfo(mesh);
    }

    private void MeshInfo(Mesh mesh)
    {
        List<Vector2> meshUVs = new List<Vector2>();
        List<Vector3> meshVerts = new List<Vector3>();
        for(int i = 0; i < mesh.vertexCount; i++)
        {
            meshVerts.Add(mesh.vertices[i]);
            meshUVs.Add(mesh.uv[i]);
        }
        Debug.Log(1);
    }
}
