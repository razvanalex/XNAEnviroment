float4x4 World;
float4x4 View;
float4x4 Projection;
 
float3 LightDirection = float3(1, -1, 0);
float3 LightColor = float3(1, 1, 1);
float3 AmbientColor = float3(-0.2, -0.2, -0.2);
float WaterHeight = 600;
float4  WaterColor = float4(0.10980f, 0.30196f, 0.49412f, 1.0f);

const static int NoOfTextures = 6;
float TextureTiling[NoOfTextures];

float4 ClipPlane;
bool ClipPlaneEnabled = false;

float3 CameraPosition;

texture Texture1, Texture2, Texture3, Texture4, Texture5, Texture6;

sampler TextureSampler[NoOfTextures] = {
	sampler_state {
		texture = <Texture1>;
		AddressU = Wrap;
		AddressV = Wrap;
		MinFilter = Anisotropic;
		MagFilter = Anisotropic;
	},
	sampler_state {
		texture = <Texture2>;
		AddressU = Wrap;
		AddressV = Wrap;
		MinFilter = Anisotropic;
		MagFilter = Anisotropic;
	},
	sampler_state {
		texture = <Texture3>;
		AddressU = Wrap;
		AddressV = Wrap;
		MinFilter = Anisotropic;
		MagFilter = Anisotropic;
	},
	sampler_state {
		texture = <Texture4>;
		AddressU = Wrap;
		AddressV = Wrap;
		MinFilter = Anisotropic;
		MagFilter = Anisotropic;
	},
	sampler_state {
		texture = <Texture5>;
		AddressU = Wrap;
		AddressV = Wrap;
		MinFilter = Anisotropic;
		MagFilter = Anisotropic;
	},
		sampler_state {
		texture = <Texture6>;
		AddressU = Wrap;
		AddressV = Wrap;
		MinFilter = Anisotropic;
		MagFilter = Anisotropic;
	}
};

texture TexturesMaps1, TexturesMaps2, TexturesMaps3, TexturesMaps4, TexturesMaps5, TexturesMaps6;
sampler TexturesMapSampler[NoOfTextures] = {
	sampler_state {
		texture = <TexturesMaps1>;
		AddressU = Clamp;
		AddressV = Clamp;
		MinFilter = Linear;
		MagFilter = Linear;
	},
	sampler_state {
		texture = <TexturesMaps2>;
		AddressU = Clamp;
		AddressV = Clamp;
		MinFilter = Linear;
		MagFilter = Linear;
	},
	sampler_state {
		texture = <TexturesMaps3>;
		AddressU = Clamp;
		AddressV = Clamp;
		MinFilter = Linear;
		MagFilter = Linear;
	},
	sampler_state {
		texture = <TexturesMaps4>;
		AddressU = Clamp;
		AddressV = Clamp;
		MinFilter = Linear;
		MagFilter = Linear;
	},
	sampler_state {
		texture = <TexturesMaps5>;
		AddressU = Clamp;
		AddressV = Clamp;
		MinFilter = Linear;
		MagFilter = Linear;
	},
		sampler_state {
		texture = <TexturesMaps6>;
		AddressU = Clamp;
		AddressV = Clamp;
		MinFilter = Linear;
		MagFilter = Linear;
	}
};

float DetailTextureTiling;
float DetailDistance = 2500;

texture DetailTexture;
sampler DetailSampler = sampler_state {
	texture = <DetailTexture>;
	AddressU = Wrap;
	AddressV = Wrap;
	MinFilter = Linear;
	MagFilter = Linear;
};


struct VertexShaderInput
{
	float4 Position : POSITION0;
	float2 UV : TEXCOORD0;
	float3 Normal : NORMAL0;
};

