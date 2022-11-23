Shader "Unlit/JuliaColoredFolded"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Iterations("Iterations", Range(1, 20)) = 10
        _Steps("Steps", range(50, 512)) = 300
        _RotX("RotX", range(0, 10)) = 2.0
        _RotY("RotY", range(0, 10)) = 2.0
        _RotZ("RotZ", range(0, 10)) = 2.0
        _ColorR("ColorR", range(0, 1)) = 0.5
        _ColorG("ColorG", range(0, 1)) = 0.44
        _ColorB("ColorB", range(0, 1)) = 0.76
        _SliceX("SliceX", Range(-1.5, 1.5)) = 0.0
        _SliceY("SliceY", Range(-1.5, 1.5)) = 0.0
        _SliceZ("SliceZ", Range(-1.5, 1.5)) = 0.0
        _Saturation("Saturation", Range(0, 1)) = 0.3
        _Speed("Speed", Range(0, 2)) = 0.5
        _CameraDistance("CameraDistance", Range(-5, 0)) = -2.0
    }
        SubShader
        {
            // No culling or depth
            Cull Off ZWrite Off ZTest Always

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "UnityCG.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    float4 vertex : SV_POSITION;
                };

                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.uv = v.uv;
                    return o;
                }

                int _Iterations;
                int _Steps;
                float _RotX;
                float _RotY;
                float _RotZ;
                float _ColorR;
                float _ColorG;
                float _ColorB;
                float _SliceX;
                float _SliceY;
                float _SliceZ;
                float _Saturation;
                float _Speed;
                float _CameraDistance;

                #define AA 2
                #define mod(x, y) (x-y*floor(x/y))

                float4 qsqr(in float4 a) // square a quaternion
                {
                    return float4(a.x * a.x - a.y * a.y - a.z * a.z - a.w * a.w,
                        2.0 * a.x * a.y,
                        2.0 * a.x * a.z,
                        2.0 * a.x * a.w);
                }
                float4 qmul(in float4 a, in float4 b)
                {
                    return float4(
                        a.x * b.x - a.y * b.y - a.z * b.z - a.w * b.w,
                        a.y * b.x + a.x * b.y + a.z * b.w - a.w * b.z,
                        a.z * b.x + a.x * b.z + a.w * b.y - a.y * b.w,
                        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y);

                }
                float4 qconj(in float4 a)
                {
                    return float4(a.x, -a.yzw);
                }
                float qlength2(in float4 q)
                {
                    return dot(q, q);
                }


                float map(in float3 p, out float4 oTrap, in float4 c)
                {
                    p.x = (p.x + 10) % 2.0 - 1.0;
                    p.y = (p.y + 10) % 3.2 - 1.6;
                    p.z = (p.z + 10) % 3.2 - 1.6;

                    float4 z = float4(p, 0.0);
                    
                    float md2 = 1.0;
                    float mz2 = dot(z, z);
                    oTrap = z;
                    
                    float4 trap = float4(abs(z.xyz), mz2);
                    
                    float n = 1.0;
                    for (int i = 0; i < _Iterations; i++)
                    {
                        md2 *= 4.0 * mz2;
                        // z  -> z^2 + c
                        z = qsqr(z) + c;

                        trap = min(trap, float4(abs(z.xyz), dot(z, z)));

                        mz2 = qlength2(z);
                        if (mz2 > 4.0) break;
                        n += 1.0;
                    }

                    oTrap = trap;
                    float d = 0.25 * sqrt(mz2 / md2) * log(mz2);
                    
                    return d;  // d = 0.5·|z|·log|z|/|z'|*/
                }

                float3 calcNormal(in float3 p, in float4 c)
                {
                    float4 z = float4(p, 0.0);

                    // identity derivative
                    float4 J0 = float4(1, 0, 0, 0);
                    float4 J1 = float4(0, 1, 0, 0);
                    float4 J2 = float4(0, 0, 1, 0);

                    for (int i = 0; i < 9; i++)
                    {
                        float4 cz = qconj(z);

                        // chain rule of jacobians (removed the 2 factor)
                        J0 = float4(dot(J0, cz), dot(J0.xy, z.yx), dot(J0.xz, z.zx), dot(J0.xw, z.wx));
                        J1 = float4(dot(J1, cz), dot(J1.xy, z.yx), dot(J1.xz, z.zx), dot(J1.xw, z.wx));
                        J2 = float4(dot(J2, cz), dot(J2.xy, z.yx), dot(J2.xz, z.zx), dot(J2.xw, z.wx));

                        // z -> z2 + c
                        z = qsqr(z) + c;

                        if (qlength2(z) > 4.0) break;
                    }

                    float3 v = float3(dot(J0, z),
                        dot(J1, z),
                        dot(J2, z));

                    return normalize(v);
                }
                //rename it to raymarch
                float intersect(in float3 ro, in float3 rd, out float4 res, in float4 c)
                {
                    float4 tmp;
                    float resT = -1.0;
                    float maxd = 10.0;
                    float h = 1.0;
                    float t = 0.0;
                    for (int i = 0; i < _Steps; i++)
                    {
                        if (h<0.0001 || t>maxd) break;
                        h = map(ro + rd * t, tmp, c);
                        t += h;
                    }
                    if (t < maxd) { resT = t; res = tmp; }

                    return resT;
                }

                float softshadow(in float3 ro, in float3 rd, float mint, float k, in float4 c)
                {
                    float res = 1.0;
                    float t = mint;
                    for (int i = 0; i < 64; i++)
                    {
                        float4 kk;
                        float h = map(ro + rd * t, kk, c);
                        res = min(res, k * h / t);
                        if (res < 0.001) break;
                        t += clamp(h, 0.01, 0.9);
                    }
                    return clamp(res, 0.6, 1.0);
                }

                float3 render(in float3 ro, in float3 rd, in float4 c)
                {
                    const float3 sun = float3(0.5, 0.5, 0.5);

                    float4 tra;
                    float3 col;
                    float t = intersect(ro, rd, tra, c);
                    if (t < 0.0)
                    {
                        col = lerp(float3(0.1, 0.1, 0.1) * 0.5, float3(0.9, 0.9, 1.0), 0.5 + 0.5 * rd.y);
                        col += float3(0.8, 0.7, 0.5) * pow(clamp(dot(rd, sun), 0.0, 1.0), 48.0);
                    }
                    else
                    {

                        float3 mate = float3(_ColorR, _ColorG, _ColorB) * _Saturation;

                        float3 pos = ro + t * rd;
                        
                        float3 nor = calcNormal(pos, c);

                        col = tra.xyz * 1.5;
                        /*
                        // sun
                        {
                            const float3 lig = sun;
                            float dif = clamp(dot(lig, nor), 0.0, 1.0);
                            float sha = softshadow(pos, lig, 0.01, 64.0, c);
                            float3 hal = normalize(-rd + lig);
                            float co = clamp(dot(hal, lig), 0.0, 1.0);
                            float fre = 0.04 + 0.96 * pow(1.0 - co, 5.0);
                            float spe = pow(clamp(dot(hal, nor), 0.0, 1.0), 32.0);
                            col += mate * 7.5 * float3(1.00, 0.90, 0.70) * dif * sha;
                            col += 7.0 * 3.5 * float3(1.00, 0.90, 0.70) * spe * dif * sha * fre;
                        }*/

                    }

                    return col;
                }


                fixed4 frag(float4 fragCoord : SV_POSITION) : SV_Target
                {
                    float time = _Time.y * 0.5;
                    float4 c = 0.45 * cos(float4(0.5,3.9,1.4,1.1) + time * float4(1.2,1.7,1.3,2.5));

                    // camera
                    float r = _CameraDistance + 0.15 * cos(0.0 + 0.29 * time);
                    float3 ro = float3(r * cos(0.3 + 0.37 * time),
                                        0.3 + 0.8 * r * cos(1.0 + 0.33 * time),
                                              r * cos(2.2 + 0.31 * time));
                    float3 ta = float3(0.0,0.0,0.0);
                    float cr = 0.1 * cos(0.1 * time);


                    // render
                    float3 col = float3(0.0, 0.0, 0.0);
                    for (int j = 0; j < AA; j++)
                    for (int i = 0; i < AA; i++)
                    {
                        float2 p = (-_ScreenParams.xy + 2.0 * (fragCoord + float2(float(i),float(j)) / float(AA))) / _ScreenParams.y;

                        float3 cw = normalize(ta - ro);
                        float3 cp = float3(sin(cr), cos(cr),0.0);
                        float3 cu = normalize(cross(cw,cp));
                        float3 cv = normalize(cross(cu,cw));
                        float3 rd = normalize(p.x * cu + p.y * cv + 2.0 * cw);

                        col += render(ro, rd, c);
                    }
                    col /= float(AA * AA);

                    float2 uv = fragCoord.xy / _ScreenParams.xy;
                    col *= 0.9 + 0.3 * pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y),0.25);

                    float4 fragColor = float4(col, 1.0);
                    return fragColor;
                }
                ENDCG
            }
        }
}