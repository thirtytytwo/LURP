using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEditor.Rendering.Universal
{
    [VolumeComponentEditor(typeof(Bloom))]
    sealed class BloomEditor : VolumeComponentEditor
    {
        SerializedDataParameter m_Threshold;
        SerializedDataParameter m_Intensity;
        SerializedDataParameter m_Scatter;
        SerializedDataParameter m_Clamp;
        SerializedDataParameter m_Tint;
        SerializedDataParameter m_BloomKernal;

        public override void OnEnable()
        {
            var o = new PropertyFetcher<Bloom>(serializedObject);

            m_Threshold = Unpack(o.Find(x => x.threshold));
            m_Intensity = Unpack(o.Find(x => x.intensity));
            m_Scatter = Unpack(o.Find(x => x.scatter));
            m_Clamp = Unpack(o.Find(x => x.clamp));
            m_Tint = Unpack(o.Find(x => x.tint));
            m_BloomKernal = Unpack(o.Find(x => x.bloomDefaultKernal));
        }

        public override void OnInspectorGUI()
        {
            PropertyField(m_Threshold);
            PropertyField(m_Intensity);
            PropertyField(m_Scatter);
            PropertyField(m_Clamp);
            PropertyField(m_Tint);
            PropertyField(m_BloomKernal);
        }
    }
}
