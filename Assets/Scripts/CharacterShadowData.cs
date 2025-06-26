using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public struct CharacterShadowStruct
{
    public uint characterID;
    public Matrix4x4 viewMatrix;
    public Matrix4x4 projectionMatrix;
    public Matrix4x4 worldMatrix;
}
public static class CharacterShadowData
{
    public static List<CharacterShadowStruct> characterShadowList = new List<CharacterShadowStruct>();

    public static void CleanData()
    {
        characterShadowList.Clear();
    }

    public static void AddData(CharacterShadowStruct data)
    {
        characterShadowList.Add(data);
    }

    public static CharacterShadowStruct[] GetCharacterShadowData()
    {
        return characterShadowList.ToArray();
    }
}
