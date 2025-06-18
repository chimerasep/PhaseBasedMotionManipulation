Shader "Hidden/ComplexSteerablePyramid"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            sampler2D _MainTex;
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

            // Generate oriented filter kernel
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
                // Calculate scale based on pyramid level
                float scale = pow(2.0, _Level);
                if (_HalfOctave == 1)
                    scale *= sqrt(2.0);
                
                // Get orientation angle
                float orientation = _Orientation * PI2 / _TotalOrientations;
                
                // Generate filter for this orientation and scale
                float2 filter = generate_oriented_filter(i.uv, orientation, scale);
                
                // Sample input texture
                float4 input = tex2D(_MainTex, i.uv);
                
                // Convert input to complex number (assuming grayscale input)
                float2 input_complex = float2(input.r, 0.0);
                
                // Apply filter
                float2 filtered = complex_mult(input_complex, filter);
                
                // Output complex result (real in R, imaginary in G)
                // Also output magnitude in B for visualization
                float magnitude = length(filtered);
                return float4(filtered.x, filtered.y, magnitude, 1.0);
            }
            ENDCG
        }
    }
} 