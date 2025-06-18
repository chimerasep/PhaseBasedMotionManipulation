Shader "Hidden/PyramidReconstruction"
{
    Properties
    {
        _PyramidTexture0 ("Pyramid Texture 0", 2D) = "white" {}
        _PyramidTexture1 ("Pyramid Texture 1", 2D) = "white" {}
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

            sampler2D _PyramidTexture0;
            sampler2D _PyramidTexture1;
            float4 _MainTex_TexelSize;
            
            // Pyramid parameters
            int _Level;
            int _Orientation;
            int _TotalOrientations;
            int _HalfOctave;
            
            // Constants
            static const float PI = 3.14159265359;
            static const float PI2 = 6.28318530718;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Complex number operations
            float2 complex_mult(float2 a, float2 b)
            {
                return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
            }

            float2 complex_conj(float2 a)
            {
                return float2(a.x, -a.y);
            }

            // Generate oriented filter kernel (same as decomposition)
            float2 generate_oriented_filter(float2 uv, float orientation, float scale)
            {
                // Convert to polar coordinates
                float2 centered_uv = uv * 2.0 - 1.0;
                float r = length(centered_uv);
                float theta = atan2(centered_uv.y, centered_uv.x);
                
                // Create oriented filter
                float orientation_angle = orientation * PI2 / _TotalOrientations;
                float angle_diff = theta - orientation_angle;
                
                // Radial component (Gaussian)
                float radial = exp(-r * r / (2.0 * scale * scale));
                
                // Angular component (oriented)
                float angular = cos(angle_diff);
                
                // Combine into complex filter
                float2 filter = float2(radial * angular, radial * sin(angle_diff));
                
                return filter;
            }

            float4 frag (v2f i) : SV_Target
            {
                return tex2D(_PyramidTexture0, i.uv);
            }
            ENDCG
        }
    }
} 