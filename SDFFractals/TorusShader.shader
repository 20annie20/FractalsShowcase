Shader "Unlit/TorusShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType"="Transparent" }
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

            float sdTorus(float3 p, float2 t)
            {
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
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

                float d = 0.0f;
                // We will step along the ray, 64 times. This value can be changed.
                for (int i = 0; i < 64; i++)
                {
                    // Here's where we calculate a position along our ray. with the very
                    // first iteration, it will be the same as just rayOrigin.
                    float3 pos = rayOrigin + rayDirection * d;

                    // This is the distance from our point, to the nearestPoint on the torus
                    float torusDistance = sdTorus(pos, float2(1.0, 0.25));

                    d += torusDistance;

                }
                float3 pos = rayOrigin + rayDirection * d;

                // What were doing here is, offsetting the position on the X axis, Y axis, and Z axis,
                // and normalizing it to get an estimate of the surface normals
                // Declaring eps as a float3, allows us to do some swizzle magic
                float3 eps = float3(0.0005, 0.0, 0.0);

                // This is ugly, but you can wrap it in a function. All distance functions create
                // a distance field, which is usually in a function called 'map'
                #define TORUS(p) sdTorus(p, float2(1.5, 0.5)).x
                                float3 nor = float3(
                                    TORUS(pos + eps.xyy) - TORUS(pos - eps.xyy),
                                    TORUS(pos + eps.yxy) - TORUS(pos - eps.yxy),
                                    TORUS(pos + eps.yyx) - TORUS(pos - eps.yyx));
                #undef TORUS

                nor = normalize(nor);
                float3 sundir = float3(1., 1., 1.);
                float3 l = normalize(sundir);
                float3 e = normalize(rayOrigin); // with raymarching, eyePos is the rayOrigin
                float3 r = normalize(-reflect(l, nor));

                // The ambient term
                float3 ambient = 0.3;

                // The diffuse term
                float3 diffuse = max(dot(nor, l), 0.0);
                diffuse = clamp(diffuse, 0.0, 1.0);

                // I have some hardcoded values here, 
                float3 specular = 0.04 * pow(max(dot(r, e), 0.0), 0.2);
                specular = clamp(specular, 0.0, 1.0);
                // Now, for the finished torus

                float4 torusCol = float4(ambient + diffuse + specular, 1.0);

                float4 result = lerp(screenColour, torusCol, 0.5f);
                return result;
            }
            ENDCG
        }
    }
}
