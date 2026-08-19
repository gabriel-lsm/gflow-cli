<#
.SYNOPSIS
    Geracao massiva de videos 16s (2 cortes de 8s juntos) para 5 pastas especificas.
    Retomavel automaticamente - imagens ja processadas sao puladas.

.DESCRIPTION
    Para cada imagem, o script faz:
      1. Roda gflow video i2v para gerar o 1º corte de 8s (captura o media_id).
      2. Roda gflow video i2v para gerar o 2º corte de 8s (captura o media_id).
      3. Roda gflow scene create juntando os 2 cortes em um unico arquivo.
#>

[CmdletBinding()]
param(
    [string]$GflowRoot = "c:\Users\gabri\OneDrive\Documentos\Claude Code\gflow-cli",
    [string]$ProjectId = "8d48b52c-7b27-4f54-a8c6-84c7c7fb7bac",
    [int]$DelaySeconds = 5,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$env:PYTHONUTF8 = "1"

# The 5 folders provided by user
$Folders = @(
    "C:\Users\gabri\Videos\Tiktok Shop\produtos\Retinol\Lote 2",
    "C:\Users\gabri\Videos\Tiktok Shop\produtos\Clareador de axilas\Lote 1",
    "C:\Users\gabri\Videos\Tiktok Shop\produtos\Protetor Solar (Beiermei)\Lote 2\imgs",
    "C:\Users\gabri\Videos\Tiktok Shop\produtos\Magic Muuh\Lote 2",
    "C:\Users\gabri\Videos\Tiktok Shop\produtos\EnvyHair\Lote 2"
)

# Product descriptions
$ProductDescs = @{
    "Retinol" = "BEIERMEI - Retinol Anti-Aging Anti-Wrinkle Serum. Frasco conta-gotas quadrado em vidro laranja ambar com gargalo dourado e conta-gotas branco. Ativos: 0.3% Retinyl Palmitate, 0.1% Grade Pro-Xylane, 0.5% Vitamin E Acetate. Powerful Anti-Wrinkle, Firm and Smooth Skin, Repair and Anti-Aging. Codigo: BE-AA001. 30ml / 1.0FL.OZ."
    "Protetor Solar \(Beiermei\)" = "BEIERMEI - Correcting and Preventing Multi-Shield Sunscreen SPF80PA+++. Pote branco compacto arredondado com tampa esferica branca e anel superior amarelo. SPF 80 PA++1. Tone-Up + Prevent, E-Shield Blocking. BEIERMEI."
    "Magic Muuh" = "MUUH Magic - Suplemento Alimentar em Po. Pote cilindrico branco com tampa branca. Colostro Bovino. Ativos: Creatina Pura, Coenzima Q10, Vitamina B12, Vitamina D3, Zinco, Magnesio. Sabor: Natural Superfood Pink Lemonade. Peso Liq. 150g."
    "EnvyHair" = "Zencial - Envy Hair. Serum Capilar Blend de Oleos. Frasco conta-gotas em vidro ambar marrom com gargalo prata e conta-gotas branco. Oleos: Ricino, Argan, Rosmarinus. Contribui para o crescimento saudavel dos fios. Conteudo 30ml."
    "Clareador de axilas" = "" # Missing specific desc, ignored
}

# Read base prompt
$PromptFile = Join-Path $GflowRoot "my prompts\POV\Universal_prompt_pv.txt"
if (-not (Test-Path $PromptFile)) {
    Write-Host "[ERRO] Arquivo de prompt base não encontrado: $PromptFile" -ForegroundColor Red
    exit 1
}
$BasePrompt = Get-Content -Path $PromptFile -Raw -Encoding UTF8

function Get-Prompt {
    param([string]$FolderPath)
    
    $prompt = $BasePrompt
    $prompt = $prompt -replace "\(Optional\)\[Portuguese speech\]", ""
    
    $desc = ""
    foreach ($key in $ProductDescs.Keys) {
        if ($FolderPath -match $key) {
            $desc = $ProductDescs[$key]
            # Handle product specific references like in previous script
            $replacementKey = $key -replace "\\", "" # Remove escape chars for the key
            $prompt = $prompt -replace "Only the FEROFIRE perfume bottle may appear\.", "Only the $replacementKey product may appear."
            break
        }
    }
    
    $prompt = $prompt -replace "\(Optional\)\[Product description or text in the product to get a high fidelity\]", $desc
    return $prompt.Trim()
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "INICIO DA GERACAO MASSIVA DE VIDEOS 16s" -ForegroundColor Cyan
Write-Host "Projeto: $ProjectId" -ForegroundColor Cyan
Write-Host "DryRun:  $DryRun" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

foreach ($folder in $Folders) {
    if (-not (Test-Path $folder)) {
        Write-Host "Pasta nao encontrada, pulando: $folder" -ForegroundColor Yellow
        continue
    }

    $folderName = Split-Path $folder -Leaf
    if ($folderName -eq "imgs") {
        $folderName = Split-Path (Split-Path $folder) -Leaf
    }
    
    $prompt = Get-Prompt -FolderPath $folder
    $promptTempFile = [System.IO.Path]::GetTempFileName() + ".txt"
    [System.IO.File]::WriteAllText($promptTempFile, $prompt, [System.Text.Encoding]::UTF8)

    # Output videos path
    $videosPath = Join-Path $folder "videos"
    if ($folder -match "imgs$") {
        $videosPath = Join-Path (Split-Path $folder) "videos"
    }
    
    if (-not (Test-Path $videosPath)) {
        New-Item -ItemType Directory -Force -Path $videosPath | Out-Null
    }

    $images = Get-ChildItem -Path $folder -File -Include *.jpeg, *.jpg, *.png -Recurse
    $imgCount = $images.Count

    Write-Host "`n[$folderName] Iniciando: $imgCount imagens" -ForegroundColor Cyan

    $imgIndex = 0
    foreach ($img in $images) {
        $imgIndex++
        
        $expectedVideoName = [System.IO.Path]::GetFileNameWithoutExtension($img.Name) + "_16s.mp4"
        $expectedVideoPath = Join-Path $videosPath $expectedVideoName
        
        if (Test-Path $expectedVideoPath) {
            Write-Host "[$folderName] ($imgIndex/$imgCount) Ja existe: $expectedVideoName" -ForegroundColor DarkGray
            continue
        }
        
        Write-Host "[$folderName] ($imgIndex/$imgCount) Processando imagem: $($img.Name)" -ForegroundColor Yellow
        
        if ($DryRun) {
            Write-Host "  [DRYRUN] Gerar Video 1 (8s)"
            Write-Host "  [DRYRUN] Gerar Video 2 (8s)"
            Write-Host "  [DRYRUN] gflow scene create -> $expectedVideoName"
            continue
        }

        # 1. Gerar Video 1
        Write-Host "  Gerando 1º corte de 8s..."
        $startTime = Get-Date
        
        $cmd1 = "uv run python scripts\i2v_json_runner.py --prompt-file `"$promptTempFile`" --initial-frame `"$($img.FullName)`" --project $ProjectId 2>&1"
        $result1 = Invoke-Expression $cmd1 | Out-String
        $exitCode1 = $LASTEXITCODE

        if ($exitCode1 -ne 0) {
            Write-Host "  Falha no 1º corte (exit=$exitCode1)" -ForegroundColor Red
            Write-Host "  Saida: $result1" -ForegroundColor Red
            continue
        }
        $mediaId1 = $result1.Trim()
        $elapsed1 = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "  1º corte OK (${elapsed1}s): $mediaId1" -ForegroundColor Green

        # Delay
        Start-Sleep -Seconds $DelaySeconds

        # 2. Gerar Video 2
        Write-Host "  Gerando 2º corte de 8s..."
        $startTime = Get-Date
        
        $cmd2 = "uv run python scripts\i2v_json_runner.py --prompt-file `"$promptTempFile`" --initial-frame `"$($img.FullName)`" --project $ProjectId 2>&1"
        $result2 = Invoke-Expression $cmd2 | Out-String
        $exitCode2 = $LASTEXITCODE

        if ($exitCode2 -ne 0) {
            Write-Host "  Falha no 2º corte (exit=$exitCode2)" -ForegroundColor Red
            Write-Host "  Saida: $result2" -ForegroundColor Red
            continue
        }
        $mediaId2 = $result2.Trim()
        $elapsed2 = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "  2º corte OK (${elapsed2}s): $mediaId2" -ForegroundColor Green

        # 3. Juntar com gflow scene create
        Write-Host "  Juntando vídeos na cena (server-side concat)..."
        $sceneCmd = "uv run gflow scene create --project $ProjectId $mediaId1 $mediaId2 -o `"$expectedVideoPath`" 2>&1"
        $sceneResult = Invoke-Expression $sceneCmd | Out-String
        $sceneExitCode = $LASTEXITCODE

        if ($sceneExitCode -ne 0) {
            Write-Host "  Falha ao criar cena (exit=$sceneExitCode)" -ForegroundColor Red
            Write-Host "  Saida: $sceneResult" -ForegroundColor Red
            continue
        }

        if (Test-Path $expectedVideoPath) {
            Write-Host "  SUCESSO: Video de 16s salvo em $expectedVideoName" -ForegroundColor Green
        } else {
            Write-Host "  Falha: Comando scene executou mas arquivo não foi encontrado em $expectedVideoPath" -ForegroundColor Red
        }

        Start-Sleep -Seconds $DelaySeconds
    }
    
    Remove-Item $promptTempFile -ErrorAction SilentlyContinue
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "GERACAO CONCLUIDA" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
