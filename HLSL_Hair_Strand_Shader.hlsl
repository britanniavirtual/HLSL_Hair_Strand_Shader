/////////////////////////////////////////////////////////////////////////
// Hair strand shader with billboards
/////////////////////////////////////////////////////////////////////////

//Standard matrix buffer
cbuffer MatrixBuffer : register(b7)
{
	float4x4 worldMatrix;
	float4x4 viewMatrix;
	float4x4 projectionMatrix;
};

cbuffer CameraBuffer : register(b1)
{
        float3 cameraPosition;
        float padding;
};

//Vertex desc
struct VertexIn
{
	float3 top : POSITION0;
        float3 bottom : POSITION1;
	float3 nextTop : POSITION2;
	float3 nextBottom : POSITION3;
	float2 widths : TEXCOORD0;
};


struct PixelIn
{
	float3 top : POSITION0;
   	float3 bottom : POSITION1;
	float3 nextTop : POSITION2;
	float3 nextBottom : POSITION3;
	float width1 : TEXCOORD0;
	float width2 : TEXCOORD1;
};

struct VertexOut
{
	uint vertexIdPassed : VERTEXID;
};

//[Vertex shader]
PixelIn3 VS(VertexIn input)
{
	PixelIn output;

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

	return output;
}

//[Pixel shader]
float4 PS(PixelIn input) : SV_TARGET
{
	float4 newCol;
	newCol.x = 1.0;
	newCol.y = 1.0;
	newCol.z = 1.0;
	newCol.w = 1.0;

	return newCol;
}

struct GeoOut
{
	float4 PosH : SV_POSITION;
};

[maxvertexcount(4)]
void GS(point PixelIn input[1], uint primID : SV_PrimitiveID, inout TriangleStream<GeoOut> OutputStream)
{
	const bool CLOSE_BILLBOARD_TIP = true;

	float strandWidth1 = input[0].width1;
	float strandWidth2 = input[0].width2;

	float4x4 fMatrix = {
					     0.0f, 0.0, 0.0f, 0.0f,
                                             0.0f, 0.0, 0.0f, 0.0f,
					     0.0f, 0.0, 0.0f, 0.0f,
					     0.0f, 0.0, 0.0f, 0.0f
                           };   

	float4x4 worldViewProj = mul( worldMatrix, mul( viewMatrix , projectionMatrix ) );

	////////////////////////////////////////////
	// Create the billboard:
	////////////////////////////////////////////

	//Check if nextTop is >= 4096(This is set to signify the end of strand)
	if(input[0].nextTop.x < 4096)
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

		//Next iteration bottom (=Current top). Align current top with this (Next block)
		float4 pos21b = float4(posNextBottom.xyz + width2b, 1);
		float4 pos22b = float4(posNextBottom.xyz - width2b, 1);
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

		float4 pos11 = float4(posTop1.xyz + width1, 1);//pos22b
		float4 pos12 = float4(posTop1.xyz - width1, 1);//pos21b
		float4 pos21 = float4(posBottom1.xyz + width2, 1);
		float4 pos22 = float4(posBottom1.xyz - width2, 1);

		//-----------------------------------

		//[Output final billboard for current two points]
		//Order affects face orientation.

		GeoOut gout4;
		gout4.PosH = mul(pos22b, worldViewProj);//v3;
		OutputStream.Append(gout4);

		GeoOut gout3;
		gout3.PosH = mul(pos21b, worldViewProj);//v4;
		OutputStream.Append(gout3);

		GeoOut gout1;
		gout1.PosH = mul(pos11, worldViewProj);//v1;
		OutputStream.Append(gout1);
	
		GeoOut gout2;
		gout2.PosH = mul(pos12, worldViewProj);//v2;
		OutputStream.Append(gout2);
	}
	else//Tip draw (No following billboard)
	{
		if(CLOSE_BILLBOARD_TIP)
		{
			float3 pos1;
			float3 pos2;

			pos1.x = input[0].top.x;
			pos1.y = input[0].top.y;
			pos1.z = input[0].top.z;

			pos2.x = input[0].bottom.x;
			pos2.y = input[0].bottom.y;
			pos2.z = input[0].bottom.z;

			float3 tangent = pos2.xyz - pos1.xyz;
			tangent = normalize(tangent);

			float3 eyeVec = mul(cameraPosition, worldMatrix) - pos1;
			float3 sideVec = normalize(cross(eyeVec, tangent));

			float3 width1 =  sideVec * strandWidth1;
			float3 width2 = sideVec * strandWidth2;

			float4 pos11 = float4( pos1.xyz + width1, 1 );
			float4 pos12 = float4( pos1.xyz - width1, 1 );
			float4 pos21 = float4( pos2.xyz + width2, 1 );
			float4 pos22 = float4( pos2.xyz - width2, 1 );

			//[Output billboard]

			GeoOut gout3;
			gout3.PosH = mul(pos21, worldViewProj);//v3;
			OutputStream.Append(gout3);

			GeoOut gout4;
			gout4.PosH = mul(pos22, worldViewProj);//v3;
			OutputStream.Append(gout4);

			GeoOut gout1;
			gout1.PosH = mul(pos11, worldViewProj);//v1;
			OutputStream.Append(gout1);
	
			GeoOut gout2;
			gout2.PosH = mul(pos12, worldViewProj);//v2;
			OutputStream.Append(gout2);
		}
	}
}