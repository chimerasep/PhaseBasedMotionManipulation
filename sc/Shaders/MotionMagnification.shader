Shader "Hidden/MotionMagnification"
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
            
            // Magnification parameters
            float _MagnificationFactor;
            float _Sigma;
            float _Attenuate;

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
                
                // Calculate magnitude and phase
                float magnitude = length(input_complex);
                float phase = atan2(input_complex.y, input_complex.x);
                
                // Apply magnification to phase
                float magnified_phase = phase * _MagnificationFactor;
                
                // Convert back to complex
                float2 magnified_complex = float2(
                    magnitude * cos(magnified_phase),
                    magnitude * sin(magnified_phase)
                );
                
                // Apply amplitude-weighted blur if needed
                if (_Sigma > 0.0)
                {
                    float2 sum = float2(0.0, 0.0);
                    float weight_sum = 0.0;
                    
                    // Simple 3x3 Gaussian blur
                    for (int x = -1; x <= 1; x++)
                    {
                        for (int y = -1; y <= 1; y++)
                        {
                            float2 offset = float2(x, y) * _MainTex_TexelSize.xy;
                            float2 sample_uv = i.uv + offset;
                            
                            // Sample neighboring pixel
                            float4 sample = tex2D(_MainTex, sample_uv);
                            float2 sample_complex = float2(sample.r, sample.g);
                            
                            // Calculate Gaussian weight
                            float weight = exp(-(x*x + y*y) / (2.0 * _Sigma * _Sigma));
                            
                            // Add to weighted sum
                            sum += sample_complex * weight;
                            weight_sum += weight;
                        }
                    }
                    
                    // Normalize
                    magnified_complex = sum / weight_sum;
                }
                
                // Attenuate other frequencies if needed
                if (_Attenuate > 0.0)
                {
                    float attenuation = 1.0 - _Attenuate * (1.0 - smoothstep(0.0, 0.5, magnitude));
                    magnified_complex *= attenuation;
                }
                
                // Output magnified result with magnitude in B channel
                float output_magnitude = length(magnified_complex);
                return float4(magnified_complex.x, magnified_complex.y, output_magnitude, 1.0);
            }
            ENDCG
        }
    }
} 