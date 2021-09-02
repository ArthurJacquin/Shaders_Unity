// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

// BOOLEAN OPERATORS //

// Union
float4 opU(float4 d1, float4 d2)
{
	return (d1.w < d2.w) ? d1 : d2;
}

// Subtraction
float4 opS(float4 d1, float4 d2)
{
	return max(-d1.w, d2.w);
}

// Intersection
float4 opI(float4 d1, float4 d2)
{
	return max(d1.w, d2.w);
}

// Mod Position Axis
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}


// SMOOTH BOOLEAN OPERATORS //

// Union smooth
float4 opUS(float4 d1, float4 d2, float k) 
{
	float h = clamp(0.5 + 0.5*(d2.w - d1.w) / k, 0.0, 1.0);
	float3 color = lerp(d2.rgb, d1.rgb, h);
	float dist = lerp(d2.w, d1.w, h) - k * h * (1.0 - h);

	return float4(color, dist);
}

//Subtraction smooth
float4 opSS(float4 d1, float4 d2, float k)
{
	float h = clamp(0.5 - 0.5*(d2.w + d1.w) / k, 0.0, 1.0);
	float3 color = lerp(d2.rgb, d1.rgb, h);
	float dist = lerp(d2.w, -d1.w, h) + k * h*(1.0 - h);

	return float4(color, dist);
}

//Intersect smooth
float4 opIS(float4 d1, float4 d2, float k)
{
	float h = clamp(0.5 - 0.5*(d2.w - d1.w) / k, 0.0, 1.0);
	float3 color = lerp(d2.rgb, d1.rgb, h);
	float dist = lerp(d2.w, d1.w, h) + k * h * (1.0 - h);

	return float4(color, dist);
}