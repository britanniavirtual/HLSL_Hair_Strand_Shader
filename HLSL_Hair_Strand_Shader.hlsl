/////////////////////////////////////////////////////////////////////////
// Hair strand shader with billboards
/////////////////////////////////////////////////////////////////////////

SamplerState SampleType;

//Standard matrix buffer
cbuffer MatrixBuffer : register(b7)
{
	float4x4 worldMatrix;
	float4x4 viewMatrix;
	float4x4 projectionMatrix;
};

struct PixelIn3
{
	float3 top : NORMAL;
   	float3 bottom : POSITION1;
	float3 nextTop : POSITION2;
	float3 nextBottom : POSITION3;

	float width1 : TEXCOORD0;
	float width2 : TEXCOORD1;
	uint vertexId : TEXCOORD2;
};

struct GeoOut
{
	float4 PosH : SV_POSITION;//Only this needed for showing a basic quad with the PS
	float3 PosW : POSITION3;
};

cbuffer CamBuffer : register(b1)
{
    float3 cameraPosition;
    float padding;
};

//Material of the current object
cbuffer MaterialBuffer : register(b4)
{
	float4 CurAmbient;
	float4 CurDiffuse;
	float4 CurSpecular;
	float4 CurReflect;
};


//Vertex desc
struct VertexIn3
{
	uint vertexId : SV_VertexId;

	float3 top : POSITION0;//Positions of the current billboard received as vertex data
    	float3 bottom : POSITION1;
	float3 nextTop : POSITION2;
	float3 nextBottom : POSITION3;
	float2 widths : TEXCOORD0;
};

//[Pixel shader]
float4 PS(GeoOut input) : SV_TARGET
{
	return float4(.2,0,0,1);//Solid strand color
}


//[Vertex shader]
PixelIn3 VS(VertexIn3 input)
{
	PixelIn3 output;

	output.vertexId = input.vertexId;

	output.top.x = input.top.x;
	output.top.y = input.top.y;
	output.top.z = input.top.z;

	output.bottom.x = input.bottom.x;
	output.bottom.y = input.bottom.y;
	output.bottom.z = input.bottom.z;

	output.width1 = input.widths.x;//Bottom width
	output.width2 = input.widths.y;//Top width

	output.nextTop.x = input.nextTop.x;
	output.nextTop.y = input.nextTop.y;
	output.nextTop.z = input.nextTop.z;

	output.nextBottom.x = input.nextBottom.x;
	output.nextBottom.y = input.nextBottom.y;
	output.nextBottom.z = input.nextBottom.z;

	output.top = mul(output.top, worldMatrix);
	output.bottom = mul(output.bottom, worldMatrix);
	output.nextTop = mul(output.nextTop, worldMatrix);
	output.nextBottom = mul(output.nextBottom, worldMatrix);

	return output;
}


