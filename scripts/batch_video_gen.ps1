<#
.SYNOPSIS
    Geracao massiva de videos POV para 12 produtos do projeto Flow.
    Retomavel automaticamente - imagens ja processadas sao puladas.

.DESCRIPTION
    Para cada produto em $ProductsRoot\{produto}\imgs\*.jpeg:
      1. Monta o prompt correto (universal ou be-an-attractive-man)
      2. Cria pasta $ProductsRoot\{produto}\videos\ se nao existir
      3. Verifica se o video ja foi gerado (skip se sim)
      4. Executa gflow video i2v com model veo-lite-lp, 9:16, 8 segundos
      5. Registra progresso em batch_video_gen.log

.NOTES
    Estimativa: ~2 min por video x 1321 videos ~ 44 horas (retomavel).
    Execute: .\scripts\batch_video_gen.ps1
    Retomar:  .\scripts\batch_video_gen.ps1   (re-executa, pula ja gerados)
    DryRun:   .\scripts\batch_video_gen.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$GflowRoot = "c:\Users\gabri\OneDrive\Documentos\Claude Code\gflow-cli",
    [string]$TiktokShopRoot = "C:\Users\gabri\Videos\Tiktok Shop",
    [string]$ProjectId = "5f9d6103-e16b-45a1-b3c0-345216b149cd",
    [int]$DelaySeconds = 5,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$env:PYTHONUTF8 = "1"

# Resolver pasta com acentos dinamicamente
$ProductsRoot = Get-ChildItem -Path $TiktokShopRoot -Directory |
    Where-Object { $_.Name -like "*deos agendados*" } |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $ProductsRoot) {
    Write-Host "[ERRO FATAL] Pasta 'Videos agendados' nao encontrada em: $TiktokShopRoot" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
$LogFile = Join-Path $GflowRoot "scripts\batch_video_gen.log"
New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts][$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        "INFO"    { Write-Host $line -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $line -ForegroundColor Green }
        "SKIP"    { Write-Host $line -ForegroundColor DarkGray }
        "ERROR"   { Write-Host $line -ForegroundColor Red }
        "WARN"    { Write-Host $line -ForegroundColor Yellow }
        default   { Write-Host $line }
    }
}

