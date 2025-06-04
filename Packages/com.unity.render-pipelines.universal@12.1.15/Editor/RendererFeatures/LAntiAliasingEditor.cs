using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEditor.Rendering.Universal
{
    [CustomEditor(typeof(LAntiAliasing))]
    internal class LAntiAliasingEditor : Editor
    {
        private SerializedProperty m_AAType;
        private SerializedProperty m_FXAAQuality;
        private SerializedProperty m_FXAAComputeMode;
        private SerializedProperty m_FXAAEdgeThresholdMin;
        private SerializedProperty m_FXAAEdgeThreshold;
        private SerializedProperty m_TAADepthTextureMode;
        
        private bool m_IsInitialized = false;
        
        private struct Styles
        {
            public static GUIContent AAType = EditorGUIUtility.TrTextContent("抗锯齿类型", "抗锯齿的类型,目前仅支持FXAA");
            public static GUIContent FXAAQuality = EditorGUIUtility.TrTextContent("质量", "FXAA的质量");
            public static GUIContent FXAAEdgeThresholdMin = EditorGUIUtility.TrTextContent("边缘阈值最小值", "最小能进入FXAA的阈值,计算公式为min(最小值,边缘阈值)");
            public static GUIContent FXAAEdgeThreshold = EditorGUIUtility.TrTextContent("边缘阈值百分比", "FXAA的边缘阈值权重,边缘阈值 = FXAA当前像素最大亮度 * 边缘阈值百分比");
            public static GUIContent FXAAComputeMode = EditorGUIUtility.TrTextContent("计算模式", "FXAA的计算模式,快速为直接使用G通道作为亮度,准确为正常使用Luminance公式计算亮度");
            public static GUIContent TAADepthTextureMode = EditorGUIUtility.TrTextContent("深度模式", "对应RenderData DepthTextureMode");
        }

        private void Init()
        {
            SerializedProperty settings = serializedObject.FindProperty("mSettings");
            m_AAType = settings.FindPropertyRelative("AAType");
            m_FXAAQuality = settings.FindPropertyRelative("FXAAQuality");
            m_FXAAComputeMode = settings.FindPropertyRelative("FXAAComputeMode");
            m_FXAAEdgeThresholdMin = settings.FindPropertyRelative("FXAAEdgeThresholdMin");
            m_FXAAEdgeThreshold = settings.FindPropertyRelative("FXAAEdgeThreshold");
            m_TAADepthTextureMode = settings.FindPropertyRelative("TAADepthTextureMode");
            
            m_IsInitialized = true;
        }
        
        public override void OnInspectorGUI()   
        {
            if (!m_IsInitialized)
            {
                Init();
            }
            EditorGUILayout.PropertyField(m_AAType, Styles.AAType);
            
            var currentType = (LAntiAliasingSettings.Type)m_AAType.enumValueIndex;
            switch (currentType)
            {
                case LAntiAliasingSettings.Type.FXAA:
                    EditorGUILayout.Space();
                    EditorGUILayout.LabelField("FXAA设置栏", EditorStyles.boldLabel);
                    EditorGUI.indentLevel++;
                    EditorGUILayout.PropertyField(m_FXAAQuality, Styles.FXAAQuality);
                    EditorGUILayout.PropertyField(m_FXAAComputeMode, Styles.FXAAComputeMode);
                    m_FXAAEdgeThresholdMin.floatValue = EditorGUILayout.Slider(Styles.FXAAEdgeThresholdMin,m_FXAAEdgeThresholdMin.floatValue, 0.0f,1.0f);
                    m_FXAAEdgeThreshold.floatValue    = EditorGUILayout.Slider(Styles.FXAAEdgeThreshold, m_FXAAEdgeThreshold.floatValue, 0.0f,1.0f);
                    break;
                case LAntiAliasingSettings.Type.TAA:
                    EditorGUILayout.Space();
                    EditorGUILayout.LabelField("TAA设置栏", EditorStyles.boldLabel);
                    EditorGUI.indentLevel++;
                    EditorGUILayout.PropertyField(m_TAADepthTextureMode, Styles.TAADepthTextureMode);
                    break;
            }
        }
    }    
}

