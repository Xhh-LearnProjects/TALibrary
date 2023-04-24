Shader "TALibrary/Billboard/Screen-Aligned Billboard_FixedSize"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "gary" { }
        _Size ("Size", Vector) = (2, 1, 0, 0)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Transparent" }

        //效果上，会跟随相机的z轴旋转，公告牌始终平行视平面，无论处于视图哪个位置都不会有畸形或形变，看起来有时反物理,在NDC空间，固定大小
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

            
            CBUFFER_START(UnityPerMaterial)
                float4 _Size;
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
                
                if (_ProjectionParams.x < 0)
                    input.uv.y = 1 - input.uv.y;
                output.uv = input.uv;

                float4 centerPosCS = TransformObjectToHClip(float3(0, 0, 0));
                centerPosCS /= centerPosCS.w; //结果：[-1, 1],centerPosCS.w = 1
                float ratio = _ScreenParams.x / _ScreenParams.y;
                float2 size = input.positionOS.xy * _Size.xy;
                size.x = size.x / ratio;
                output.positionCS = centerPosCS;
                output.positionCS.xy += size;

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