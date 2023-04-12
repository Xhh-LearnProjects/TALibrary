Shader "TALibrary/Biplanar"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" { }
        [Normal] _NormalTex ("NormalTex", 2D) = "bump" { }
        _Tilling ("Tilling", Range(0, 5)) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Back
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include "./Biplanar.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float _Tilling;
            CBUFFER_END

            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalTex);  SAMPLER(sampler_NormalTex);
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD2;
                float2 uv : TEXCOORD0;
                float3 normalWS : NORMAL;
                half4 tangentWS : TEXCOORD3;    // xyz: tangent, w: sign

            };

            
            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.uv = input.uv;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = normalInput.normalWS;
                real sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = half4(normalInput.tangentWS, sign);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float3 worldUV = input.positionWS / _Tilling;
                input.normalWS = normalize(input.normalWS);
                
                half4 finalColor = 0;
                Biplanar_float(_MainTex, sampler_MainTex, worldUV, input.normalWS, finalColor);

                float3 normalTS = 0;
                float sgn = input.tangentWS.w;      // should be either +1 or -1
                float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                BiplanarNormal_float(_NormalTex, sampler_NormalTex, worldUV, input.tangentWS.xyz, bitangent, input.normalWS, normalTS);
                
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
                float3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);

                InputData inputData = (InputData)0;
                inputData.normalWS = normalWS;
                inputData.positionWS = input.positionWS;
                inputData.positionCS = input.positionCS;
                inputData.tangentToWorld = tangentToWorld;
                inputData.bakedGI = SampleSH(normalWS);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = finalColor;
                surfaceData.alpha = 1;
                surfaceData.occlusion = 1;
                surfaceData.metallic = 0;
                surfaceData.smoothness = 0;
                surfaceData.normalTS = normalTS;
                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                return color;
            }
            
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}