# ---------------------------------------------------------------------------
# Produto -> Collection ID + Prompt base + Descricao do produto
# ---------------------------------------------------------------------------
$Products = @(
    @{
        FolderName   = "Be An Attractive Man"
        SearchKey    = "Attractive"
        CollectionId = "0ff888d6-2f6f-43ad-a562-9a5668c0bc5d"
        PromptFile   = "my prompts\POV\pov_prompt_be_an_attractiveman.txt"
        ProductDesc  = $null
    },
    @{
        FolderName   = "Bodysplash feminino"
        SearchKey    = "Bodysplash"
        CollectionId = "f0144fc2-5f78-4aba-8421-b49254e45236"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Barbour's Beauty - My Sweet Delight Body Splash. Frasco spray transparente com tampa protetora transparente e bomba dourada. Rotulo branco com bloco vinho/marsala. Fragancia: Lichia, Peonia e Cedro. Desodorante Corporal. 200ml | 6.76 fl.oz."
    },
    @{
        FolderName   = "Retinol"
        SearchKey    = "Retinol"
        CollectionId = "a5550c6f-cb5c-4576-a459-4eecd6a71e26"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "BEIERMEI - Retinol Anti-Aging Anti-Wrinkle Serum. Frasco conta-gotas quadrado em vidro laranja ambar com gargalo dourado e conta-gotas branco. Ativos: 0.3% Retinyl Palmitate, 0.1% Grade Pro-Xylane, 0.5% Vitamin E Acetate. Powerful Anti-Wrinkle, Firm and Smooth Skin, Repair and Anti-Aging. Codigo: BE-AA001. 30ml / 1.0FL.OZ."
    },
    @{
        FolderName   = "Protetor Solar (Hidrabene)"
        SearchKey    = "Hidrabene"
        CollectionId = "e4182781-db0a-482c-a2ca-e0ba95a29971"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Hidrabene - Protetor Solar Facial CLAREADOR. Bisnaga branca/rosa com tampa rosqueada. FPS 70, UVA + UVB. Ativos: Argila + Niacinamida. Beneficios: Amplo espectro, Toque seco, Rapida absorcao, Clareia a pele, Hidratante, Antissinais, Antioxidante, Hipoalergenico. 50g."
    },
    @{
        FolderName   = "Trans Resveratrol"
        SearchKey    = "Resveratrol"
        CollectionId = "cb165e65-533e-4d15-a467-fbaaaf18dd53"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Quantum Nutrition - Trans Resveratrol. Pote plastico vermelho escuro/bordo com tampa vermelha. Logo NQ em prata. Suplemento alimentar em capsulas. 60 Capsulas vermelhas."
    },
    @{
        FolderName   = "Protetor Solar (Beiermei)"
        SearchKey    = "Beiermei"
        CollectionId = "d9f1af29-ecd1-4921-8ba5-774afb95a65a"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "BEIERMEI - Correcting and Preventing Multi-Shield Sunscreen SPF80PA+++. Pote branco compacto arredondado com tampa esferica branca e anel superior amarelo. SPF 80 PA++1. Tone-Up + Prevent, E-Shield Blocking. BEIERMEI."
    },
    @{
        FolderName   = "ImunoFem"
        SearchKey    = "ImunoFem"
        CollectionId = "d466a3a0-96cd-4c72-8592-dcdc49c42f24"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Maxfem - ImunoFem. Pote cilindrico branco com detalhes lilas/roxo. Ativos: Feno Grego, Beta-Glucana, Cranberry. Suplemento alimentar em capsulas. 60 Caps 500mg | 30g Peso Liquido."
    },
    @{
        FolderName   = "Magic Muuh"
        SearchKey    = "Magic"
        CollectionId = "b43974db-8964-4180-8474-f26d2b07d292"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "MUUH Magic - Suplemento Alimentar em Po. Pote cilindrico branco com tampa branca. Colostro Bovino. Ativos: Creatina Pura, Coenzima Q10, Vitamina B12, Vitamina D3, Zinco, Magnesio. Sabor: Natural Superfood Pink Lemonade. Peso Liq. 150g."
    },
    @{
        FolderName   = "Locao Corporal"
        SearchKey    = "o Corporal"
        CollectionId = "e24f8e2d-9711-4433-aea6-28d1ea9aeb14"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "BEIERMEI - High Moisturizing Nourishing Body Lotion. Embalagem retangular azul medio com bomba dispensadora branca. Ativos: 12% Glycerin, 1.2% Niacinamide, 1% Urea. Deeply Penetrates and Intensely Moisturizes, Nourishing and Whitening, Anti-Inflammatory and Soothing. Codigo: BE-MO002. 350g / 11.8FL.OZ."
    },
    @{
        FolderName   = "Bendita Canfora"
        SearchKey    = "Bendita"
        CollectionId = "056f438e-e4bb-4bf6-9d44-57a78321f00d"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Bravir - Bendita Canfora. Tablete Multiuso. Pote de vidro verde-escuro com tampa plastica verde-escuro com rosca. Texto branco: REFRESCA, ENERGIZA, ODORIZA. Canfora Refinada."
    },
    @{
        FolderName   = "GHK-Cu"
        SearchKey    = "GHK"
        CollectionId = "996c26ff-1222-4f77-b9e1-3a54e5bcd06f"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Zencial - EnvySkin GHK-Cu. Frasco conta-gotas com vidro transparente contendo liquido azul profundo, gargalo rose gold e conta-gotas branco. Peptideos de Cobre, Colageno, Acido Hialuronico. Copper Peptide + Collagen + Hyaluronic Acid. Conteudo 30ml."
    },
    @{
        FolderName   = "EnvyHair"
        SearchKey    = "EnvyHair"
        CollectionId = "085757c4-b83e-4166-b589-d9804fd48e41"
        PromptFile   = "my prompts\POV\Universal_prompt_pv.txt"
        ProductDesc  = "Zencial - Envy Hair. Serum Capilar Blend de Oleos. Frasco conta-gotas em vidro ambar marrom com gargalo prata e conta-gotas branco. Oleos: Ricino, Argan, Rosmarinus. Contribui para o crescimento saudavel dos fios. Conteudo 30ml."
    }
)

