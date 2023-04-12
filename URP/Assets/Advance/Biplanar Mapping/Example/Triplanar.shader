// 这是一个普通的三平面映射
Shader "TALibrary/Triplanar"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" { }
        [Normal] _NormalTex ("NormalTex", 2D) = "bump" { }
        _Tilling ("Tilling", Range(0, 5)) = 1
        _Smooth ("Smooth", Range(0, 10)) = 1
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
            
            CBUFFER_START(UnityPerMaterial)
                float _Tilling;
                float _Smooth;
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


            void TriPlanar_float(Texture2D tex, SamplerState samp, float3 posWS, half3 normal, float smooth, out float4 output)
            {
                half3 normalWS = normalize(normal);
                // half3 weight = abs(normalWS);
                half3 weight = pow(abs(normalWS), smooth);
                half3 uvWeight = weight / (weight.x + weight.y + weight.z);

                half4 colorUp = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, posWS.xz) * uvWeight.y;
                half4 colorLeft = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, posWS.xy) * uvWeight.z;
                half4 colorForward = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, posWS.yz) * uvWeight.x;

                output = colorUp + colorLeft + colorForward;
            }

            void TriplanarNormal_float(Texture2D tex, SamplerState samp, float3 posWS, half3 normal, half3 tangent, half3 bitangent, float smooth, out float3 output)
            {
                half3 normalWS = normalize(normal);
                // half3 weight = abs(normalWS);
                half3 weight = pow(abs(normalWS), smooth);
                half3 uvWeight = weight / (weight.x + weight.y + weight.z);

                float3 normalTSUp = UnpackNormal(SAMPLE_TEXTURE2D(tex, samp, posWS.xz)) * uvWeight.y;
                float3 normalTSLeft = UnpackNormal(SAMPLE_TEXTURE2D(tex, samp, posWS.xy)) * uvWeight.z;
                float3 normalTSForward = UnpackNormal(SAMPLE_TEXTURE2D(tex, samp, posWS.yz)) * uvWeight.x;

                output = normalTSUp + normalTSLeft + normalTSForward;
            }


            half4 frag(Varyings input) : SV_Target
            {
                float3 worldUV = input.positionWS / _Tilling;
                input.normalWS = normalize(input.normalWS);

                half4 finalColor = 0;
                TriPlanar_float(_MainTex, sampler_MainTex, worldUV, input.normalWS, _Smooth, finalColor);

                float3 normalTS = 0;
                float sgn = input.tangentWS.w;      // should be either +1 or -1
                float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                TriplanarNormal_float(_NormalTex, sampler_NormalTex, worldUV, input.normalWS, input.tangentWS, bitangent, _Smooth, normalTS);

                //这里bitanget 用abs处理 避免转角处法线反转的问题
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, abs(bitangent.xyz), input.normalWS.xyz);
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