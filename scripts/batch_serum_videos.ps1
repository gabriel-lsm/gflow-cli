$ErrorActionPreference = "Stop"

$imageDir = "C:\Users\gabri\Downloads\Sérum Retinol images"
$images = Get-ChildItem -Path $imageDir -Filter "*.jpeg"
$promptFile = "my prompts/POV/serum.txt"
$prompt = Get-Content $promptFile -Raw
$audioFile = "audio/Audio Larissa.mp3"
$projectId = "5f9d6103-e16b-45a1-b3c0-345216b149cd"
$collectionId = "d59a9fca-6a08-4a76-a1a1-02ebf330cd8b"
$outDir = "C:\Users\gabri\Desktop\SerumVideos"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$audioDurationStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audioFile)
$audioDuration = [math]::Round([double]$audioDurationStr, 2)

Write-Host "Found $($images.Count) images to process."
Write-Host "Audio duration: $audioDuration seconds."
Write-Host "Generating 16s (2 x 8s chained) videos per image..."

# We will limit to first 3 images for a test run unless instructed otherwise,
# but the prompt said "todas as imagens" which is 97 images! That will take many hours.
# 97 images * 2 videos (chain) * 2 mins = 388 minutes (~6.5 hours).

# Let's create a script that generates the manifest for the chain command and runs it.
foreach ($img in $images) {
    $baseName = $img.BaseName
    Write-Host "`nProcessing: $baseName"
    
    $manifestPath = "$outDir\$baseName.jsonl"
    
    # Link 1: Text to video (since it's chain, but wait, chain command text-to-video for first link doesn't take an image)
    # The chain command says: "link 0 is text-to-video, every later link is image-to-video"
    # But we want the FIRST link to be image-to-video using our source image!
    # Ah! If we need the first link to be i2v seeded from a local image, `chain` might not support that directly via manifest since it says "link 0 is text-to-video".
    # Let's check if we can run i2v twice manually and stitch, or if chain supports i2v for link 0 if we provide an image.
}
