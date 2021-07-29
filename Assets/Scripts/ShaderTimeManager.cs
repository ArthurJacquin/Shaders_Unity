using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShaderTimeManager : MonoBehaviour
{
    [SerializeField] List<Renderer> renderers;
    [SerializeField] int materialID;
    private float time;

    private void Update()
    {
        time += Time.deltaTime;

        foreach (Renderer r in renderers)
        {
            r.materials[materialID].SetFloat("_TimeAnim", time);
        }
    }

    public void ResetTime()
    {
        time = 0f;
    }

}
