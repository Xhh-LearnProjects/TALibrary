Shader "TALibrary/World-Oriented Billboard"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "gary" { }
        [Toggle]_TransformInView ("变换应用与观察视角", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Transparent" }

        //效果上，不会跟随相机的z轴旋转，会有畸形或形变，物理正确的,但从顶或底部越过时，物体会发生旋转
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha, One Zero
            Cull Off
            ZWrite Off

            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            #pragma shader_feature _TRANSFORMINVIEW_ON
            
            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };


            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };


            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;;
                output.uv = input.uv;

                //先缩放旋转，再乘新空间矩阵，则缩放，旋转位于新空间下
                #ifdef _TRANSFORMINVIEW_ON
                    float3 centerPosWS = TransformObjectToWorld(float3(0, 0, 0));
                    float3 newPosWS = mul((float3x3)UNITY_MATRIX_M, input.positionOS); //应用缩放

                    float3 forward = - (_WorldSpaceCameraPos - centerPosWS);
                    forward = SafeNormalize(forward);
                    float3 up = abs(forward.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                    float3 right = SafeNormalize(cross(up, forward));
                    up = SafeNormalize(cross(forward, right));
                    float3x3 newWorldMatrix = float3x3(right, up, forward); //世界空间的旋转矩阵/新空间标准正交基
                    newWorldMatrix = transpose(newWorldMatrix);

                    float3 posWS = mul(newWorldMatrix, newPosWS) + centerPosWS;
                    output.positionCS = TransformWorldToHClip(posWS);
                #else
                    //先乘新空间矩阵，再缩放，旋转，则缩放，旋转位于世界空间下
                    float3 centerPosWS = TransformObjectToWorld(float3(0, 0, 0));
                    float3 forward = - (_WorldSpaceCameraPos - centerPosWS);
                    forward = SafeNormalize(forward);
                    float3 up = abs(forward.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                    float3 right = SafeNormalize(cross(up, forward));
                    up = SafeNormalize(cross(forward, right));
                    float3x3 newLocalMatrix = float3x3(right, up, forward); //世界空间的旋转矩阵/新空间标准正交基
                    newLocalMatrix = transpose(newLocalMatrix);

                    float3 posOS = mul(newLocalMatrix, input.positionOS);
                    output.positionCS = TransformObjectToHClip(posOS);
                #endif

                return output;
            }


            half4 frag(Varyings input) : SV_Target
            {
                half4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                return var_MainTex;
            }
            
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}