using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LiquidPoolManager : MonoBehaviour
{
    public static LiquidPoolManager Instance { get; private set; }

    [SerializeField]private Transform poolParent;
    [SerializeField] private Transform spawner;

    private Queue<Transform> pool;
    public List<Transform> activeSpheres;

    public int poolSize;

    private float lastSpawnTime;

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
        pool = new Queue<Transform>();
        for (int i = 0; i < poolParent.childCount; i++)
        {
            pool.Enqueue(poolParent.GetChild(i));
        }
        poolSize = pool.Count;
    }

    private void Update()
    {
        if(Input.GetKey(KeyCode.S))
        {
            if(pool.Count > 0 && Time.time - lastSpawnTime > 0.02f)
            {
                EnableSphereFromPool();
                lastSpawnTime = Time.time;
            }
        }
    }

    public void DisableSphere(Transform t)
    {
        t.gameObject.SetActive(false);
        activeSpheres.Remove(t);
        pool.Enqueue(t);
    }
    
    public void EnableSphereFromPool()
    {
        for (int i = 0; i < 360; i+=36)
        {
            Transform t = pool.Dequeue();
            activeSpheres.Add(t);
            t.position = spawner.position + new Vector3(Mathf.Cos(i), 0, Mathf.Sin(i)) * 0.1f;
            t.gameObject.SetActive(true);
        }
    }

    private void OnApplicationQuit()
    {
        activeSpheres.Clear();
    }
}
