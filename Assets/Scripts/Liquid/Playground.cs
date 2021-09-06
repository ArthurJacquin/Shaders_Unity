using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Playground : MonoBehaviour
{
    [SerializeField]Transform sphere;
    [SerializeField] float speed;

    private Vector3 sphereRotationPos;
    private void Start()
    {
        sphereRotationPos = sphere.position;
        sphere.position += new Vector3(0, 0, 0.1f);
    }

    // Update is called once per frame
    void Update()
    {
        sphere.RotateAround(sphereRotationPos, Vector3.up, speed * Time.deltaTime);
    }
}
