Shader "TALibrary/Fake Interior"
{
    Properties
    {
        [Foldout(0, 2, 1, 1)] _F_Interior ("Interior_Foldout", float) = 1
        [Tex(_InteriorColor)] _InteriorTex ("贴图", 2D) = "white" { }
        [HideInInspector] _InteriorColor ("颜色", Color) = (1, 1, 1, 1)
        _InteriorIntensity ("强度", Range(0, 5)) = 1
        [Toggle_Switch] _UseInteriorBlur ("使用模糊图模拟粗糙度效果", float) = 0
        [Tex(_, _UseInteriorBlur)][NoScaleOffset] _InteriorBlurTex ("模糊贴图", 2D) = "white" { }

        [Foldout(1, 2, 1, 0)] _F_InteriorAtlas ("图集_Foldout", float) = 0
        _InteriorXCount ("横向多少张", Float) = 1.0
        _InteriorYCount ("纵向多少张", Float) = 1.0
        _InteriorIndex ("坐标序号", Float) = 0.0
        [Foldout_Out(1)] _F_InteriorAtlas_Out ("F_InteriorAtlas_Out_Foldout", float) = 1

        [Foldout(1, 2, 0, 1)] _F_InteriorSpaceParams ("体积相关_Foldout", float) = 1
        _InteriorWidthRate ("宽高比", Float) = 1.0
        _InteriorXYScale ("深度", Range(0.0, 2.0)) = 1.0
        _InteriorDepth ("远平面位置", Range(0.001, 0.999)) = 0.5
        [Toggle_Switch] _InteriorDepthDebug ("远平面位置Debug", float) = 0
        [Foldout_Out(1)] _F_InteriorSpaceParams_Out ("F_InteriorSpaceParams_Out_Foldout", float) = 1


        [Foldout(1, 2, 1, 1)] _F_InteriorDecal ("窗户贴花_Foldout", float) = 0
        [Tex(_)] _InteriorDecalTex ("贴图", 2D) = "black" { }
        [Toggle_Switch] _InteriorDecalUseTilling ("贴花Tilling", float) = 0
        _InteriorDecalDepth ("深度", Range(0.0, 0.5)) = 0.0
        [Toggle_Switch] _InteriorDecalUseNormalMap ("使用法线贴图", float) = 0
        [Tex(_InteriorDecalBumpScale, _InteriorDecalUseNormalMap)][NoScaleOffset] _InteriorDecalBumpMap ("法线贴图", 2D) = "bump" { }
        [HideInInspector]_InteriorDecalBumpScale ("法线缩放", Range(0, 1)) = 1.0
        [Toggle_Switch] _InteriorDecalUsePBR ("使用PBR", float) = 0
        [Tex(_, _InteriorDecalUsePBR)][NoScaleOffset] _InteriorDecalMetalMap ("金属光滑度贴图(RA)", 2D) = "white" { }
        [Switch(_InteriorDecalUsePBR)]_InteriorDecalMetallic ("金属度 (Metallic)", Range(0.0, 1.0)) = 0.5
        [Switch(_InteriorDecalUsePBR)]_InteriorDecalGlossiness ("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5
        [Foldout_Out(1)] _F_InteriorDecal_Out ("F_InteriorDecal_Out_Foldout", float) = 1


        [Foldout_Out(0)] _F_Interior_Out ("F_Interior_Out_Foldout", float) = 1
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

            #pragma shader_feature_local _F_INTERIOR_ON
            #pragma shader_feature_local_fragment _INTERIORDEPTHDEBUG_ON
            #pragma shader_feature_local_fragment _F_INTERIORATLAS_ON
            #pragma shader_feature_local_fragment _F_INTERIORDECAL_ON
            #pragma shader_feature_local_fragment _INTERIORDECALUSETILLING_ON
            #pragma shader_feature_local_fragment _INTERIORDECALUSENORMALMAP_ON
            #pragma shader_feature_local_fragment _INTERIORDECALUSEPBR_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _InteriorTex_ST;
                half _InteriorXCount;
                half _InteriorYCount;
                half _InteriorIndex;
                half _InteriorDepth;
                half _InteriorXYScale;
                half _InteriorWidthRate;
                half4 _InteriorColor;
                half _InteriorIntensity;


                float4 _InteriorDecalTex_ST;
                half _InteriorDecalDepth;
                half _InteriorDecalBumpScale;
                half _InteriorDecalMetallic;
                half _InteriorDecalGlossiness;
            CBUFFER_END

            TEXTURE2D(_InteriorTex);            SAMPLER(sampler_InteriorTex);
            TEXTURE2D(_InteriorBlurTex);        SAMPLER(sampler_InteriorBlurTex);

            // 假室内窗户贴花
            TEXTURE2D(_InteriorDecalTex);       SAMPLER(sampler_InteriorDecalTex);
            TEXTURE2D(_InteriorDecalBumpMap);   SAMPLER(sampler_InteriorDecalBumpMap);
            TEXTURE2D(_InteriorDecalMetalMap);  SAMPLER(sampler_InteriorDecalMetalMap);
            
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
                half3 viewDirTS : TEXCOORD7;
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

            //---------------------------------------------------------------------------------
            //bgolus's original source code: https://forum.unity.com/threads/interior-mapping.424676/#post-2751518
            //this reusable InteriorUVFunction.hlsl is created base on bgolus's original source code
            //for param "roomMaxDepth01Define": input 0.0001 if room is a "near 0 volume" room, input 0.9999 if room is a "near inf depth" room
            #ifdef _INTERIORDEPTHDEBUG_ON
                float2 ConvertOriginalRawUVToInteriorUV(float2 originalRawUV, float3 viewDirTangentSpace, float roomMaxDepth01Define, out float debugInterp)
            #else
                float2 ConvertOriginalRawUVToInteriorUV(float2 originalRawUV, float3 viewDirTangentSpace, float roomMaxDepth01Define)
            #endif
            {
                originalRawUV = originalRawUV * _InteriorTex_ST.xy + _InteriorTex_ST.zw;

                //remap [0,1] to [+inf,0]
                //->if input roomMaxDepth01Define = 0    -> depthScale = +inf   (0 volume room)
                //->if input roomMaxDepth01Define = 0.5  -> depthScale = 1
                //->if input roomMaxDepth01Define = 1    -> depthScale = 0              (inf depth room)
                float depthScale = rcp(roomMaxDepth01Define) - 1.0;

                //normalized box space is a space where room's min max corner = (-1,-1,-1) & (+1,+1,+1)
                //apply simple scale & translate to tangent space = transform tangent space to normalized box space

                //now prepare ray box intersection test's input data in normalized box space
                float3 viewRayStartPosBoxSpace = float3(originalRawUV * 2 - 1, -1); //normalized box space's ray start pos is on trinagle surface, where z = -1
                float3 viewRayDirBoxSpace = viewDirTangentSpace * float3(1, 1, -depthScale);//transform input ray dir from tangent space to normalized box space

                // 我们的假室内可以使用长方形图，这里应用宽高比
                float xyScale = max(_InteriorXYScale, 0.001);
                float xyRate = max(_InteriorWidthRate, 0.001);
                viewRayDirBoxSpace *= float3(xyScale, xyScale * xyRate, 1.0);

                //do ray & axis aligned box intersection test in normalized box space (all input transformed to normalized box space)
                //intersection test function used = https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
                //============================================================================
                float3 viewRayDirBoxSpaceRcp = rcp(viewRayDirBoxSpace);

                //hitRayLengthForSeperatedAxis means normalized box space depth hit per x/y/z plane seperated
                //(we dont care about near hit result here, we only want far hit result)
                float3 hitRayLengthForSeperatedAxis = abs(viewRayDirBoxSpaceRcp) - viewRayStartPosBoxSpace * viewRayDirBoxSpaceRcp;
                //shortestHitRayLength = normalized box space real hit ray length
                float shortestHitRayLength = min(min(hitRayLengthForSeperatedAxis.x, hitRayLengthForSeperatedAxis.y), hitRayLengthForSeperatedAxis.z);
                //normalized box Space real hit pos = rayOrigin + t * rayDir.
                float3 hitPosBoxSpace = viewRayStartPosBoxSpace + shortestHitRayLength * viewRayDirBoxSpace;
                //============================================================================

                // remap from [-1,1] to [0,1] room depth
                float interp = hitPosBoxSpace.z * 0.5 + 0.5;

                // 远平面debug显示
                #ifdef _INTERIORDEPTHDEBUG_ON
                    debugInterp = interp;
                #endif

                // account for perspective in "room" textures
                // assumes camera with an fov of 53.13 degrees (atan(0.5))
                //hard to explain, visual result = transform nonlinear depth back to linear
                float realZ = saturate(interp) / depthScale + 1;
                interp = 1.0 - (1.0 / realZ);
                interp *= depthScale + 1.0;

                //linear iterpolate from wall back to near
                float2 interiorUV = hitPosBoxSpace.xy * lerp(1.0, 1 - roomMaxDepth01Define, interp);

                //convert back to valid 0~1 uv, ready for user's tex2D() call
                interiorUV = interiorUV * 0.5 + 0.5;

                #ifdef _F_INTERIORATLAS_ON
                    // 我们的假室内可以用一张图上存多张
                    float4 atlasST = 0;
                    int index = (int)max(_InteriorIndex, 0);
                    int posy = floor(index / _InteriorXCount);
                    int posx = fmod(index, _InteriorXCount);
                    atlasST.xy = float2(1.0 / _InteriorXCount, 1.0 / _InteriorYCount);
                    atlasST.zw = atlasST.xy * float2((uint)posx, _InteriorYCount - 1 - (uint)posy);
                    interiorUV = interiorUV * atlasST.xy + atlasST.zw;
                #endif
                return interiorUV;
            }


            // --------------------------------------------------------------------------------------
            // 假室内窗户上的贴花
            #if _INTERIORDECALUSEPBR_ON
                void GlassCalculateInteriorDecal(float2 uv, float3 viewDirTangentSpace, Varyings input, InputData inputData, SurfaceData surfaceData, inout half3 color)
            #else
                void GlassCalculateInteriorDecal(float2 uv, float3 viewDirTangentSpace, Varyings input, SurfaceData surfaceData, inout half3 color)
            #endif
            {
                #if __RENDERMODE_OPAQUE && _F_INTERIORDECAL_ON
                    float2 decalUV = uv * _InteriorDecalTex_ST.xy + _InteriorDecalTex_ST.zw;
                    // 让窗户贴花可以有一个深度
                    // 有几层Tilling变换，为了保持深度正确，这里有一个稍复杂的长宽比矫正
                    decalUV -= (viewDirTangentSpace.xy / viewDirTangentSpace.z) * float2(_InteriorTex_ST.y * _InteriorDecalTex_ST.x, _InteriorWidthRate * _InteriorTex_ST.x * _InteriorDecalTex_ST.y) * _InteriorDecalDepth;

                    // 法线对interior的扰动
                    #if _NORMALMAP
                        float3 bump = normalize(surfaceData.normalTS);
                        decalUV += bump.xy;
                    #endif

                    float4 decalTex = SAMPLE_TEXTURE2D(_InteriorDecalTex, sampler_InteriorDecalTex, decalUV);
                    #ifndef _INTERIORDECALUSETILLING_ON
                        bool offScreen = any(abs(decalUV.xy * 2 - 1) >= 1.0f);
                        if (offScreen)
                            decalTex = 0;
                    #endif
                    float decalAlpha = decalTex.a;
                    float3 decalColor = decalTex.rgb;

                    // decal的所有PBR部分将使用half计算。希望尽量少消耗。

                    // 使用法线贴图 ?
                    #if _INTERIORDECALUSENORMALMAP_ON
                        half4 normalMap = SAMPLE_TEXTURE2D(_InteriorDecalBumpMap, sampler_InteriorDecalBumpMap, decalUV);
                        half3 normalTS = UnpackNormalScale(normalMap, _InteriorDecalBumpScale);
                        half sgn = input.tangentWS.w;      // should be either +1 or -1
                        half3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                        half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
                        half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
                    #else
                        half3 normalWS = input.normalWS.xyz;
                    #endif

                    // 无参数获取mainLight，这个函数不会对阴影进行采样。
                    Light mainLight = GetMainLight();

                    // 开启了PBR选项 ?
                    #if _INTERIORDECALUSEPBR_ON
                        half2 metalSmoothness = SAMPLE_TEXTURE2D(_InteriorDecalMetalMap, sampler_InteriorDecalMetalMap, decalUV).ra;
                        half metallic = metalSmoothness.r * _InteriorDecalMetallic;
                        half smoothness = metalSmoothness.g * _InteriorDecalGlossiness;

                        BRDFData brdfData;
                        half fakeAlpha = 1;
                        InitializeBRDFData(decalColor, metallic, 0, smoothness, fakeAlpha, brdfData);

                        decalColor = LightingPhysicallyBased(brdfData, mainLight, normalWS, inputData.viewDirectionWS) * decalAlpha;
                        decalColor += GlobalIllumination(brdfData, inputData.bakedGI, 1, inputData.positionWS, normalWS, inputData.viewDirectionWS) * decalAlpha;
                    #else
                        half NdotL = dot(normalWS, mainLight.direction);
                        decalColor *= NdotL * 0.5 + 0.5;
                    #endif

                    // alpha blend 注意 此时 _ALPHAPREMULTIPLY_ON 是打开的
                    color = lerp(color, decalColor, decalAlpha);
                #endif
            }


            // --------------------------------------------------------------------------------------
            // 假室内
            void GlassCalculateInterior(float2 uv, float4 viewDirTSorPositionNDC, Varyings input, inout half4 color)
            {
                #if _F_INTERIOR_ON

                    #ifdef _INTERIORDEPTHDEBUG_ON
                        float outDebugInterp = 0;
                        float2 interiorUV = ConvertOriginalRawUVToInteriorUV(uv, -viewDirTSorPositionNDC.xyz, _InteriorDepth, outDebugInterp);
                    #else
                        float2 interiorUV = ConvertOriginalRawUVToInteriorUV(uv, -viewDirTSorPositionNDC.xyz, _InteriorDepth);
                    #endif

                    // 法线对interior的扰动
                    // #if _NORMALMAP
                    //     float3 bump = normalize(surfaceData.normalTS);
                    //     interiorUV.xy += bump.xy;
                    // #endif

                    float3 interior = SAMPLE_TEXTURE2D(_InteriorTex, sampler_InteriorTex, interiorUV).rgb;
                    // 再传入一张模糊好的图模拟毛玻璃部分
                    #if _USEINTERIORBLUR_ON
                        float3 interior_blur = SAMPLE_TEXTURE2D(_InteriorBlurTex, sampler_InteriorBlurTex, interiorUV).rgb;
                        float roughness = PerceptualSmoothnessToRoughness(surfaceData.smoothness);
                        // 模糊好的图需要保留一定细节所以不能太糊 对应到粗糙度 这里可能需要进行缩放 方便统一范围
                        interior = lerp(interior, interior_blur, saturate(roughness/**2*/));
                    #endif

                    interior *= _InteriorColor.rgb * _InteriorIntensity;

                    // 远平面位置debug
                    #ifdef _INTERIORDEPTHDEBUG_ON
                        if (abs(outDebugInterp - 1) <= 0.001)
                        {
                            color.rgba = float4(0.01, 0.1, 0.02, 0.9);
                        }
                    #endif

                    // alpha blend 注意 此时 _ALPHAPREMULTIPLY_ON 是打开的
                    color.rgb = color.rgb * color.a + interior * (1 - color.a);
                    color.a = 1.0;

                #endif
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                input.viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);

                half4 finalColor = 0;
                GlassCalculateInterior(uv, float4(input.viewDirTS, 1), input, finalColor);

                return finalColor;
            }
            
            ENDHLSL
        }
    }
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
