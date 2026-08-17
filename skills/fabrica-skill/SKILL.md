---
name: tiktok-fabrica-ia
description: Cria vídeos para TikTok Shop no estilo "gancho com fábrica com IA". Use esta skill sempre que o usuário pedir para gerar um vídeo de "fábrica", "vídeo fábrica", "gancho fábrica com produto", ou vídeos em três partes (gancho + 2 ugc) para o TikTok.
---

# TikTok Shop - Fábrica com IA

Esta skill orquestra a criação de um vídeo de 24 segundos (3 partes de 8s) para o TikTok Shop, utilizando imagens de referência e mesclando ganchos de fábrica com conteúdo gerado pelo usuário (UGC).

O processo envolve a geração de imagens, a geração de vídeos a partir dessas imagens e a concatenação final.

## 1. Compreensão do Fluxo e Requisitos

Antes de iniciar qualquer ação técnica, certifique-se de que os seguintes recursos estejam disponíveis ou que você os providencie usando a skill de geração de imagens/vídeos MCP se necessário:

- **Imagens de Referência:**
  - `img_referencia_fabrica.jpeg` (cenário da fábrica)
  - `img_referencia_ugc.jpeg` (cenário UGC/criador)
  - `imagem_do_produto` (imagem do produto alvo)
- **Informações do Produto:** Pesquise informações básicas sobre o produto para criar as copys das partes 2 e 3.
- **Projeto Base do Flow:** Para não lotar a conta do usuário com projetos temporários, realize todas as chamadas de API (`gflow image i2i` e `gflow video i2v`) passando sempre a flag `--project 52e1b8ae-fb5f-4ebb-8105-f67830f41627`.

## 2. Estrutura do Vídeo Final (24 Segundos)

O vídeo é composto por 3 clipes de 8 segundos, concatenados no final.

### Vídeo 1: Gancho com a Fábrica (0s - 8s)

**Passo 1: Gerar Imagem Inicial (Nano Banana 2)**
- **Formato:** Vertical 9:16
- **Input:** `img_referencia_fabrica.jpeg` + `imagem_do_produto`
- **Prompt:** Utilize o prompt em `skills/fabrica-skill/prompts/prompt_img_fabrica.txt` ("Transforme essa fábrica, em uma fábrica do produto da segunda imagem, com a mesma ideia da primeira imagem, mude as pessoas da imagem também para mulheres muito lindas, e um pouco do cenário também")

**Passo 2: Gerar Vídeo (Veo3.1 lp)**
- **Input:** Imagem gerada no Passo 1.
- **Prompt Base:** Utilize o prompt base localizado em `skills/fabrica-skill/prompts/prompt_vid_gancho_com_a_fabrica.txt`
- **Adaptação:** Substitua `[PRODUTO]` no prompt pelo nome do produto alvo. NÃO altere o resto do prompt.

```json
{
  "generation_model": "VEO 3.1",
  "task": "Image-to-Video (I2V)",
  "aspect_ratio": "9:16",
  "resolution": "4K UHD",
  "frame_rate": 30,
  "scene_description": {
    "setting": { "location": "Galpão industrial" },
    "dialogue_and_audio": {
      "spoken_dialogue": {
        "text": "Quem comprou esse [PRODUTO] ontem tá chorando! O TikTok surtou e o estoque tá sumindooooo!",
        "language": "pt-BR"
      }
    }
  },
  "prompt_text": "Create a realistic vertical 9:16 image-to-video animation based strictly on the reference image... ALL PEOPLE VISIBLE IN THE REFERENCE IMAGE must speak TOGETHER and SIMULTANEOUSLY in Brazilian Portuguese. They must say this EXACT dialogue VERBATIM: \"Quem comprou esse [PRODUTO] ontem tá chorando! O TikTok surtou e o estoque tá sumindooooo!\"..."
}
```

*Nota: Use o conteúdo completo do arquivo `prompt_vid_gancho_com_a_fabrica.txt` para fazer a geração, não apenas este trecho ilustrativo.*

### Vídeo 2: Produto UGC (8s - 16s)

**Passo 1: Gerar Imagem Inicial (Nano Banana 2)**
- **Formato:** Vertical 9:16
- **Input:** `img_referencia_ugc.jpeg` + `imagem_do_produto`
- **Prompt:** Utilize o prompt em `skills/fabrica-skill/prompts/prompt_img_ugc_com_produto.txt` ("mude levemente o cenário, os produtos de acordo com o produto da imagem, e com o uniforme da marca")

**Passo 2: Gerar Vídeo (Veo3.1 lp)**
- **Input:** Imagem gerada no Passo 1.
- **Copy (Fala):** Crie a primeira parte de uma copy sobre o produto (até 180 caracteres).
- **Prompt Base:** Utilize o prompt base localizado em `skills/fabrica-skill/prompts/prompt_vid_ugc_produto.txt` e substitua APENAS o bloco de fala sob "INFLUENCER SPEECH (example — Portuguese only):" pela sua copy gerada. Não altere o restante das diretrizes ("VISUAL REALISM", "CAMERA & MOTION", etc).

### Vídeo 3: CTA UGC (16s - 24s)

**Passo 1: Reutilizar Imagem Inicial**
- Use exatamente a MESMA imagem inicial gerada para o Vídeo 2.

**Passo 2: Gerar Vídeo (Veo3.1 lp)**
- **Input:** Imagem inicial do Vídeo 2.
- **Copy (Fala):** Crie a parte final/CTA da copy sobre o produto (até 180 caracteres).
- **Prompt Base:** Utilize o mesmo prompt base do Vídeo 2 (`skills/fabrica-skill/prompts/prompt_vid_ugc_produto.txt`), substituindo APENAS a fala sob "INFLUENCER SPEECH (example — Portuguese only):" pela copy CTA criada. Mantenha o restante das diretrizes inalterado.

## 3. Concatenação e Finalização

Após obter os três vídeos de 8 segundos (gerados via seu sistema/MCP correspondente), utilize o comando `ffmpeg` no bash para juntá-loc em um único arquivo de 24 segundos.

**Exemplo de comando:**
```bash
# Crie um arquivo list.txt com o nome dos 3 vídeos
echo "file 'video1.mp4'" > list.txt
echo "file 'video2.mp4'" >> list.txt
echo "file 'video3.mp4'" >> list.txt

# Concatene
ffmpeg -f concat -safe 0 -i list.txt -c copy video_final_fabrica.mp4
```

## Passo a passo de Execução:
1. **Entrevista/Confirmação:** Peça ao usuário qual é o Produto e se as imagens base já estão no diretório de trabalho. Sugira criar uma pasta isolada para os arquivos deste projeto (ex: `tiktok-[nome-produto]`).
2. **Copywriting:** Gere e mostre ao usuário as copys para o Vídeo 2 e Vídeo 3 (máximo 180 caracteres cada).
3. **Escrita dos Prompts:** Escreva o texto de prompt alterado em arquivos separados (`prompt_vid2.txt` e `prompt_vid3.txt`) dentro da pasta isolada ao invés de enviar textos gigantes diretamente por linha de comando.
4. **Orquestração:** Chame a CLI passando os argumentos, os arquivos adequados e a flag obrigatória `--project 52e1b8ae-fb5f-4ebb-8105-f67830f41627`. Sugira sempre utilizar `-n 2` ou `-n 3` na geração das imagens iniciais para que o usuário possa escolher o melhor antes de avançar para a geração em vídeo.
5. **Finalização:** Concatene os vídeos finais e entregue o resultado final.