struct VertexShaderOutput
{
	float4 Position : POSITION0;
	float2 UV : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float Depth : TEXCOORD2;
	float3 WorldPosition : TEXCOORD3;
	float Height : TEXCOORD4;
};

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
	VertexShaderOutput output;
	
	output.Position = mul(input.Position, mul(World, mul(View, Projection)));
	output.Normal = input.Normal;
	output.UV = input.UV;
	output.Depth = output.Position.z;
	output.WorldPosition = mul(input.Position, World);
	output.Height = input.Position.y;
	return output;
}

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{
	if (ClipPlaneEnabled)
		clip(dot(float4(input.WorldPosition, 1), ClipPlane));

	float3 light = AmbientColor;
		float3 lightDir = normalize(LightDirection);
		float3 normal = normalize(input.Normal);
		light = clamp(light + 0.4f, 0, 1);
	light += saturate(dot(lightDir, normal)) * LightColor;

	float3 Tex[NoOfTextures], TexMaps[NoOfTextures];

	for (int i = 0; i < NoOfTextures; i++)
	{
		Tex[i] = tex2D(TextureSampler[i], input.UV * TextureTiling[i]);
		TexMaps[i] = tex2D(TexturesMapSampler[i], input.UV);
	}

	float dif = 1.0f;
	for (int i = 0; i < NoOfTextures; i++)
		dif -= TexMaps[i].r;

	float3 output = saturate(dif);

	for (int i = 0; i < NoOfTextures; i++)
	{
		output += TexMaps[i].r * Tex[i];
	//	for (int j = i + 1; j < NoOfTextures; j++)
	//		if (TexMaps[i].r != TexMaps[j].r)
	//			output /= 2;
	
	}
	
	float bBlendDist;
	float bBlendWidth;

	float4 waterColor = WaterColor;
	float detailDistance = DetailDistance;
	float sunFactor = 4; //4  7

	if (CameraPosition.y > WaterHeight)
	{
	if (input.Height < WaterHeight && input.WorldPosition.y < WaterHeight)
	{
			detailDistance = 500;

			float BlendDist = WaterHeight - 100;
			float BlendWidth = WaterHeight;
	
			bBlendDist = WaterHeight - 200;
			bBlendWidth = WaterHeight;
		
			//Gradient for XY plane
			float dBlendDist = 2500;
			float dBlendWidth = 5000;

			//Gradient for Height
			float hBlendDist = 5000;
			float hBlendWidth = 10000;
			
			//Gradient for Time
			float Gtime = saturate(1-light);

			float BlendFactor = saturate((input.WorldPosition.y - BlendDist) / (BlendWidth - BlendDist));
			float bBlendFactor = saturate(((input.WorldPosition.y - bBlendDist) / (bBlendWidth - bBlendDist)));
			float dBlendFactor = saturate((pow((pow((input.WorldPosition.z - CameraPosition.z), 2) + pow((input.WorldPosition.x - CameraPosition.x), 2)), 0.5) - dBlendDist) / (dBlendWidth - dBlendDist));
			float hBlendFactor = saturate((input.Depth - hBlendDist) / (hBlendWidth - hBlendDist));
			
			waterColor = lerp(waterColor, waterColor * sunFactor, bBlendFactor);

			output = lerp(waterColor, output * saturate(light), BlendFactor);
			output = lerp(output, WaterColor, dBlendFactor);
			output = lerp(output, WaterColor, hBlendFactor);
			output = lerp(output, WaterColor, Gtime);
		}
		 output *= saturate(light);
	}
	else if (CameraPosition.y < WaterHeight)
	{
		if (input.WorldPosition.y < WaterHeight)
		{
			
			bBlendDist = 400;
			bBlendWidth = 200;
			float dBlendDist = 100;
			float dBlendWidth = 50;
			detailDistance = 200;
			float bBlendFactor = saturate((input.WorldPosition.y - bBlendDist) / bBlendWidth);
			float dBlendFactor = saturate((input.Depth - dBlendDist) / (dBlendWidth - dBlendDist));
			
			waterColor = lerp(waterColor, saturate(waterColor * sunFactor), bBlendFactor);
			light = WaterColor;
			output = lerp(WaterColor / saturate(light), output, dBlendFactor) * saturate(light);

		}
		else output *= saturate(light);
	}

	float3 detail = tex2D(DetailSampler, input.UV * DetailTextureTiling);
	float detailAmt = input.Depth / detailDistance;
	detail = lerp(detail, 1, clamp(detailAmt, 0, 1));
	
	return float4(detail * output, 1);
}

technique Technique1
{
	pass Pass1
	{
		VertexShader = compile vs_3_0 VertexShaderFunction();
		PixelShader = compile ps_3_0 PixelShaderFunction();
	}
}