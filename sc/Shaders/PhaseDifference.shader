Shader "Custom/PhaseDifference" // Shader adını değiştirdim
{
    Properties
    {
        _CurrentDFT ("Current DFT", 2D) = "white" {}
        _PreviousDFT ("Previous DFT", 2D) = "white" {}
        _PhaseScale ("Phase Scale (Motion Amp)", Range(0.1, 50.0)) = 10.0 // Büyütme faktörü
        _Threshold ("Magnitude Threshold", Range(0.0, 0.1)) = 0.01   // Gürültü eşiği
        _MagnitudeScale ("Magnitude Scale (Brightness)", Range(0.1, 5.0)) = 1.0 // Parlaklık ölçeklemesi (isteğe bağlı)
        // _Attenuation ("Use Attenuation", Range(0, 1)) = 0 // Zayıflatma kullan (opsiyonel, 0=Hayır, 1=Evet)
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

            sampler2D _CurrentDFT;
            sampler2D _PreviousDFT;
            float _PhaseScale;
            float _Threshold;
            float _MagnitudeScale;
            // float _Attenuation; // Zayıflatma için değişken (aktif değil)

            #define PI 3.14159265359
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            // Helper function to shift UV coordinates for centered FFT spectrum
            // DFT sonucu genellikle köşede DC bileşeni olacak şekilde gelir,
            // bu fonksiyon onu merkeze taşır.
            float2 fftShift(float2 coord) {
                // Koordinatı 0.5 kaydır ve 1.0 modunu al
                // Örn: 0 -> 0.5, 0.4 -> 0.9, 0.5 -> 0.0, 0.9 -> 0.4
                return fmod(coord + 0.5, 1.0);
            }
            
            float4 frag (v2f i) : SV_Target
            {
                // Apply FFT shift to center the DC component
                float2 shiftedUV = fftShift(i.uv);
                
                // Sample from both textures (DFT results) at the shifted coordinates
                // DFT sonucu genellikle rg kanallarında kompleks sayı (real, imaginary) olarak saklanır
                float2 fftCurr = tex2D(_CurrentDFT, shiftedUV).rg; 
                float2 fftPrev = tex2D(_PreviousDFT, shiftedUV).rg; 
                
                // Calculate magnitude and phase for the current frame's DFT component
                float magnitudeCurr = length(fftCurr);
                float phaseCurr = atan2(fftCurr.y, fftCurr.x); // atan2(imaginary, real) -> [-PI, PI]
                
                // Calculate phase for the previous frame's DFT component
                float phasePrev = atan2(fftPrev.y, fftPrev.x);
                
                // Calculate the difference in phase between the current and previous frame
                float phaseDiff = phasePrev - phaseCurr;
                
                // Wrap the phase difference to the range [-PI, PI] to handle angle wrap-around
                // E.g., if phaseCurr = 0.1*PI and phasePrev = 1.9*PI, diff is -1.8*PI (correct)
                // not 0.1*PI - 1.9*PI = -1.8*PI
                // if phaseCurr = -0.9*PI and phasePrev = 0.9*PI, diff is -1.8*PI (correct)
                // Naive diff would be -1.8*PI.
                // if phaseCurr = 0.1*PI and phasePrev = -1.9*PI, diff is 2.0*PI, should be 0
                // Let's check the logic:
                // Wrap: (diff + PI) % (2*PI) - PI
                // Example 1: phaseDiff = -1.8*PI -> (-1.8*PI + PI) % (2*PI) - PI = -0.8*PI % (2*PI) - PI = -0.8*PI - PI = -1.8*PI (Correct)
                // Example 2: phaseDiff = 2.0*PI -> (2.0*PI + PI) % (2*PI) - PI = 3.0*PI % (2*PI) - PI = 1.0*PI - PI = 0 (Correct)
                // Example 3: phaseDiff = -2.0*PI -> (-2.0*PI + PI) % (2*PI) - PI = -1.0*PI % (2*PI) - PI = -1.0*PI - PI = -2.0*PI -> should be 0?
                // Let's use the if/else logic as it's clearer:
                if (phaseDiff > PI)
                    phaseDiff -= 2.0 * PI; // Wrap down (e.g., 3*PI/2 becomes -PI/2)
                else if (phaseDiff < -PI)
                    phaseDiff += 2.0 * PI; // Wrap up (e.g., -3*PI/2 becomes PI/2)

                // Apply threshold: ignore phase differences for frequency components with very low energy/magnitude
                // This helps reduce noise amplification.
                if (magnitudeCurr < _Threshold)
                {
                    phaseDiff = 0.0; // Treat as no phase change if magnitude is too low
                }
                
                // Magnify the phase difference. This is the core of motion magnification.
                // A larger _PhaseScale amplifies the perceived motion.
                float magnifiedPhaseDiff = phaseDiff * _PhaseScale; 
                
                // Calculate the new phase for the output.
                // We add the *magnified* phase difference to the *original* current phase.
                // This modifies the phase based on the detected change.
                float newPhase = phaseCurr + magnifiedPhaseDiff; 
                
                // --- Optional: Attenuation ---
                // If you want to implement the attenuation mentioned in the Python code:
                // Attenuation replaces the current phase with the reference (previous) phase
                // before adding the magnified difference. This can isolate the magnified motion.
                // if (_Attenuation > 0.5) // Use previous phase as base if attenuation is enabled
                // {
                //     newPhase = phasePrev + magnifiedPhaseDiff; 
                // }
                // else // Default: use current phase as base
                // {
                //     newPhase = phaseCurr + magnifiedPhaseDiff; 
                // }
                 // --- End Optional: Attenuation ---


                // Scale the magnitude (optional). 
                // _MagnitudeScale = 1.0 means no change in brightness.
                // Values > 1 increase brightness, < 1 decrease brightness of the components.
                //float finalMagnitude = magnitudeCurr * _MagnitudeScale;
                float finalMagnitude = magnitudeCurr;

                // Reconstruct the complex number (Real, Imaginary) using the new phase and final magnitude
                float2 result;
                result.x = finalMagnitude * cos(newPhase); // Real part = magnitude * cos(angle)
                result.y = finalMagnitude * sin(newPhase); // Imaginary part = magnitude * sin(angle)
                
                // Return the result. 
                // rg stores the modified complex number (Real, Imaginary).
                // b (blue channel) can optionally store the final magnitude for debugging/visualization.
                // a (alpha channel) is typically 1.0 for opaque shaders.
                return float4(result.x, result.y, finalMagnitude, 1.0); 
            }
            ENDCG
        }
    }
    Fallback "Diffuse" // Fallback shader if this one fails on hardware
}