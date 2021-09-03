using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class LiquidPoolManager : MonoBehaviour
{
    public static LiquidPoolManager Instance { get; private set; }

    [SerializeField]private Transform poolParent;
    public List<Transform> pool { get; private set; }
    public int poolSize
    {
        get { return pool.Count; }
    }

    void Awake()
    {
        if (Instance == null) 
        { 
            Instance = this; 
        }
        else 
        { 
            Debug.Log("Warning: multiple " + this + " in scene!"); 
        }
    }

    private void Start()
    {
        pool = new List<Transform>();
        for (int i = 0; i < poolParent.childCount; i++)
        {
            pool.Add(poolParent.GetChild(i));
            pool[i].position = poolParent.position + new Vector3(0, 0.05f, 0) * i;
        }
    }

    private void Update()
    {
        
    }
}
