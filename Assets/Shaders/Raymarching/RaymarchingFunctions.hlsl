#include "DistanceFunctions.hlsl"

//Distance
float GetDist(float3 p) 
{
    float sphereDist = sdSphere(p - float3(0., 0., 4.), 1.0);
    return sphereDist;
}
 
//Raymarch step
bool RayMarch(float3 ro, float3 rd, const int MAX_STEPS, const float MAX_DIST, const float ACCURACY, out float d)
{
    d = 0.; //Distane Origin
    for(int i = 0; i < MAX_STEPS; i++)
    {
        float3 p = ro + rd * d;
        float ds = GetDist(p); // ds is Distance Scene
        d += ds;
    
        if (d > MAX_DIST) //No hit
            return false;
        
        if(ds < ACCURACY) //Hit
            break;
    }
    return true;
}

//Normal
float3 GetNormal(float3 p)
{ 
    float d = GetDist(p); // Distance
    float2 e = float2(.01, 0); // Epsilon
    float3 n = d - float3(
    GetDist(p-e.xyy),
    GetDist(p-e.yxy),
    GetDist(p-e.yyx));
 
    return normalize(n);
}