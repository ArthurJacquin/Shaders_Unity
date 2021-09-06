using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LiquidCollision : MonoBehaviour
{
    private void OnCollisionEnter(Collision collision)
    {
        if(collision.gameObject.tag == "WaterDroplet")
        {
            LiquidPoolManager.Instance.DisableSphere(collision.transform);
        }
    }
}
