Shader "TALibrary/Plane Reflection"
{
    Properties
    {
        [Foldout(1, 1, 0, 1)] _F_Base ("基础_Foldout", float) = 1
        _ShadowLerpWhite ("阴影淡化", Range(0, 1)) = 0.5

        _MirrorPosX ("对称中心X（在屏幕上）", Range(0, 1)) = 0.5
        _MirrorPosY ("对称中心Y（在屏幕上）", Range(0, 1)) = 0.5
        _MirrorFadeCurve ("镜面渐隐 曲线", Range(0.1, 5)) = 1.25
        _MirrorFadeIntensity ("镜面渐隐 亮度", Float) = 16.25

        _Roughness ("粗糙度", Range(0, 1)) = 0
        [Foldout_Out(1)] _F_Base_Out ("F_BaseTexChannel_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Debug ("Debug_Foldout", float) = 1
        [Toggle_Switch] _DebugCenterPos ("显示中心坐标", Float) = 0
        [Foldout_Out(1)] _F_Debug_Out ("_F_Debug_Out_Foldout", float) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float _ShadowLerpWhite;
            float _MirrorPosX;
            float _MirrorPosY;
            float _MirrorFadeCurve;
            float _MirrorFadeIntensity;
            float _Roughness;
        CBUFFER_END
        ENDHLSL

        Pass
        {

            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            // Blend Zero SrcColor
            Blend SrcAlpha OneMinusSrcAlpha

            ZWrite Off
            Cull Back


            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _DEBUGCENTERPOS_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            struct a2v
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };


            TEXTURE2D(_GrabTexture);                SAMPLER(sampler_GrabTexture);
            TEXTURE2D(_CameraColorTexture);         SAMPLER(sampler_CameraColorTexture);
            TEXTURE2D_X_FLOAT(_CharMaskRT);         SAMPLER(sampler_CharMaskRT);

            v2f vert(a2v v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                float3 positionOS = v.positionOS.xyz;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(positionOS);
                o.positionWS = positionInputs.positionWS;
                o.positionCS = positionInputs.positionCS;

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                float finalAlpha = 1;
                half3 finalColor = 1;

                float2 screenUV = i.positionCS.xy * (_ScaledScreenParams.zw - 1.0);

                // shadow
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                float shadow = MainLightRealtimeShadow(shadowCoord);
                shadow = lerp(shadow, 1, _ShadowLerpWhite);

                // 常规向量
                float3 normalWS = normalize(i.normalWS);
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);

                float NdotV = abs(dot(normalWS, viewDirectionWS));
                // 菲涅尔
                float fresnelTerm = Pow4(1.0 - NdotV) * (1.0 - NdotV);

                // EnvironmentBRDFSpecular，但是去掉grazingTerm
                float roughness2 = max(_Roughness * _Roughness, HALF_MIN);
                float surfaceReduction = 1.0 / (roughness2 + 1.0);

                // 模拟平面反射
                float2 mirrorPos = float2(_MirrorPosX, _MirrorPosY);
                float2 grabUV = screenUV;
                grabUV.y = grabUV.y * (-1) + mirrorPos.y * 2;
                half3 mirrorGrabTex = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, grabUV).rgb;

                // 模拟平面反射的视角渐隐
                float yFade = 1.0 - saturate(pow(abs(screenUV.y - mirrorPos.y), _MirrorFadeCurve) * _MirrorFadeIntensity);

                // 初步确定最终alpha
                finalAlpha = fresnelTerm * surfaceReduction * yFade;

                // float mirrorTestChar = SAMPLE_TEXTURE2D(_CharMaskRT, sampler_CharMaskRT, grabUV).r;
                // bool isMirrorCharacter = mirrorTestChar > 0.1;
                // if (isMirrorCharacter == false)
                // {
                //     mirrorGrabTex = 0;
                //     finalAlpha = 0;
                // }

                finalColor = mirrorGrabTex.rgb;

                // shadow
                finalColor = finalColor * shadow;
                finalAlpha = lerp(0.5, finalAlpha, shadow);

                // debug角色对称中心
                #ifdef _DEBUGCENTERPOS_ON
                    finalColor = (1.0 - saturate(pow(length(screenUV - mirrorPos.xy), 1) * 50)) * half3(1, 0, 0);
                    finalAlpha = 1;
                #endif

                return half4(finalColor, finalAlpha);
            }
            ENDHLSL
        }
    }
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
