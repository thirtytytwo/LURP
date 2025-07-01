using UnityEditor;
using UnityEngine;

public class CharacterShadow : MonoBehaviour
{
    [Header("Characters SkM")] 
    [SerializeField]private GameObject[] _Characters;
    
    [Header("Bounding")]
    [SerializeField]private Vector3 _BoundingPoints;
    [SerializeField]private Vector3 _BoundingBoxSize;
    
    
    [Header("Debug")] 
    [SerializeField]private bool Debug = false;
    [SerializeField]private float BoundingScale = 1.0f;
    
    private uint[] mCharacterID;
    private Light mMainLight;
    
    void Start()
    {
        mMainLight = RenderSettings.sun;
        
        mCharacterID = new uint[_Characters.Length];
        for (int i = 0; i < _Characters.Length; i++)
        {
            var r = _Characters[i].GetComponentInChildren<SkinnedMeshRenderer>();
            mCharacterID[i] = r.renderingLayerMask;
        }
        CharacterShadowData.CleanData();
    }
    
    void Update()
    {
        CharacterShadowData.CleanData();
        if (_Characters.Length == 0) return;
        UpdatePerCharacterData();
    }

    private void UpdatePerCharacterData()
    {
        for (int i = 0; i < _Characters.Length; i++)
        {
            float zfar = 15f;
            Vector3 targetPos = _Characters[i].transform.position + _BoundingPoints - mMainLight.transform.forward * 10f;

            Matrix4x4 viewMatrix = Matrix4x4.TRS(targetPos, mMainLight.transform.rotation, Vector3.one).inverse;
            Matrix4x4 projMatrix = Matrix4x4.Ortho(-_BoundingBoxSize.x, _BoundingBoxSize.x, -_BoundingBoxSize.y, _BoundingBoxSize.y, 5f, zfar);

            if (SystemInfo.usesReversedZBuffer)
            {
                viewMatrix.m20 *= -1;
                viewMatrix.m21 *= -1;
                viewMatrix.m22 *= -1;
                viewMatrix.m23 *= -1;
            }
            
            Matrix4x4 worldMatrix = Matrix4x4.TRS(targetPos, mMainLight.transform.rotation, new Vector3(_BoundingBoxSize.x * 2, _BoundingBoxSize.y * 2, zfar * 2));
            
            CharacterShadowStruct data = new CharacterShadowStruct();
            data.characterID = mCharacterID[i];
            data.viewMatrix = viewMatrix;
            data.projectionMatrix = projMatrix;
            data.worldMatrix = worldMatrix;
            CharacterShadowData.AddData(data);
            
        }
    }
    
    private void OnDrawGizmos()
    {
        if (!Application.isPlaying) return;
        if (Debug)
        {
            Gizmos.color = Color.red;
            for (int i = 0; i < _Characters.Length; i++)
            {
                Vector3 targetPos = _Characters[i].transform.position + _BoundingPoints - mMainLight.transform.forward * 10f;
                Vector3 orginPos = _Characters[i].transform.position + _BoundingPoints;
                //Camera
                Gizmos.DrawWireCube(targetPos, new Vector3(BoundingScale, BoundingScale, BoundingScale));
                //Focus Point
                Gizmos.DrawWireSphere(orginPos, BoundingScale * 0.1f);
                //CameraRay
                Gizmos.DrawLine(orginPos, targetPos);
            }
            
            //Bounding Box
            Gizmos.color = Color.green;
            for (int i = 0; i < _Characters.Length; i++)
            {
                Vector3 orginPos = _Characters[i].transform.position + _BoundingPoints;
                Gizmos.DrawWireCube(orginPos, _BoundingBoxSize);
            }
        }
    }
}
