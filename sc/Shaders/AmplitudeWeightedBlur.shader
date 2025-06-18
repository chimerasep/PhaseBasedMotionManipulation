Shader "Hidden/AmplitudeWeightedBlur"
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
            
            // Blur parameters
            float _Sigma;
            float _KernelWidth;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Sample input texture (complex coefficients)
                float4 input = tex2D(_MainTex, i.uv);
                float2 input_complex = float2(input.r, input.g);
                
                // Calculate input magnitude
                float input_magnitude = length(input_complex);
                
                // Initialize weighted sum
                float2 sum = float2(0.0, 0.0);
                float weight_sum = 0.0;
                
                // Calculate kernel size based on sigma
                int kernel_size = min(int(_KernelWidth), 7); // Limit kernel size for performance
                int half_kernel = kernel_size / 2;
                
                // Apply Gaussian blur weighted by amplitude
                for (int x = -half_kernel; x <= half_kernel; x++)
                {
                    for (int y = -half_kernel; y <= half_kernel; y++)
                    {
                        float2 offset = float2(x, y) * _MainTex_TexelSize.xy;
                        float2 sample_uv = i.uv + offset;
                        
                        // Sample neighboring pixel
                        float4 sample = tex2D(_MainTex, sample_uv);
                        float2 sample_complex = float2(sample.r, sample.g);
                        float sample_magnitude = length(sample_complex);
                        
                        // Calculate Gaussian weight
                        float weight = exp(-(x*x + y*y) / (2.0 * _Sigma * _Sigma));
                        
                        // Weight by amplitude
                        weight *= sample_magnitude;
                        
                        // Add to weighted sum
                        sum += sample_complex * weight;
                        weight_sum += weight;
                    }
                }
                
                // Normalize
                float2 blurred_complex = sum / max(weight_sum, 0.0001);
                
                // Output blurred result with magnitude in B channel
                float output_magnitude = length(blurred_complex);
                return float4(blurred_complex.x, blurred_complex.y, output_magnitude, 1.0);
            }
            ENDCG
        }
    }
} 