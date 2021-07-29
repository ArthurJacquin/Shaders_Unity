using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class TerrainCycleScript : MonoBehaviour
{
    [SerializeField] Transform bike;
    [SerializeField] Material terrainCycleMaterial;

    [Space]
    [Header("Shader properties")]
    [SerializeField] Vector3 _ClipAxis;
    [SerializeField] float _ClipDistance;

    private void Update()
    {
        terrainCycleMaterial.SetVector("_BikePosition", bike.position);
        terrainCycleMaterial.SetVector("_ClipAxis", _ClipAxis);
        terrainCycleMaterial.SetFloat("_ClipDistance", _ClipDistance);

    }
}
