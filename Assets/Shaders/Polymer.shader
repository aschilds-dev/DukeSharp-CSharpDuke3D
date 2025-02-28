﻿// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

Shader "Unlit/Polymer"
{
    Properties
    {
        _MainTex ("_MainTex", 2D) = "white" {}
        _PaletteTex("_PaletteTex", 2D) = "white" {}
        _LookupTex("_LookupTex", 2D) = "white" {}
        _MaterialParams("_MaterialParams", Vector) = (1, 0, 0, 0)
        _MaterialParams2("_MaterialParams2", Vector) = (1, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                 float4 depth : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };
            texture2D _PaletteTex;
            sampler2D _MainTex;
            texture2D _LookupTex;


            float4 _MainTex_ST;
            float4 _MaterialParams;
            float4 _MaterialParams2;

            float linearize_depth(float d, float zNear, float zFar)
            {
                return zNear * zFar / (zFar + d * (zNear - zFar));
            }

            float fogFactorLinear(const float dist, const float start, const float end) {
                return 1.0 - clamp((end - dist) / (end - start), 0.0, 1.0);
            }


            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.depth.x = (o.vertex.z / (1.0 / o.vertex.w));

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                 
                bool isSprite = _MaterialParams2.x == -1;

                if (isSprite)
                {
                    o.vertex.w -= 0.0005;
                }

                return o;
            }

            struct fragmentOutput
            {
                half4 color : COLOR;
                float depth : DEPTH;
            };

            fragmentOutput frag(v2f i) : SV_Target
            {
                fragmentOutput o;
                float visibility =  (_MaterialParams.x + 16.0f) / 16.0f;
                float shadeOffset =  _MaterialParams.y;
                float palette =  _MaterialParams.z;
                float curbasepal =  _MaterialParams.w;
                float flipx = curbasepal < 0;
                float highres = _MaterialParams2.y;
                

                curbasepal = 0; // abs(curbasepal) - 1;

                float shadeLookup = i.depth.x / 1.024 * (visibility);
               shadeLookup = max(shadeLookup + shadeOffset, 0);

                // sample the texture
                float colorIndex = 0;
               
                if (highres != 0)
                {
                    float2 _uv = i.uv;
                    _uv.y = 1.0 - _uv.y;
                    o.color = tex2D(_MainTex, _uv);
                }
                else
                {
                    if (flipx == 0)
                    {
                        colorIndex = tex2D(_MainTex, i.uv).r * 256;
                    }
                    else
                    {
                        float2 uv = i.uv;
                        uv.x = 1 - uv.x;
                        colorIndex = tex2D(_MainTex, uv).r * 256;
                    }
                    if (colorIndex == 256)
                        discard;

                    float lookupIndex = _LookupTex.Load(int3(colorIndex, shadeLookup + (32 * palette), 0)).r * 256;
                    float3 texelNear = _PaletteTex.Load(int3(lookupIndex, curbasepal, 0)).xyz;

                    float lum = saturate(Luminance(texelNear.rgb) * 4);

                    o.color = float4(texelNear.rgb, 1.0) * 4;
                }

                // 
                if (shadeOffset > 0)
                {       
                    if (_MaterialParams.x <= 239)
                    {
                        o.color.xyz *= clamp(1.0 - ((i.depth.x) * (shadeOffset / 8)), 0.0, 1.0);
                    }
                }

                return o;
            }
            ENDHLSL
        }
    }
}
