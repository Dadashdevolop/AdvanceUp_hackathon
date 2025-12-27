# Optimizes a GLB with Draco mesh compression and KTX2 textures (BasisU ETC1S)
# Requirements: Node.js, npm, and @gltf-transform/cli installed globally
# Run from project root or frontend folder
# Usage:
#   pwsh ./tools/optimize_glb.ps1 -InPath ../assets/3d/ahir.glb -OutPath ../assets/3d/ahir_optimized.glb -MaxTexSize 2048

param(
    [Parameter(Mandatory=$true)] [string]$InPath,
    [Parameter(Mandatory=$true)] [string]$OutPath,
    [int]$MaxTexSize = 2048
)

function Ensure-GltfTransform {
    $exists = (Get-Command gltf-transform -ErrorAction SilentlyContinue) -ne $null
    if (-not $exists) {
        Write-Host 'Installing @gltf-transform/cli globally...' -ForegroundColor Cyan
        npm i -g @gltf-transform/cli
    }
}

function Optimize-GLB {
    param([string]$src, [string]$dst, [int]$maxSize)

    $tmp = Join-Path ([System.IO.Path]::GetDirectoryName($dst)) ("$( [System.IO.Path]::GetFileNameWithoutExtension($dst) )_tmp.glb")

    Write-Host "Draco compressing: $src -> $tmp" -ForegroundColor Green
    gltf-transform draco "$src" "$tmp"

    Write-Host "Converting textures to KTX2 (ETC1S), resize=$maxSize: $tmp -> $dst" -ForegroundColor Green
    gltf-transform etc1s "$tmp" "$dst" --resize $maxSize --slots "baseColor,emissive,metallicRoughness,normal,occlusion" --filter

    Write-Host "Inspecting: $dst" -ForegroundColor Green
    gltf-transform inspect "$dst"

    Remove-Item "$tmp" -ErrorAction SilentlyContinue
    Write-Host "Done: $dst" -ForegroundColor Cyan
}

# Main
Ensure-GltfTransform
Optimize-GLB -src $InPath -dst $OutPath -maxSize $MaxTexSize
