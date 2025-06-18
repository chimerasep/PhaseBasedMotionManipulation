Shader "Hidden/TemporalFilter"
{
    Properties
    {
        _MainTex ("Current Frame", 2D) = "white" {}
        _PreviousTex ("Previous Frame", 2D) = "white" {}
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
            sampler2D _PreviousTex;
            float4 _MainTex_TexelSize;
            
            // Filter parameters
            float _LowFreq;
            float _HighFreq;
            float _Lambda;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Sample current and previous frames
                float4 current = tex2D(_MainTex, i.uv);
                float4 previous = tex2D(_PreviousTex, i.uv);
                
                // Extract complex coefficients
                float2 current_complex = float2(current.r, current.g);
                float2 previous_complex = float2(previous.r, previous.g);
                
                // Calculate phase difference
                float2 phase_diff = float2(
                    current_complex.x * previous_complex.x + current_complex.y * previous_complex.y,
                    current_complex.y * previous_complex.x - current_complex.x * previous_complex.y
                );
                
                // Normalize phase difference
                float phase_mag = length(phase_diff);
                if (phase_mag > 0.0)
                    phase_diff /= phase_mag;
                
                // Apply frequency bandpass filter
                float freq = length(current_complex);
                float filter = smoothstep(_LowFreq, _HighFreq, freq) * (1.0 - smoothstep(_HighFreq, _HighFreq * 1.5, freq));
                
                // Apply temporal filtering
                float2 filtered = lerp(previous_complex, current_complex, _Lambda * filter);
                
                // Output filtered result with magnitude in B channel
                float magnitude = length(filtered);
                return float4(filtered.x, filtered.y, magnitude, 1.0);
            }
            ENDCG
        }
    }
} 