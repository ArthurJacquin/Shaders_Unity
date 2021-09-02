Shader "Hidden/Raymarching/Liquid"
{
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Assets/Shaders/Raymarching/RaymarchingFunctions.hlsl"

        TEXTURE2D_X(_MainTex);

        float _Intensity;

        //Camera
        //uniform sampler2D _CameraDepthTexture;
        uniform float4x4 _CamInvProj;
        uniform float4x4 _CamToWorld;
        uniform float3 _camPos;
        uniform float _maxDistance;
        uniform int _maxIterations;
        uniform float _accuracy;

        struct Attributes
        {
            uint vertexID : SV_VertexID;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord   : TEXCOORD0;
            float3 ray : TEXCOORD1;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        Varyings Vert(Attributes input)
        {
            Varyings output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            
            output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
            output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);

            output.ray = mul(_CamInvProj, float4(output.texcoord * 2 - 1, 0, 1));
            output.ray = mul(UNITY_MATRIX_I_V, float4(output.ray, 0));

            return output;
        }

        float4 Frag(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            
            float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord);
            float4 sceneColor = LOAD_TEXTURE2D_X(_MainTex, uv * _ScreenSize.xy);

            float3 ro = _camPos; // Ray Origin/Camera
            float3 rd = input.ray; // Ray Direction
            float HitDist; //Distance of the hit
            bool hit = RayMarch(ro, rd, _maxIterations, _maxDistance, _accuracy, HitDist); // Distance

            float4 result; 
            
            if (hit)
            {
                result = float4(1, 1, 1, 1);
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