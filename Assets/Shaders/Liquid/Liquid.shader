Shader "Hidden/Raymarching/Liquid"
{
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
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
        uniform sampler1D _spheresData;
        uniform int _nbSphere;
        uniform int _poolSize;
        uniform float _sphereSmooth;

        //Lighting
        uniform float _glossiness;
        uniform float _metallic;
        uniform float _smoothness;

        //Inputs
        struct Attributes
        {
            uint vertexID : SV_VertexID;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Varyings
        {
            float2 uv                       : TEXCOORD0;
            float3 viewVector               : TEXCOORD1;
            float4 positionCS               : SV_POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        /*void InitializeInputData(Varyings input, float3 posWS, half3 normalWS, half3 viewDirWS, out InputData inputData)
        {
            inputData = (InputData)0;

            inputData.positionWS = posWS;
            inputData.normalWS = NormalizeNormalPerPixel(normalWS);
            inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
            inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

            inputData.fogCoord = input.fogFactorAndVertexLight.x;
            inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
            inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
            inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
            inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
        }*/


        //Distance
        //Return a float4 with color in XYZ and distance in W
        float4 GetDist(float3 p)
        {
            float q = 1.0f / float(_poolSize - 1);
            //TODO : color
            float4 sphereDist = float4(float3(1, 1, 1), sdSphere(p - tex1Dlod(_spheresData, 0).xyz * 1000.0, tex1Dlod(_spheresData, 0).w * 1000.0)); 
            
            float4 result = sphereDist;
            for (int i = 1; i < _nbSphere; i++)
            {
                //Distance
                sphereDist = float4(float3(1, 1, 1), sdSphere(p - tex1Dlod(_spheresData, i * q).xyz * 1000.0, tex1Dlod(_spheresData, i * q).w * 1000.0));

                result = opUS(result, sphereDist, _sphereSmooth);
            }
            
            return result;
        }

        //Raymarch step
        bool RayMarch(float3 ro, float3 rd, float depth, inout float3 p)
        {
            float d = 0.; //Distane Origin
            for (int i = 0; i < _maxIterations; i++)
            {
                if (d > _maxDistance || d >= depth) //No hit
                    return false;

                p = ro + rd * d; //New position

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

        //Shading
        float3 Shading(float3 p, float3 n, float3 viewDir, float3 c)
        {
            Light mainLight = GetMainLight();
            half alpha = 1;

            BRDFData brdfData;
            InitializeBRDFData(c, _metallic, c, _smoothness, alpha, brdfData);

            half3 color = LightingPhysicallyBased(brdfData, mainLight, n, viewDir, false);

            //TODO : better shading + GI
            //SurfaceData surfaceData;
            //InitializeStandardLitSurfaceData(input.uv, surfaceData);
            //
            //InputData inputData;
            //InitializeInputData(input, p, n, viewDir, inputData);
            //
            //half4 color = UniversalFragmentPBR(inputData, surfaceData);

            return color;
        }

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

        Varyings Vert(Attributes input)
        {
            Varyings output = (Varyings)0;

            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input, output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            
            output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
            output.uv = GetFullScreenTriangleTexCoord(input.vertexID);

            output.viewVector = mul(_CamInvProj, float4(output.uv * 2 - 1, 0, 1));
            output.viewVector = mul(UNITY_MATRIX_I_V, float4(output.viewVector, 0));

            return output;
        }

        float4 Frag(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            
            float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
            float4 sceneColor = LOAD_TEXTURE2D_X(_MainTex, uv * _ScreenSize.xy);

            if (_nbSphere == 0) //No sphere -> do nothing
                return sceneColor;

            //Setup ray
            float3 rayOrigin = _WorldSpaceCameraPos; // Ray Origin/Camera
            float viewLength = length(input.viewVector);
            float3 rayDir = input.viewVector / viewLength; // Ray Direction
            
            // Depth
            float depth = SampleSceneDepth(input.uv);
            depth = LinearEyeDepth(depth, _ZBufferParams) * viewLength;

            //Raymarch
            float3 HitPos; 
            float3 color = float3(0.08, 0.81, 1);
            bool hit = RayMarch(rayOrigin, rayDir, depth, HitPos);

            float4 result; 
            if (hit)
            {
                //Shading
                float3 n = GetNormal(HitPos);
                float3 s = Shading(HitPos, n, rayDir, color);
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