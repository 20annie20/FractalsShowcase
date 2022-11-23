Shader "Unlit/SDFEffects"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Glow("Glow", Range(0, 1)) = 0.0
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

            float _Glow;

            #define MAX_STEPS 100
            #define MAX_DIST 200.
            #define SURF_DIST .0001 //I decreased it when adding glow to eliminate artifacts

            float2x2 Rot(float a) {
                float s = sin(a);
                float c = cos(a);
                return float2x2(c, -s, s, c);
            }

            float smin(float a, float b, float k) {
                float h = clamp(0.5 + 0.5 * (b - a) / k, 0., 1.);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }

            float opUnion(float d1, float d2)
            {
                return min(d1, d2);
            }

            float opSmoothUnion(float d1, float d2, float k)
            {
                float h = max(k - abs(d1 - d2), 0.0);
                return min(d1, d2) - h * h * 0.25 / k;
            }

            /*
            float opTwist(in sdf3d primitive, in vec3 p)
            {
                const float k = 10.0;
                float c = cos(k * p.y);
                float s = sin(k * p.y);
                mat2  m = mat2(c, -s, s, c);
                vec3  q = vec3(m * p.xz, p.y);
                return primitive(q);
            }*/

            float sdSphere(in float3 p, in float r)
            {
                return length(p) - r;
            }

            float sdRoundBox(float3 p, float3 b, float r)
            {
                float3 d = abs(p) - b;
                return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0)) - r;
            }

            float getRay(float startSize, float freq, float angle) {
                return startSize + 0.02 * sin(freq * _Time.y + angle);
            }

            float GetDist(float3 p) {
                float d = 1e10;

                float an = sin(_Time.y) + 1.3;

                //twist
                float k = -0.005;
                float c = cos(1 + k * p.x);
                float s = sin(-1.0 + 0.01 * p.z);
                float2x2  m = float2x2(c, -s, s, c);
                p = float3(mul(m, p.xy), p.z);

                //space folding
                p.x = (p.x + 30.0) % 2.6 + 0.8 * sin(p.y) + 1.3;
                p.y = (p.y + 30.0) % 2.0 + 2.0;
                p.z = (p.z + 100.0) % 5.0 + 0.8*sin(p.x) + 2.0;
                
                // opSmoothUnion
                {
                    float3 q = p - float3(2.0, 2.0, 4.0);
                    
                    float d1 = sdSphere(q - float3(0.0, 0.5 + 0.3 * an, 0.0), 0.2);
                    //float d2 = sdSphere(q - float3(-0.4, 0.5 + 0.3 * an, 0.0), getRay(0.15, 5, 1));
                    //float d3 = sdSphere(q - float3(0.4, 0.5 + 0.3 * an, 0.0), getRay(0.15, 3, 0));
                    //float d4 = sdSphere(q - float3(0.0, 0.9 + 0.3 * an, 0.0), getRay(0.15, 8, 2));
                    //float d5 = sdSphere(q - float3(0.0, 0.1 + 0.3 * an, 0.0), getRay(0.15, 5, 4));
                    //float dt = opSmoothUnion(d1, d2, 0.23);
                    //dt = opSmoothUnion(dt, d3, 0.23);
                    //dt = opSmoothUnion(dt, d4, 0.23);
                    //dt = opSmoothUnion(dt, d5, 0.23);

                    d = min(d, d1);
                }
                
                return d;
            }

            //returns distance and glow object
            float4 RayMarch(float3 ro, float3 rd) {
                float dO = 0.;
                float3 glow = (0., 0., 0.);

                for (int i = 0; i < MAX_STEPS; i++) {
                    float3 p = ro + rd * dO;
                    float dS = GetDist(p);
                    dO += dS;
                    if (dO > MAX_DIST || dS < SURF_DIST) break;
                    glow += float3(0.0, 0.0, 0.0) / (50. * (dS)) * _Glow;
                }

                return float4(dO, glow);
            }

            float3 GetNormal(float3 p) {
                float d = GetDist(p);
                float2 e = float2(.001, 0);

                float3 n = d - float3(
                    GetDist(p - e.xyy),
                    GetDist(p - e.yxy),
                    GetDist(p - e.yyx));

                return normalize(n);
            }

            float GetLight(float3 p) {
                float3 lightPos = float3(10, 10, 10);
                float3 l = normalize(lightPos - p);
                float3 n = GetNormal(p);
                float dif = clamp(dot(n, l) * .4 + .4, 0., 1.);
                return dif; //n
            }

            float3 R(float2 uv, float3 p, float3 l, float z) {
                float3 f = normalize(l - p),
                    r = normalize(cross(float3(0, 1, 0), f)),
                    u = cross(f, r),
                    c = p + f * z,
                    i = c + uv.x * r + uv.y * u,
                    d = normalize(i - p);
                return d;
            }


            fixed4 frag (float4 fragCoord : SV_POSITION) : SV_Target
            {
                float2 uv = (fragCoord - .5 * _ScreenParams.xy) / _ScreenParams.y;

                float3 col = float3(0, 0, 0);

                float3 ro = float3(3, 6, 9) + 0.2 * _Time.y % 25;

                float3 rd = R(uv, ro, float3(0, 1, 0), 1.);

                float4 rm = RayMarch(ro, rd);
                float d = rm.x;

                if (d < MAX_DIST) {
                    float3 p = ro + rd * d;
                    
                    float dif = GetLight(p);
                    
                    col = float3(0.2*dif, 0.7*dif, 0.8*dif); // (dif + 1) / 2; //

                    float3 fGlow = clamp(p.z * 0.1, 0.0, 1.0);
                    fGlow = pow(fGlow, 3.0);
                    col += fGlow;
                }

                if (d > SURF_DIST)
                {
                    col += 50 * float3(0.2, 0.7, 0.8) / abs(5. - d) * _Glow;
                }
                
                //col += 50 * float3(0.2, 0.7, 0.8) / abs(15.-d) * _Glow;
                //col += pow((50 * float3(0.2, 0.7, 0.8) / (d) * _Glow), (100 - d)); fajny cartoonowy efekt


                //col = pow(col, float3(.4545, .4545, .4545));	// gamma correction

                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
