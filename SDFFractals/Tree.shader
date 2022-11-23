Shader "Unlit/Tree"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Lightness("Lightness", Range(0, 2)) = 0.8
        _Precyzja("Precision", Range(5, 32)) = 24.0
        _Branches("Branches", Range(1, 50)) = 11.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #define pi 3.1415926

            float _Lightness;
            float _Precyzja;
            float3 light;
            float _Branches;

            float ln(float3 p, float3 a, float3 b, float R) {
                float r = dot(p - a, b - a) / dot(b - a, b - a);
                r = clamp(r, 0., 1.);
                return length(p - a - (b - a) * r) - R * (1.0 - 0.4 * r);
            }
            float2x2 ro(float a) {
                float s = sin(a), c = cos(a);
                return float2x2(c, -s, s, c);
            }
            float rand(float2 t) {
                return frac(sin(dot(t * 0.123, float2(12.9898, 78.233))) * 43758.5453);
            }

            float map(float3 p) {
                float l = length(p - light) - 1e-2;
                l = min(l, abs(p.y + 0.4) - 1e-2);
                l = min(l, abs(p.z - 0.4) - 1e-2);
                l = min(l, abs(p.x - 0.7) - 1e-2);
                p.y += 0.4;
                p.z += 0.1;
                p.zx = mul(p.zx, ro(.2 * _Time.y));
                float2 rl = float2(0.02, .25 + 0.01 * sin(pi * 4. * 1.));
                for (int i = 1; i < _Branches; i++) {

                    l = min(l, ln(p, float3(0, 0, 0), float3(0, rl.y, 0), rl.x));
                    p.y -= rl.y;
                    p.xy = mul(p.xy, ro(0.2 * sin(3.1 * _Time.y + float(i)) + sin(0.222 * _Time.y) * (-0.1 * sin(0.4 * pi * _Time.y) + sin(0.543 * _Time.y) / max(float(i), 2.))));
                    p.x = abs(p.x);
                    p.xy = mul(p.xy, ro(0.2 + 0.05 * sin(0.5 * _Time.y) + 0.5 * float(i) * sin(0.3 * _Time.y) - 1.5));
                    p.zx = mul(p.zx, ro(0.5 * pi + 0.2 * sin(0.5278 * _Time.y) + 0.8 * float(i) * (sin(0.1 * _Time.y) * (sin(0.1 * pi * _Time.y) + sin(0.333 * _Time.y) + 0.2 * sin(1.292 * _Time.y)))));

                    rl *= (.7 + 0.015 * float(i) * (sin(_Time.y) + 0.1 * sin(4. * pi * _Time.y)));

                    l = min(l, length(p) - 0.15 * sqrt(rl.x));
                }
                return l;
            }

            float3 march(float3 p, float3 d) {
                float o = 1e3;
                for (int i = 0; i < _Precyzja; i++) {
                    float l = map(p);
                    p += l * d;
                    if (l < 1e-3)break;
                }
                return p;
            }
            float3 norm(float3 p) { // iq
                float2 e = float2(.001, 0.);
                return normalize(float3(
                    map(p + e.xyy) - map(p - e.xyy),
                    map(p + e.yxy) - map(p - e.yxy),
                    map(p + e.yyx) - map(p - e.yyx)
                ));
            }
            fixed4 frag(float4 fragCoord : SV_POSITION) : SV_Target
            {
                float2 R = _ScreenParams.xy;
                light = float3(0.3 * sin(_Time.y), 1.5, -.5);

                fragCoord.xy = (fragCoord.xy - 0.5 * R) / R.y;
                //point of view
                float3 p = float3(0, 0, -1.);
                float3 d = normalize(float3(fragCoord.xy, 1));
                p = march(p, d);
                float3 n = norm(p);
                float4 C = _Lightness + 0.7 * sin(1.2 * float4(1. * cos(_Time.y), 1. * sin(_Time.y), 3, 4) * dot(d, n));

                float3 D = light - p;
                d = normalize(D);
                float3 lp = march(p + d * 1e-2, d);
                C *= 2.5 * (dot(d, n)) * (.3 + 0.7 * length(lp - p) / length(light - p));
                return atan(C) / pi * 2.;
            }

            ENDCG
        }
    }
}
