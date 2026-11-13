# 018 — Personagem 3D no estilo da referência e sistema de skins

Status: aberta · HITL (espera o modelo 3D do usuário) · depende de 009

## Decisão do usuário
- Personagens em **3D**, no estilo de `docs/referencias/mago-estilo.jpg`: fantasia sombria ilustrada, proporções adultas, contorno a nanquim, tecido e couro gastos, capuz, ombreiras, cintos, bolsas, cajado retorcido. A imagem é guia de estilo, não o personagem final.
- No futuro: trocar skins, cajados, chapéus/capuzes e acessórios.
- O mago de primitivas (`render/mage_view.gd`) é provisório e sai nesta issue.

## O que o usuário precisa entregar (em `assets/models/mage/`)
Um modelo que código não produz. Origem possível: IA de imagem-para-3D, pacote pago ou artista — sempre com licença para uso comercial (anotar em `docs/CREDITS.md`).

1. **Corpo**: `mage_body.glb`, um humanoide com esqueleto, em pose A ou T, olhando para +Z, pés na origem, ~1,8 m de altura, até ~15 mil triângulos, 1 textura de cor (até 2048 px). Sem cajado e sem chapéu fundidos ao corpo.
2. **Animações** no mesmo esqueleto (dentro do GLB ou em GLBs separados): parado, correr, lançar magia, ser atingido, morrer. Nomes livres: o jogo mapeia.
3. **Peças separadas**, cada uma num GLB sem esqueleto, com a origem no ponto de encaixe: `staff_*.glb` (origem onde a mão segura, eixo ao longo de +Y), `hat_*.glb` ou `hood_*.glb` (origem no topo da cabeça), acessórios (`belt_*.glb`, `shoulder_*.glb`...).
4. **Skins**: mesma malha e esqueleto com outra textura (`mage_skin_*.png`). O manto deve ter uma cor-base bem separada (ex.: vermelho) para o jogo recolorir por jogador.

Dica para IA de imagem-para-3D: ela precisa de uma imagem do personagem **de frente, em pose A, corpo inteiro, fundo liso, sem cajado na mão e sem efeitos**; a folha de poses de ação não serve de entrada. Gerar cajado e chapéu como objetos à parte.

## O que o código fará quando o modelo chegar
- `render/mage_view.gd` passa a instanciar o GLB e a tocar as animações escolhidas por `render/mage_anim.gd` (já testado).
- `game/cosmetics.gd` (dados puros, com testes): catálogo de peças por espaço (`skin`, `staff`, `head`, `accessory`), escolha por mago, validação e gravação em `user://settings.cfg`.
- Encaixe das peças por `BoneAttachment3D` (mão direita, cabeça, peito, cintura); recolorir o manto por shader.
- Contorno a nanquim (casca invertida ou pós-processo) e cenário com vegetação no mesmo estilo: avaliar ao ver o modelo; se crescer, viram issues próprias.
