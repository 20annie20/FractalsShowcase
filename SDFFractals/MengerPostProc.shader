Shader "Unlit/MengerPostProc"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Blend SrcAlpha OneMinusSrcAlpha
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
            sampler2D _CameraDepthTexture;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #if HW_PERFORMANCE==0
            #define AA 1
            #else
            #define AA 2
            #endif
            #define mod(x, y) (x-y*floor(x/y))

            float GetDistanceFromDepth(float2 uv, out float3 rayDir)
            {
                // Bring UV coordinates to correct space, for matrix math below
                float2 p = uv * 2.0f - 1.0f; // from -1 to 1

                // Figure out the factor, to convert depth into distance.
                // This is the distance, from the cameras origin to the corresponding UV
                // coordinate on the near plane. 
                float3 rd = mul(unity_CameraInvProjection, float4(p, -1.0, 1.0)).xyz;

                // Let's create some variables here. _ProjectionParams y and z are Near and Far plane distances.
                float a = _ProjectionParams.z / (_ProjectionParams.z - _ProjectionParams.y);
                float b = _ProjectionParams.z * _ProjectionParams.y / (_ProjectionParams.y - _ProjectionParams.z);
                float z_buffer_value = tex2D(_CameraDepthTexture, uv).r;

                // Z buffer valeus are distributed as follows:
                // z_buffer_value =  a + b / z 
                // So, below is the inverse, to calculate the linearEyeDepth. 
                float d = b / (z_buffer_value - a);

                // This function also returns the ray direction, used later (very important)
                rayDir = normalize(rd);

                return d;
            }

            float maxcomp(in float3 p) { return max(p.x, max(p.y, p.z)); }
            float sdBox(float3 p, float3 b)
            {
                float3 di = abs(p) - b;
                float mc = maxcomp(di);
                return min(mc, length(max(di, 0.0)));
            }

            float2 iBox(in float3 ro, in float3 rd, in float3 rad)
            {
                float3 m = 1.0 / rd;
                float3 n = m * ro;
                float3 k = abs(m) * rad;
                float3 t1 = -n - k;
                float3 t2 = -n + k;

                return float2(max(max(t1.x, t1.y), t1.z),
                              min(min(t2.x, t2.y), t2.z));

            }
            
            float4 map(in float3 p)
            {
                float d = sdBox(p, float3(1.0, 1.0, 1.0));

                float4 res = float4(d, 1.0, 0.0, 0.0);

                float s = 1.0;
                for (int m = 0; m < 4; m++)
                {

                    float3 a = mod(mul(p, s), 2.0) - 1.0;
                    s *= 3.0;

                    float3 r = abs(1.0 - 3.0 * abs(a));
                    float da = max(r.x, r.y);
                    float db = max(r.y, r.z);
                    float dc = max(r.z, r.x);
                    float c = (min(da, min(db, dc)) - 1.0) / s;


                    if (c > d)
                    {
                        d = c;
                        res = float4(d, min(res.y, 0.2 * da * db * dc), (1.0 + float(m)) / 4.0, 0.0);
                    }
                }


                return res;
            }

            float4 intersect(in float3 ro, in float3 rd)
            {
                float2 bb = iBox(ro, rd, 1.05);
                if (bb.y < bb.x) return -1.0;

                float tmin = bb.x;
                float tmax = bb.y;

                float t = tmin;
                float4 res = -1.0;
                for (int i = 0; i < 64; i++)
                {
                    float4 h = map(ro + rd * t);
                    if (h.x<0.002 || t>tmax) break;
                    res = float4(t, h.yzw);
                    t += h.x;
                }
                if (t > tmax) res = -1.0;
                return res;
            }

            float softshadow(in float3 ro, in float3 rd, float mint, float k)
            {
                float2 bb = iBox(ro, rd, 1.05);
                float tmax = bb.y;

                float res = 1.0;
                float t = mint;
                for (int i = 0; i < 64; i++)
                {
                    float h = map(ro + rd * t).x;
                    res = min(res, k * h / t);
                    if (res < 0.001) break;
                    t += clamp(h, 0.005, 0.1);
                    if (t > tmax) break;
                }
                return clamp(res, 0.0, 1.0);
            }

            float3 calcNormal(in float3 pos)
            {
                float3 eps = float3(.001, 0.0, 0.0);
                return normalize(float3(
                    map(pos + eps.xyy).x - map(pos - eps.xyy).x,
                    map(pos + eps.yxy).x - map(pos - eps.yxy).x,
                    map(pos + eps.yyx).x - map(pos - eps.yyx).x));
            }

            float3 render(in float3 ro, in float3 rd, in float3 col)
            {
                float4 tfloat = intersect(ro, rd);
                if (tfloat.x > 0.0)
                {
                    float3  pos = ro + tfloat.x * rd;
                    float3  nor = calcNormal(pos);

                    float3 matcol = 0.5 + 0.5 * cos(float3(1.0, 0.0, 0.0) + 2.0 * tfloat.z);
                    
                    float occ = tfloat.y;

                    const float3 light = normalize(float3(1.0, 1.0, 1.0));
                    float dif = dot(nor, light);
                    float sha = 1.0;
                    if (dif > 0.0) sha = softshadow(pos, light, 0.01, 64.0);
                    dif = max(dif, 0.0);
                    float3  hal = normalize(light - rd);
                    float spe = dif * sha * pow(clamp(dot(hal, nor), 0.0, 1.0), 16.0) * (0.04 + 0.96 * pow(clamp(1.0 - dot(hal, light), 0.0, 1.0), 5.0));

                    float sky = 0.5 + 0.5 * nor.y;
                    float bac = max(0.4 + 0.6 * dot(nor, float3(-light.x, light.y, -light.z)), 0.0);

                    float3 lin = 0.0;
                    lin += 1.00 * dif * float3(1.10, 0.85, 0.60) * sha;
                    lin += 0.50 * sky * float3(0.10, 0.20, 0.40) * occ;
                    lin += 0.10 * bac * float3(1.00, 1.00, 1.00) * (0.5 + 0.5 * occ);
                    lin += 0.25 * occ * float3(0.15, 0.17, 0.20);
                    col = matcol * lin + spe * 128.0;
                }
                col = sqrt(col);

                return col;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv_MainTex = i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                float4 screenColour = tex2D(_MainTex, uv_MainTex);

                float3 rayDirection;
                // Our code from above!
                GetDistanceFromDepth(i.uv.xy, rayDirection);

                // The cameras position (worldspace)
                float3 rayOrigin = _WorldSpaceCameraPos;
                // Accounting for the cameras rotation
                rayDirection = mul(unity_CameraProjection, float4(rayDirection, 0.0)).xyz;

                float4 mengerCol = float4(render(rayOrigin, rayDirection, screenColour.xyz), 1.0);

                float4 result = lerp(screenColour, mengerCol, 1.0f);
                return result;
            }
            ENDCG
        }
    }
}