# ---------------------------------------------------------------------------
# Montar prompt final para cada produto
# ---------------------------------------------------------------------------
function Build-Prompt {
    param(
        [hashtable]$Product,
        [string]$GflowRoot
    )

    $promptPath = Join-Path $GflowRoot $Product.PromptFile
    if (-not (Test-Path $promptPath)) {
        throw "Arquivo de prompt nao encontrado: $promptPath"
    }

    $rawPrompt = Get-Content -Path $promptPath -Raw -Encoding UTF8

    if ($null -eq $Product.ProductDesc) {
        # Be An Attractive Man - prompt completo, sem substituicoes
        return $rawPrompt.Trim()
    }

    # Universal prompt: substituir placeholders
    # Substitui referencia ao FEROFIRE pelo produto correto
    $prompt = $rawPrompt -replace "Only the FEROFIRE perfume bottle may appear\.", "Only the $($Product.FolderName) product may appear."

    # Substituir placeholder de fala por vazio (sem dialogo)
    $prompt = $prompt -replace "\(Optional\)\[Portuguese speech\]", ""

    # Substituir placeholder de descricao do produto
    $prompt = $prompt -replace "\(Optional\)\[Product description or text in the product to get a high fidelity\]", $Product.ProductDesc

    return $prompt.Trim()
}

# ---------------------------------------------------------------------------
# Resolver nome real da pasta no disco (trata acentos)
# ---------------------------------------------------------------------------
function Resolve-ProductFolder {
    param([string]$ProductsRoot, [string]$FolderName, [string]$SearchKey)

    # Tentar nome exato primeiro
    $exact = Join-Path $ProductsRoot $FolderName
    if (Test-Path $exact) { return $exact }

    # Busca por SearchKey (sem acentos) — cobre pastas com caracteres especiais
    if ($SearchKey) {
        $byKey = Get-ChildItem -Path $ProductsRoot -Directory |
            Where-Object { $_.Name -like "*$SearchKey*" } |
            Select-Object -First 1
        if ($byKey) { return $byKey.FullName }
    }

    # Fallback: correspondencia parcial pelo inicio do nome
    $prefix = $FolderName.Substring(0, [Math]::Min(6, $FolderName.Length))
    $candidates = Get-ChildItem -Path $ProductsRoot -Directory |
        Where-Object { $_.Name -like "*$prefix*" }

    if ($candidates.Count -eq 1) { return $candidates[0].FullName }
    if ($candidates.Count -gt 1) {
        $match = $candidates | Where-Object { $_.Name -eq $FolderName } | Select-Object -First 1
        if ($match) { return $match.FullName }
    }

    return $null
}

# ---------------------------------------------------------------------------
# Estatisticas globais
# ---------------------------------------------------------------------------
$Stats = @{
    Total     = 0
    Generated = 0
    Skipped   = 0
    Errors    = 0
}

Write-Log "INFO" "=========================================="
Write-Log "INFO" "INICIO DA GERACAO MASSIVA DE VIDEOS"
Write-Log "INFO" "Projeto: $ProjectId"
Write-Log "INFO" "Produtos: $($Products.Count)"
Write-Log "INFO" "DryRun: $DryRun"
Write-Log "INFO" "=========================================="

