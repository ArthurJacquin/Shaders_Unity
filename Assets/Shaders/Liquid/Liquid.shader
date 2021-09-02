Shader "Hidden/Raymarching/Liquid"
{
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Assets/Shaders/Raymarching/DistanceFunctions.hlsl"

        TEXTURE2D_X(_MainTex);

        float _Intensity;

        //Camera
        uniform float4x4 _CamInvProj;
        uniform float3 _camPos;
        uniform float _maxDistance;
        uniform int _maxIterations;
        uniform float _accuracy;

        //Spheres
        uniform float3 pos;

        //Shadows
        uniform float _shadowIntensity;
        uniform float2 _shadowDistance;
        uniform float _shadowPenumbra;

        //Lighting
        uniform float _glossiness;

        //Inputs
        struct Attributes
        {
            uint vertexID : SV_VertexID;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord   : TEXCOORD0;
            float3 viewVector : TEXCOORD1;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        Varyings Vert(Attributes input)
        {
            Varyings output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            
            output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
            output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);

            output.viewVector = mul(_CamInvProj, float4(output.texcoord * 2 - 1, 0, 1));
            output.viewVector = mul(UNITY_MATRIX_I_V, float4(output.viewVector, 0));

            return output;
        }

        //Distance
        float4 GetDist(float3 p)
        {
            float4 sphereDist = float4(float3(1, 1, 1), sdSphere(p - pos, 1.0)); //TODO : color
            return sphereDist;
        }

        //Raymarch step
        bool RayMarch(float3 ro, float3 rd, float depth, inout float d)
        {
            d = 0.; //Distane Origin
            for (int i = 0; i < _maxIterations; i++)
            {
                if (d > _maxDistance || d >= depth) //No hit
                    return false;

                float3 p = ro + rd * d; //New position

                float ds = GetDist(p).w; // ds is Distance Scene
                if (ds < _accuracy) //Hit
                {
                    //TODO : set color
                    break;
                }

                d += ds; //Next step
            }

            return true;
        }

        //Normal
        float3 GetNormal(float3 p)
        {
            float d = GetDist(p).w; // Distance
            float2 e = float2(.01, 0); // Epsilon
            float3 n = d - float3(
                GetDist(p - e.xyy).w,
                GetDist(p - e.yxy).w,
                GetDist(p - e.yyx).w);

            return normalize(n);
        }

        //Shadows
        float softShadow(float3 ro, float3 rd, float minT, float maxT, float k)
        {
            float result = 1.0;

            for (float t = minT; t < maxT;)
            {
                float h = GetDist(ro + rd * t).w;
                if (h < 0.001)
                {
                    return 0.0;
                }
                result = min(result, k * h / t);

                t += h;
            }

            return result;
        }

        float hardShadow(float3 ro, float3 rd, float minT, float maxT)
        {
            for (float t = minT; t < maxT;)
            {
                float h = GetDist(ro + rd * t).w;
                if (h < 0.001)
                {
                    return 0.0;
                }

                t += h;
            }

            return 1.0;
        }

        //Shading
        float3 Shading(float3 p, float3 n, float3 c)
        {
            float3 result;

            //Diffuse color
            float3 color = c.rgb;

            //Directional light
            Light mainLight = GetMainLight();
            float3 light = (dot(-mainLight.direction, n) * 0.5 + 0.5) * mainLight.color;

            // GGX NDF = > Specular
            float3 halfDir = normalize(mainLight.direction + _WorldSpaceCameraPos);
            float specAngle = max(dot(halfDir, n), 0.0);
            float specular = pow(specAngle, _glossiness * 10);

            //Shadows
            float shadow = softShadow(p, -mainLight.direction, _shadowDistance.x, _shadowDistance.y, _shadowPenumbra) * 0.5 + 0.5;
            shadow = max(0.0, pow(shadow, _shadowIntensity));

            shadow = hardShadow(p, -mainLight.direction, _shadowDistance.x, _shadowDistance.y);
            result = color * light * shadow + (specular * c.rgb);
            return result;
        }

        float4 Frag(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            
            float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord);
            float4 sceneColor = LOAD_TEXTURE2D_X(_MainTex, uv * _ScreenSize.xy);

            //Setup ray
            float3 rayOrigin = _WorldSpaceCameraPos; // Ray Origin/Camera
            float viewLength = length(input.viewVector);
            float3 rayDir = input.viewVector / viewLength; // Ray Direction
            
            // Depth
            float depth = SampleSceneDepth(input.texcoord);
            depth = LinearEyeDepth(depth, _ZBufferParams) * viewLength;

            //Raymarch
            float HitPos; 
            float3 color = float3(0.08, 0.81, 1);
            bool hit = RayMarch(rayOrigin, rayDir, depth, HitPos);

            float4 result; 
            if (hit)
            {
                //Shading
                float3 n = GetNormal(HitPos);
                float3 s = Shading(HitPos, n, color);
                result = float4(s, 1);
            }
            else 
            {
               result = float4(0, 0, 0, 0);
            }

            return float4(sceneColor * (1.0 - result.w) + result.xyz * result.w, 1.0);
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        
         Pass
        {
            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment Frag
            ENDHLSL
        }
    }
    Fallback Off
}