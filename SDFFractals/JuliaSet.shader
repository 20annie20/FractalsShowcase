Shader "Unlit/JuliaShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Iterations("Iterations", Range(3, 12)) = 10
        _Steps("Steps", Range(128, 2048)) = 512
        _RotX("RotX", Range(0, 10)) = 2.0
        _RotY("RotY", Range(0, 10)) = 2.0
        _RotZ("RotZ", Range(0, 10)) = 2.0
        _ColorR("ColorR", Range(0, 20)) = 10.0
        _ColorG("ColorG", Range(0, 20)) = 10.0
        _ColorB("ColorB", Range(0, 20)) = 10.0
        _SliceX("SliceX", Range(-1, 2)) = 0.0
        _SliceY("SliceY", Range(-1, 2)) = 1.0
        _SliceZ("SliceZ", Range(-1, 2)) = 0.0
        _Saturation("Saturation", Range(0, 2)) = 0.1
        _Speed("Speed", Range(0, 5 )) = 0.3
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

            v2f vert (appdata v)
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

            float3 sq3(float3 v) {
                return float3(
                    v.x * v.x - v.y * v.y - v.z * v.z,
                    2. * v.x * v.y,
                    2. * v.x * v.z
                );
            }
            float squishy(float x) {
                return x * x * x;
            }
            float julia(float3 p, float3 c) {
                float3 k = p;
                for (int i = 0; i < _Iterations; i++) {
                    k = sq3(k) + c;
                    if (length(k) > 10.) return 1. - squishy(float(i) / float(_Iterations));
                }
                return -0.01;
            }
            float2 rotate2D(float2 p, float angle) {
                return float2(p.x * cos(angle) - p.y * sin(angle), p.y * cos(angle) + p.x * sin(angle)); \
            }
            float sdf(float3 p) {
                float3 r = p;
                r.xz = rotate2D(r.xz, _Time.y * 0.3);
                r.yz = rotate2D(r.yz, _Time.y * 0.1);

                float plane = p.y * _SliceY + p.x * _SliceX + p.z * _SliceZ;

                return max(plane, julia(p,

                    float3(sin(_Time.y * _Speed) * 0.7, cos(_Time.y * _Speed) * 0.7, 0.1)
                ));

            }
            float4 trace(float3 o, float3 r) {
                float3 p = o;
                float t = 0.;
                float s;
                int i;
                for (i = 0; i < _Steps; i++) {
                    p = o + r * t;
                    s = sdf(p);
                    t += s * 0.005;
                    if ((s < 0.001 && s >= 0.) || t > 10.) break;
                }
                return float4(p, float(i));
            }
            const float E = 0.01;
            float3 estimateNormal(float3 p) {
                return normalize(float3(
                    sdf(float3(p.x + E, p.y, p.z)) - sdf(float3(p.x - E, p.y, p.z)),
                    sdf(float3(p.x, p.y + E, p.z)) - sdf(float3(p.x, p.y - E, p.z)),
                    sdf(float3(p.x, p.y, p.z + E)) - sdf(float3(p.x, p.y, p.z - E))
                ));
            }
            fixed4 frag(float4 fragCoord : SV_POSITION) : SV_Target
            {
                float2 uv = fragCoord / _ScreenParams.xy;
                uv -= 0.5;
                float3 cam = float3(0., 0., _CameraDistance);
                float3 ray = normalize(float3(uv.xy * 1.3, 1.));

                float3 rot = float3(_RotX, _RotY, _RotZ);

                cam.xz = rotate2D(cam.xz, rot.y);
                ray.xz = rotate2D(ray.xz, rot.y);

                cam.zy = rotate2D(cam.zy, rot.x);
                ray.zy = rotate2D(ray.zy, rot.x);


                float4 t = trace(cam, ray);
                float3 e = t.xyz;
                float3 light = float3(0., 0., -5.);
                float3 toLight = normalize(light - e);
                float3 norm = estimateNormal(e);
                float diffuse = max(0., dot(toLight, norm)) * 5.8;
                float3 refl = reflect(ray, norm);
                float specular = pow(max(0.0, dot(refl, toLight)), 4.0) * 0.5;
                float d = length(e - cam);
                float fog = 1.0 / (1.0 + d * d * 1.7);

                float4 col = float4(_ColorR, _ColorG, _ColorB, 1.0);
                col -= pow(t.w / float(_Steps), 2.) * 0.5;//ao
                col *= (diffuse + specular) + _Saturation;//other light
                col *= fog;

                // Output to screen
                return float4(col);
            }
            ENDCG
        }
    }
}