# ---------------------------------------------------------------------------
# Loop principal
# ---------------------------------------------------------------------------
foreach ($product in $Products) {

    # Resolver pasta real no disco
    $folderPath = Resolve-ProductFolder -ProductsRoot $ProductsRoot -FolderName $product.FolderName -SearchKey $product.SearchKey
    if (-not $folderPath) {
        # Tentar com o nome real das pastas que tem acentos
        $allFolders = Get-ChildItem -Path $ProductsRoot -Directory
        Write-Log "WARN" "Pasta '$($product.FolderName)' nao encontrada. Pastas disponiveis:"
        $allFolders | ForEach-Object { Write-Log "WARN" "  -> $($_.Name)" }
        continue
    }

    $imgsPath   = Join-Path $folderPath "imgs"
    $videosPath = Join-Path $folderPath "videos"

    if (-not (Test-Path $imgsPath)) {
        Write-Log "WARN" "Pasta imgs nao encontrada, pulando: $imgsPath"
        continue
    }

    # Criar pasta de videos se nao existir
    if (-not (Test-Path $videosPath)) {
        New-Item -ItemType Directory -Force -Path $videosPath | Out-Null
        Write-Log "INFO" "[$($product.FolderName)] Pasta videos criada: $videosPath"
    }

    # Montar prompt
    try {
        $finalPrompt = Build-Prompt -Product $product -GflowRoot $GflowRoot
    }
    catch {
        Write-Log "ERROR" "[$($product.FolderName)] Erro ao montar prompt: $_"
        continue
    }

    # Listar imagens
    $images = Get-ChildItem -Path $imgsPath -Filter "*.jpeg" -File | Sort-Object Name
    $imgCount = $images.Count

    Write-Log "INFO" "[$($product.FolderName)] Iniciando: $imgCount imagens | Collection: $($product.CollectionId)"

    $productGenerated = 0
    $productSkipped   = 0
    $productErrors    = 0
    $imgIndex         = 0

    foreach ($img in $images) {
        $imgIndex++
        $Stats.Total++

        # Nome base do video esperado (mesmo nome da imagem, extensao .mp4)
        $expectedVideoName = [System.IO.Path]::GetFileNameWithoutExtension($img.Name) + ".mp4"
        $expectedVideoPath = Join-Path $videosPath $expectedVideoName

        # Skip se ja existe
        if (Test-Path $expectedVideoPath) {
            Write-Log "SKIP" "[$($product.FolderName)] ($imgIndex/$imgCount) Ja existe: $expectedVideoName"
            $productSkipped++
            $Stats.Skipped++
            continue
        }

        Write-Log "INFO" "[$($product.FolderName)] ($imgIndex/$imgCount) Gerando: $($img.Name)"

        if ($DryRun) {
            Write-Log "INFO" "[DRYRUN] gflow video i2v --initial-frame `"$($img.FullName)`" --model veo-lite-lp --duration 8 --aspect 9:16 --project $ProjectId --collection $($product.CollectionId) --out-dir `"$videosPath`""
            $productGenerated++
            $Stats.Generated++
            continue
        }

        # Executar gflow video i2v via wrapper Python (evita problemas de quoting
        # no PowerShell com prompts que tem linhas iniciando com "-")
        try {
            $startTime = Get-Date

            # Salvar prompt em arquivo temporario
            $promptTempFile = [System.IO.Path]::GetTempFileName() + ".txt"
            [System.IO.File]::WriteAllText($promptTempFile, $finalPrompt, [System.Text.Encoding]::UTF8)

            # Chamar wrapper Python — subprocess do Python faz o quoting correto
            $result = uv run python scripts\i2v_runner.py `
                --prompt-file $promptTempFile `
                --initial-frame $img.FullName `
                --output-name $expectedVideoName `
                --model veo-lite-lp `
                --duration 8 `
                --aspect 9:16 `
                --project $ProjectId `
                --collection $product.CollectionId `
                --out-dir $videosPath 2>&1

            $exitCode = $LASTEXITCODE
            Remove-Item $promptTempFile -ErrorAction SilentlyContinue

            $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)

            if ($exitCode -eq 0) {
                Write-Log "SUCCESS" "[$($product.FolderName)] ($imgIndex/$imgCount) OK em ${elapsed}s: $($img.Name)"
                $productGenerated++
                $Stats.Generated++
            }
            else {
                Write-Log "ERROR" "[$($product.FolderName)] ($imgIndex/$imgCount) FALHOU (exit=$exitCode) em ${elapsed}s: $($img.Name)"
                Write-Log "ERROR" "  Saida: $(($result | Select-Object -Last 5) -join ' | ')"
                $productErrors++
                $Stats.Errors++
            }
        }
        catch {
            Write-Log "ERROR" "[$($product.FolderName)] ($imgIndex/$imgCount) EXCECAO: $_"
            $productErrors++
            $Stats.Errors++
        }


        # Pausa entre geracoes para evitar throttling
        if ($imgIndex -lt $imgCount) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    Write-Log "INFO" "[$($product.FolderName)] CONCLUIDO: $productGenerated gerados | $productSkipped pulados | $productErrors erros"
    Write-Log "INFO" "------------------------------------------"
}

# ---------------------------------------------------------------------------
# Resumo final
# ---------------------------------------------------------------------------
Write-Log "INFO" "=========================================="
Write-Log "INFO" "GERACAO CONCLUIDA"
Write-Log "INFO" "  Total processado    : $($Stats.Total)"
Write-Log "INFO" "  Gerados com sucesso : $($Stats.Generated)"
Write-Log "INFO" "  Pulados (ja tinham) : $($Stats.Skipped)"
Write-Log "INFO" "  Erros               : $($Stats.Errors)"
Write-Log "INFO" "=========================================="