//[Strand GS]
[maxvertexcount(4)]
void GS(point PixelIn3 input[1], uint primID : SV_PrimitiveID, inout TriangleStream<GeoOut> OutputStream)
{
	float4 testColor = {0,0,0,1};

	float strandWidth1 = input[0].width1;
	float strandWidth2 = input[0].width2;

	float4x4 worldViewProj = mul( worldMatrix, mul( viewMatrix, projectionMatrix ) );

	////////////////////////////////////////////
	// Create billboards:
	////////////////////////////////////////////

	if(input[0].nextTop.x < 4096)//If 4096 its a tip billboard
	{
		float3 posTop1;
		float3 posBottom1;

		float3 posNextTop;
		float3 posNextBottom;

		posNextTop.x = input[0].nextTop.x;
		posNextTop.y = input[0].nextTop.y;
		posNextTop.z = input[0].nextTop.z;

		posNextBottom.x = input[0].nextBottom.x;
		posNextBottom.y = input[0].nextBottom.y;
		posNextBottom.z = input[0].nextBottom.z;

		posTop1.x = input[0].top.x;
		posTop1.y = input[0].top.y;
		posTop1.z = input[0].top.z;

		posBottom1.x = input[0].bottom.x;
		posBottom1.y = input[0].bottom.y;
		posBottom1.z = input[0].bottom.z;
		//

		float3 tangentb = posNextBottom.xyz - posNextTop.xyz;
		tangentb = normalize(tangentb);

		float3 eyeVecb = mul(cameraPosition, worldMatrix) - posNextTop;
		float3 sideVecb = normalize(cross(eyeVecb, tangentb));

		float3 width1b = sideVecb * strandWidth1;
		float3 width2b = sideVecb * strandWidth2;

		//Align positions with nexttop
		float4 pos11b = float4(posNextTop.xyz + width1b, 1);
		float4 pos12b = float4(posNextTop.xyz - width1b, 1);

		//Next iteration bottom (=Current top). Align current top with this (Next block)
		float4 pos21b = float4(posNextBottom.xyz + width2b, 1);
		float4 pos22b = float4(posNextBottom.xyz - width2b, 1);
		
		//(1/2) [End two points of the quad]

		//Rotating the world matrix throws it (Empty side drawn)
		float3 tangent = posBottom1.xyz - posTop1.xyz;
		tangent = normalize(tangent);
		float3 eyeVec = mul( cameraPosition, worldMatrix ) - posTop1;
		float3 sideVec = normalize( cross( eyeVec, tangent ) );

		float3 width1 = sideVec * strandWidth1;
		float3 width2 = sideVec * strandWidth2;

		float4 pos11 = float4(posTop1.xyz + width1, 1);//TOP
		float4 pos12 = float4(posTop1.xyz - width1, 1);
		float4 pos21 = float4(posBottom1.xyz + width2, 1);//BOTTOM
		float4 pos22 = float4(posBottom1.xyz - width2, 1);
		
		//[Output final billboard for current two points]
		//NB: Order affects face orientation.

		//[Upper]

		GeoOut gout4;
		gout4.PosH = mul(pos22b, worldViewProj);//v4;
		gout4.PosW = pos22b.xyz;
		OutputStream.Append(gout4);

		GeoOut gout3;
		gout3.PosH = mul(pos21b, worldViewProj);//v4;
		gout3.PosW = pos21b.xyz;
		OutputStream.Append(gout3);
	
		//[Lower]

		GeoOut gout1;
		gout1.PosH = mul(pos11, worldViewProj);//v2;
		gout1.PosW = pos11.xyz;
		OutputStream.Append(gout1);

		GeoOut gout2;
		gout2.PosH = mul(pos12, worldViewProj);//v2;
		gout2.PosW = pos11.xyz;
		OutputStream.Append(gout2);
	}
	else//Tip of strand billboard
	{

		float3 posNextTop;
		float3 posNextBottom;

		//
		posNextTop.x = input[0].nextTop.x;
		posNextTop.y = input[0].nextTop.y;
		posNextTop.z = input[0].nextTop.z;

		posNextBottom.x = input[0].nextBottom.x;
		posNextBottom.y = input[0].nextBottom.y;
		posNextBottom.z = input[0].nextBottom.z;
		//

		float3 tangentb = posNextBottom.xyz - posNextTop.xyz;
		tangentb = normalize(tangentb);

		float3 eyeVecb = mul(cameraPosition, worldMatrix) - posNextTop;
		float3 sideVecb = normalize(cross(eyeVecb, tangentb));

		float3 width1b = sideVecb * strandWidth1;
		float3 width2b = sideVecb * strandWidth2;

		//Align positions with nexttop
		float4 pos11b = float4(posNextTop.xyz + width1b, 1);
		float4 pos12b = float4(posNextTop.xyz - width1b, 1);

		//Next iteration bottom (=Current top)
		float4 pos21b = float4(posNextBottom.xyz + width2b, 1);
		float4 pos22b = float4(posNextBottom.xyz - width2b, 1);

		//-----------------------------------
		//2) Current upper/lower
		//-----------------------------------

		float3 posTop1;
		float3 posBottom1;

		posTop1.x = input[0].top.x;
		posTop1.y = input[0].top.y;
		posTop1.z = input[0].top.z;

		posBottom1.x = input[0].bottom.x;
		posBottom1.y = input[0].bottom.y;
		posBottom1.z = input[0].bottom.z;

		float3 tangent = posBottom1.xyz - posTop1.xyz;
		tangent = normalize(tangent);
		float3 eyeVec = mul( cameraPosition, worldMatrix ) - posTop1;
		float3 sideVec = normalize( cross( eyeVec, tangent ) );

		float3 width1 = sideVec * strandWidth1;
		float3 width2 = sideVec * strandWidth2;

		float4 pos11 = float4(posTop1.xyz + width1, 1);//TOP
		float4 pos12 = float4(posTop1.xyz - width1, 1);
		float4 pos21 = float4(posBottom1.xyz + width2, 1);//BOTTOM
		float4 pos22 = float4(posBottom1.xyz - width2, 1);
		
		//[Output final billboard for current two points]
		//NB: Order affects face orientation.

		//Upper
		GeoOut gout4;
		gout4.PosH = mul(pos22, worldViewProj);
		gout4.PosW = pos21.xyz;
		OutputStream.Append(gout4);

		GeoOut gout3;
		gout3.PosH = mul(pos21, worldViewProj);
		gout3.PosW = pos22.xyz;
		OutputStream.Append(gout3);

		//Lower
		GeoOut gout1;
		gout1.PosH = mul(pos12, worldViewProj);
		gout1.PosW = pos11.xyz;
		OutputStream.Append(gout1);

		GeoOut gout2;
		gout2.PosH = mul(pos11, worldViewProj);
		gout2.PosW = pos12.xyz;
		OutputStream.Append(gout2);
	}
	
	return;
}