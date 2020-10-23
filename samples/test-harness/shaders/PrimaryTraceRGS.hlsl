/*
* Copyright (c) 2019-2020, NVIDIA CORPORATION.  All rights reserved.
*
* NVIDIA CORPORATION and its licensors retain all intellectual property
* and proprietary rights in and to this software, related documentation
* and any modifications thereto.  Any use, reproduction, disclosure or
* distribution of this software and related documentation without an express
* license agreement from NVIDIA CORPORATION is strictly prohibited.
*/

#include "include/RTCommon.hlsl"
#include "include/RTGlobalRS.hlsl"
#include "include/LightingCommon.hlsl"

// ---[ Ray Generation Shader ]---

[shader("raygeneration")]
void RayGen()
{
    uint2 LaunchIndex = DispatchRaysIndex().xy;
    uint2 LaunchDimensions = DispatchRaysDimensions().xy;

    RayDesc ray;
    ray.Origin = cameraPosition;
    ray.TMin = 0.f;
    ray.TMax = 1e27f;

    // Compute the primary ray direction
    float  halfHeight = cameraTanHalfFovY;
    float  halfWidth = (cameraAspect * halfHeight);
    float3 lowerLeftCorner = cameraPosition - (halfWidth * cameraRight) - (halfHeight * cameraUp) + cameraForward;
    float3 horizontal = (2.f * halfWidth) * cameraRight;
    float3 vertical = (2.f * halfHeight) * cameraUp;

    float s = ((float)LaunchIndex.x + 0.5f) / (float)LaunchDimensions.x;
    float t = 1.f - (((float)LaunchIndex.y + 0.5f) / (float)LaunchDimensions.y);

    ray.Direction = (lowerLeftCorner + s * horizontal + t * vertical) - ray.Origin;

    // Primary Ray Trace
    PackedPayload packedPayload = (PackedPayload)0;
    TraceRay(
        SceneBVH,
        RAY_FLAG_CULL_BACK_FACING_TRIANGLES,
        0xFF,
        0,
        1,
        0,
        ray,
        packedPayload);

    // Ray Miss, early out.
    if (packedPayload.hitT < 0.f)
    {
        GBufferA[LaunchIndex] = float4(SkyIntensity.xxx, 0.f);
        GBufferB[LaunchIndex].w = -1.f;
        return;
    }

    // Unpack the payload
    Payload payload = UnpackPayload(packedPayload);

    // Compute direct diffuse lighting
    float3 diffuse = DirectDiffuseLighting(payload, NormalBias, ViewBias, SceneBVH);

    // Write the GBuffer
    GBufferA[LaunchIndex] = float4(payload.albedo, 1.f);
    GBufferB[LaunchIndex] = float4(payload.worldPosition, payload.hitT);
    GBufferC[LaunchIndex] = float4(payload.normal, 1.f);
    GBufferD[LaunchIndex] = float4(diffuse, 1.f);
}
