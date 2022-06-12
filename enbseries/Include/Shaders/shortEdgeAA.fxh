// Ported from AstrayFX by BlueSkyDefender: https://github.com/BlueSkyDefender/AstrayFX/blob/master/Shaders/NFAA.fx
// ENB Port by Adyss

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//* Normal Filter Anti Aliasing.
//* For ReShade 3.0+ & Freestyle
//*  ---------------------------------
//*                                                                          NFAA
//* Due Diligence
//* Based on port by b34r
//* https://www.gamedev.net/forums/topic/580517-nfaa---a-post-process-anti-aliasing-filter-results-implementation-details/?page=2
//* If I missed any please tell me.
//*
//* LICENSE
//* ============
//* Normal Filter Anti Aliasing is licenses under: Attribution-NoDerivatives 4.0 International
//*
//* You are free to:
//* Share - copy and redistribute the material in any medium or format
//* for any purpose, even commercially.
//* The licensor cannot revoke these freedoms as long as you follow the license terms.
//* Under the following terms:
//* Attribution - You must give appropriate credit, provide a link to the license, and indicate if changes were made.
//* You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
//*
//* NoDerivatives - If you remix, transform, or build upon the material, you may not distribute the modified material.
//*
//* No additional restrictions - You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
//*
//* https://creativecommons.org/licenses/by-nd/4.0/
//*
//* Have fun,
//* Jose Negrete AKA BlueSkyDefender
//*
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_INPUT
{
    float3 pos     : POSITION;
    float2 txcoord : TEXCOORD0;
};
struct VS_OUTPUT
{
    float4 pos     : SV_POSITION;
    float2 txcoord : TEXCOORD0;
};

VS_OUTPUT VS_Draw(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    OUT.pos = float4(IN.pos.xyz, 1.0);
    OUT.txcoord.xy = IN.txcoord.xy;
    return OUT;
}