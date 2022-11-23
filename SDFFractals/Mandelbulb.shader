Shader "Unlit/Mandelbulb"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CameraDistance("CameraDistance", Range(0,8)) = 2.0
        _RotX("RotationX", Range(0, 0.1)) = 0.02
        _MandelbulbPower("MandelbulbPower", Range(5, 20)) = 10.
        _ViewRadius("ViewRadius", Range(2, 70)) = 15.
        _Iterations("Iterations", Range(1, 30)) = 15.
        _Saturation("Saturation", Range(-1, 1)) = 0.4
        _Brightness("Brightness", Range(-0.5, 1)) = 0.5
        _Contrast("Contrast", Range(3, 0)) = 1.0
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

            float _CameraDistance;
            float _RotX;
            float _MandelbulbPower;
            float _ViewRadius;
            float _Iterations;
            float _Saturation;
            float _Brightness;
            float _Contrast;

            #define EPSILON 0.002
            #define CAMERA_DISTANCE _CameraDistance
            #define rotation_speed _RotX
            #define fov radians(35.)
            #define mandelbulb_power _MandelbulbPower
            #define view_radius _ViewRadius
            #define mandelbulb_iter_num _Iterations

            

            float mandelbulb_sdf(float3 pos) {
                float2 cursor = 1;
                float power = 0.5 + (mandelbulb_power - 1.) * (0.5 - cos(_Time.y * radians(360.) / 73.) * 0.5);
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;

                for (int i = 0; i < mandelbulb_iter_num; i++)
                {
                    r = length(z);
                    
                    if (r > 3.) break;

                    // convert to polar coordinates
                    float theta = acos(z.z / r);
                    float phi = atan2(z.x, z.y);

                    dr = pow(r, power - 1.0) * power * dr + 1.0;

                    // scale and rotate the point
                    float zr = pow(r, power);
                    theta = theta * power;
                    phi = phi * power;

                    // convert back to cartesian coordinates
                    z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
                    z += pos;
                }
                return 0.5 * log(r) * r / dr;
            }

            float intersectSDF(float distA, float distB) {
                return max(distA, distB);
            }

            /**
             * Constructive solid geometry union operation on SDF-calculated distances.
             */
            float unionSDF(float distA, float distB) {
                return min(distA, distB);
            }

            /**
             * Constructive solid geometry difference operation on SDF-calculated distances.
             */
            float differenceSDF(float distA, float distB) {
                return max(distA, -distB);
            }

            float scene_sdf(float3 p)
            {
                float planeDist = p.y + 10.;
                return differenceSDF(mandelbulb_sdf(p), planeDist);
            }

            float3 ray_marching(const float3 eye, const float3 ray, out float depth, out float steps)
            {
                depth = 0.;
                steps = 0.;
                float dist;
                float3 intersection_point;

                do
                {
                    intersection_point = eye + depth * ray;
                    dist = scene_sdf(intersection_point);
                    depth += dist;
                    steps++;
                } while (depth < view_radius && dist > EPSILON);

                return intersection_point;
            }

            float3 estimate_normal(const float3 p, const float delta)
            {
                return normalize(float3(
                    scene_sdf(float3(p.x + delta, p.y, p.z)) - scene_sdf(float3(p.x - delta, p.y, p.z)),
                    scene_sdf(float3(p.x, p.y + delta, p.z)) - scene_sdf(float3(p.x, p.y - delta, p.z)),
                    scene_sdf(float3(p.x, p.y, p.z + delta)) - scene_sdf(float3(p.x, p.y, p.z - delta))
                ));
            }


            float2 transformed_coordinates(float4 fragCoord)
            {
                float2 coord = (fragCoord / _ScreenParams.xy) * 2. - 1.;
                //coord.y *= _ScreenParams.y / _ScreenParams.x;
                return coord;
            }

            float contrast(float val, float contrast_offset, float contrast_mid_level)
            {
                return clamp((val - contrast_mid_level) * (1. + contrast_offset) + contrast_mid_level, 0., 1.);
            }

            fixed4 frag(float4 fragCoord : SV_POSITION) : SV_Target
            {
                float2 coord = transformed_coordinates(fragCoord);

                float3 ray = normalize(float3(coord, 1));

                float angle = radians(360.) * _Time.y * rotation_speed;

                float3x3 cam_basis = float3x3(0, cos(angle), sin(angle),
                                             -1, 0, 0,
                                              0, -sin(angle), cos(angle));

                ray = mul(ray, cam_basis);

                float3 cam_pos = -cam_basis[2] * CAMERA_DISTANCE;

                float depth = 0.;
                float steps = 0.;
                float3 intersection_point = ray_marching(cam_pos + EPSILON * ray, ray, depth, steps);

                //AO

                float ao = steps * 0.01;
                ao = 1. - ao / (ao + 0.5);  // reinhard

                const float contrast_offset = 0.3;
                const float contrast_mid_level = _Contrast;
                ao = contrast(ao, contrast_offset, contrast_mid_level);

                float3 normal = estimate_normal(intersection_point, EPSILON * 0.5);

                float3 fColor = ao * (normal * _Saturation + _Brightness);

                // Output to screen
                return float4(fColor, 1.0);
            }
            ENDCG
        }
    }
}
