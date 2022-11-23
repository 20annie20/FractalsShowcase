Shader "Unlit/MengerSponge"
{
    Properties
    {
        _CubeColor1("CubeColor1", Range(0,20)) = 1.0
        _CubeColor2("CubeColor2", Range(0,20)) = 1.0
        _CubeColor3("CubeColor3", Range(0,20)) = 1.0
        _CubeSaturation("CubeSaturation", Range(0, 4)) = 0.2
        _CameraDist("CameraDistance", Range(0.5, 100)) = 20
        _CubeLightness("CubeLightness", Range(0, 2)) = 0.5
        _DissapearSpeed("DissapearSpeed", Range(0, 1)) = 0.4
        _Rozwarstwienie("Rozwarstwienie", Range(0, 3)) = 1.0
        _Iteracje("Iteracje", Range(1,4)) = 4.0
        _Ksztalt("Ksztalt", Range(0,10)) = 3.0
        _SizeX("SizeX", Range(-1, 100)) = 3.0
        _SliceX("SliceX", Range(-2, 4)) = 0.0
        _SliceY("SliceY", Range(-2, 4)) = 1.0
        _SliceZ("SliceZ", Range(-2, 4)) = 0.0

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

            float _CubeColor1;
            float _CubeColor2;
            float _CubeColor3;
            float _CubeSaturation;
            float _CameraDist;
            float _CubeLightness;
            float _DissapearSpeed;
            float _Rozwarstwienie;
            float _Ksztalt;
            float _Iteracje;
            float _SizeX;
            float _SizeY;
            float _SizeZ;
            float _SliceX;
            float _SliceY;
            float _SliceZ;

            float maxcomp(in float3 p) { return max(p.x, max(p.y, p.z)); }
            float sdBox(float3 p, float3 b)
            {
                float3  di = abs(p) - b;
                float mc = maxcomp(di);

                float plane = p.y * _SliceY + p.x * _SliceX + p.z * _SliceZ;
                mc = min(mc, plane);

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

            const float3x3 ma = float3x3(0.60, 0.00, 0.80,
                                         0.00, 1.00, 0.00,
                                        -0.80, 0.00, 0.60);
            float4 map(in float3 p)
            {
                float d = sdBox(p, float3(_SizeX, _SizeY, _SizeZ));
                
                float4 res = float4(d, 1.0, 0.0, 0.0);

                float ani = 0.0f; // smoothstep(-0.2, 0.2, -cos(_DissapearSpeed * _Time.y));
                float off = 1.5 * sin(0.001 * _Time.y);

                float s = 1.0;
                for (int m = 0; m < _Iteracje; m++)
                {
                    p = lerp(p, mul(ma, (p + off)), ani);

                    float3 a = mod(mul(p, s), 2.0) - _Rozwarstwienie;
                    s *= _Ksztalt;               

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
                float2 bb = iBox(ro, rd, _SizeX);
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

            float3 render(in float3 ro, in float3 rd)
            {
                // background color
                float3 col = lerp(float3(0.1, 0.1, 0.1) * 0.5, float3(0.9, 0.9, 1.0), 0.5 + 0.5 * rd.y);

                float4 tfloat = intersect(ro, rd);
                if (tfloat.x > 0.0)
                {
                    float3  pos = ro + tfloat.x * rd;
                    float3  nor = calcNormal(pos);

                    float3 matcol = _CubeLightness +_CubeSaturation * cos(float3(_CubeColor1, _CubeColor2, _CubeColor3) + 5.0 * tfloat.z);
                    
                    float occ = tfloat.y;

                    const float3 light = normalize(float3(1.0, 0.9, 0.3));
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

                col = 1.5 * col / (1.0 + col);
                col = sqrt(col);

                return col;
            }

            fixed4 frag(float4 fragCoord : SV_POSITION) : SV_Target
            {
                
                // camera
                float3 ro = _CameraDist * float3(2.5 * sin(0.2 * _Time.y), 0.5 + 1.0 * cos(_Time.y * .4), 2.5 * cos(0.12 * _Time.y));

            #if AA>1
            #define ZERO (min(iFrame,0))
                 float3 col = float3(0.0);
                 for (int m = ZERO; m < AA; m++)
                      for (int n = ZERO; n < AA; n++)
                      {
                          // pixel coordinates
                           float2 o = float2(float(m), float(n)) / float(AA) - 0.5;
                           float2 p = (2.0 * (fragCoord + o) - _ScreenParams.xy) / _ScreenParams.y;

                           float3 ww = normalize(0.0 - ro);
                           float3 uu = normalize(cross(float3(0.0, 1.0, 0.0), ww));
                           float3 vv = normalize(cross(ww, uu));
                           float3 rd = normalize(p.x * uu + p.y * vv + 2.5 * ww);

                           col += render(ro, rd);
                      }
                      col /= float(AA * AA);
            #else   
                float2 p = (2.0 * fragCoord - _ScreenParams.xy) / _ScreenParams.y;
                float3 ww = normalize(0.0 - ro);
                float3 uu = normalize(cross(float3(0.0, 1.0, 0.0), ww));
                float3 vv = normalize(cross(ww, uu));
                float3 rd = normalize(p.x * uu + p.y * vv + 2.5 * ww);
                float3 col = render(ro, rd);
            #endif        

                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
