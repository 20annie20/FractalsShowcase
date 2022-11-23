Shader "Unlit/sierpinski"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Iterations("Iterations", Range(1, 20)) = 6.
        _Speed("Speed", Range(0, 5)) = 1.0 
        _Filling("Filling", Range(1.9, 2.3)) = 2.0
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
            float _Iterations;
            float _Speed;
            float _Filling;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            float stime, ctime;
            void ry(inout float3 p, float a) {
                float c, s; float3 q = p;
                c = cos(a); s = sin(a);
                p.x = c * q.x + s * q.z;
                p.z = -s * q.x + c * q.z;
            }

            float plane(float3 p, float y) {
                return length(float3(p.x, y, p.z) - p);
            }

            float3 mat = float3(0.0, 0., 0.);
            float bcolor = 0.0;

            float tetrahedron(float3 p) {
                return (max(
                    max(-p.x - p.y - p.z, p.x + p.y - p.z),
                    max(-p.x + p.y + p.z, p.x - p.y + p.z)
                )
                    - 1.) / sqrt(3.0);
            }


            float sierpinski(in float3 z) {
                float scale = _Filling;
                for (int n = 0; n < _Iterations; n++) {
                    if (z.x + z.y < 0.) { z.xy = -z.yx; }
                    if (z.x + z.z < 0.) { z.xz = -z.zx; }
                    if (z.y + z.z < 0.) { z.yz = -z.zy; }
                    z = z * 2. - 1. + 0.3 * sin(_Time.y) * _Speed;
                    if (bcolor && n == 2)mat += float3(0.3, 0.3, 0.3) + sin(z.xyz) * float3(1.0, 0.24, 0.245);
                }

                return tetrahedron(z) * pow(scale, -_Iterations);
            }

            float3 f(float3 p) {
                ry(p, stime);
                float d1 = plane(p, -1.4);
                float d2 = sierpinski(p);
                if (d1 < d2)
                {
                    return float3(d1, 0.0, 0.0);
                }
                else
                {
                    return float3(d2, 1.0, 0.0);
                }
            }

            float ao(float3 p, float3 n) {
                float ao = 0.0, sca = 1.0;
                for (float i = 0.0; i < 20.0; ++i) {
                    float hr = 0.05 + 0.015 * i * i;
                    ao += (hr - f(n * hr + p).x) * sca;
                    sca *= 0.75;
                }
                return 1.0 - clamp(ao, 0.0, 1.0);
            }


            float rand(float2 t) {
                return frac(sin(dot(t * 0.123, float2(12.9898, 78.233))) * 43758.5453);
            }

            float3 nor(float3 p) {
                float3 e = float3(0.001, 0.0, 0.0);
                return normalize(float3(f(p + e.xyy).x - f(p - e.xyy).x,
                    f(p + e.yxy).x - f(p - e.yxy).x,
                    f(p + e.yyx).x - f(p - e.yyx).x));
            }

            float3 intersect(in float3 ro, in float3 rd)
            {
                float t = 0.0;
                float3 res = float3(-1.0, -1.0, -1.0);
                float3 h = float3(1.0, 1., 1.);
                for (int i = 0; i < 120; i++)
                {
                    if (h.x < 0.005 || t>30.0) {
                    }
                    else {
                        h = f(ro + rd * t);
                        res = float3(t, h.yz);
                        t += abs(h.x);
                    }
                }
                if (t > 30.0) res = float3(-1.0, -1.0, -1.);
                return res;
            }
            fixed4 frag(float4 fragCoord : SV_POSITION) : SV_Target
            {
                float2 q = fragCoord.xy / _ScreenParams.xy;
                float2 uv = -1.0 + 2.0 * q;
                uv.x *= _ScreenParams.x / _ScreenParams.y;
                // camera
                stime = sin(_Time.y * 0.2) * _Speed;
                ctime = cos(_Time.y * 0.2) * _Speed;

                float3 ta = float3(.0, 0.0, 0.0);
                float3 ro = float3(4, 4. + 0.5 * ctime, 9. + 1.0 * stime) * 0.5;

                float3 cf = normalize(ta - ro);
                float3 cs = normalize(cross(cf, float3(0.0, 1.0, 0.0)));
                float3 cu = normalize(cross(cs, cf));
                float3 rd = normalize(uv.x * cs + uv.y * cu + 2.8 * cf);  // transform from view to world

                float3 sundir = normalize(float3(-3.5, 7.0, 2.8));
                float3 light_col = float3(1.0, 1.0, 1.0);

                float3 bg = float3(1.0, 1.0, 1.0);

                float sc = clamp(dot(sundir, rd), 0.0, 1.0);
                float3 col = bg + float3(0.5, 0.5, 0.4) * pow(sc, 50.0);


                float t = 0.0;
                float3 p = ro;

                float3 res = intersect(ro, rd);
                if (res.x > 0.0) {
                    p = ro + res.x * rd;
                    bcolor = 1;
                    mat = float3(0.0, 0., 0.);
                    float3 n = nor(p);
                    mat /= 6.0;
                    bcolor = 0;
                    float occ = ao(p, n);

                    float dif = max(0.0, dot(n, sundir));
                    float sky = 0.8 + 0.4 * max(0.0, dot(n, float3(0.0, 1.0, 0.0)));
                    float bac = max(0.3 + 0.7 * dot(float3(-sundir.x, -1.0, -sundir.z), n), 0.0);
                    float spe = max(0.0, pow(clamp(dot(sundir, reflect(rd, n)), 0.0, 1.0), 10.0));

                    float3 lin = 4.5 * light_col * dif * occ;
                    //lin += 0.1 * bac * light_col * occ;
                    lin += 2.6 * sky * light_col * occ;
                    lin += 3.0 * spe * occ;

                    col = lin * (float3(0.4, 1., 1.) * (1.0 - res.y) + mat * res.y) * 0.6;
                    //col = lerp(col, bg, 1.0 - exp(-0.002 * res.x * res.x));
                }

                // post
                
                col = pow(clamp(col, 0.0, 1.0), float3(0.45, 0.45, 0.45));
                col = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col);  // contrast
                //col = lerp(col, float3(dot(col, float3(0.33, 0.33, 0.33))), -0.5, 0.0);  // satuation
                return float4(col, 1.0);   
            }

            ENDCG
        }
    }
}
