// Motion vector shader for Skinner Trail
#include "Common.cginc"

float4x4 _NonJitteredVP;
float4x4 _PreviousVP;
float4x4 _PreviousM;

sampler2D _PositionBuffer;
sampler2D _VelocityBuffer;
sampler2D _OrthnormBuffer;

sampler2D _PreviousPositionBuffer;
sampler2D _PreviousVelocityBuffer;
sampler2D _PreviousOrthnormBuffer;

// Line width modifier
half _SpeedToWidthMin;
half _SpeedToWidthMax;
half _Width;

struct appdata
{
    float4 vertex : POSITION;
    float2 texcoord1 : TEXCOORD1;
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float4 transfer0 : TEXCOORD0;
    float4 transfer1 : TEXCOORD1;
};

v2f vert(appdata data)
{
    // Fetch samples from the animatio kernel.
    float4 texcoord = float4(data.vertex.xy, 0, 0);
    float3 P0 = tex2Dlod(_PreviousPositionBuffer, texcoord).xyz;
    float3 V0 = tex2Dlod(_PreviousVelocityBuffer, texcoord).xyz;
    float4 B0 = tex2Dlod(_PreviousOrthnormBuffer, texcoord);
    float3 P1 = tex2Dlod(_PositionBuffer, texcoord).xyz;
    float3 V1 = tex2Dlod(_VelocityBuffer, texcoord).xyz;
    float4 B1 = tex2Dlod(_OrthnormBuffer, texcoord);

    // Binormal vector
    half3 binormal0 = StereoInverseProjection(B0.zw);
    half3 binormal1 = StereoInverseProjection(B1.zw);

    // Line width
    half width = _Width * data.vertex.z * (1 - data.vertex.y);
    half width0 = width * smoothstep(_SpeedToWidthMin, _SpeedToWidthMax, length(V0));
    half width1 = width * smoothstep(_SpeedToWidthMin, _SpeedToWidthMax, length(V1));

    // Modify the vertex positions.
    float4 vp0 = float4(P0 + binormal0 * width0, 1);
    float4 vp1 = float4(P1 + binormal1 * width1, 1);

    // Transfer the data to the pixel shader.
    v2f o;
    o.vertex = UnityObjectToClipPos(vp1);
    o.transfer0 = mul(_PreviousVP, mul(_PreviousM, vp0));
    o.transfer1 = mul(_NonJitteredVP, mul(unity_ObjectToWorld, vp1));
    return o;
}

half4 frag(v2f i) : SV_Target
{
    float3 hp0 = i.transfer0.xyz / i.transfer0.w;
    float3 hp1 = i.transfer1.xyz / i.transfer1.w;

    float2 vp0 = (hp0.xy + 1) / 2;
    float2 vp1 = (hp1.xy + 1) / 2;

#if UNITY_UV_STARTS_AT_TOP
    vp0.y = 1 - vp0.y;
    vp1.y = 1 - vp1.y;
#endif

    return half4(vp1 - vp0, 0, 1);
}