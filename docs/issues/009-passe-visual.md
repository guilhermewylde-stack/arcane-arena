# 009 — Passe visual

Status: concluída · HITL · depende de 006

Decidir com o usuário a direção de arte e a origem dos modelos (CC0 ou próprios). Modelos GLTF animados (parado, andar, lançar, atingido, morrer), partículas, shader de lava, rachaduras na borda, bloom e correção de cor. Registrar tudo em `docs/CREDITS.md`.

## Decisões do usuário
- Direção de arte: primeiro **sombrio vulcânico**; o usuário não gostou e pediu algo na linha de fantasia clara e colorida (citou Magicka como referência de clima). Refeito como **fantasia clara**, com visual próprio: nada do jogo citado é copiado.
- Modelos: **CC0 baixado** — Mago do KayKit Adventurers (repositório público no GitHub; os sites de assets ficam bloqueados na rede da nuvem).
- Prioridade: arena e efeitos primeiro (coube tudo numa sessão).

## Feito
- `render/lava.gdshader` (faixas chapadas de cor quente, estilo desenho) e `render/rock.gdshader` (lajes de pedra clara com musgo; juntas incandescentes na faixa da borda, que acompanha o raio da arena; laterais acesas por baixo). Ruído calculado no próprio shader, sem texturas.
- `render/fx.gd`: rastros dos projéteis e do Cometa, faíscas nos acertos/explosões/teleportes, ondas de choque, chamas no mago que está na lava, brasas subindo no fundo.
- `render/mage_view.gd` + `render/mage_anim.gd` (lógica pura, testada): modelo animado de manto inteiro na cor do jogador (chapéu e capa num tom mais escuro), anel no chão e cajado aceso.
- Simulação: todo lançamento gera um evento `cast` (serve à animação e servirá ao áudio).
- Ambiente: céu azul, sol quente com sombras, leve clarão da lava por baixo, bloom discreto e saturação.

## Fica para o retorno do usuário
- Nada disso foi visto em Forward+ (só no renderizador de software da nuvem): exposição (claro demais ou não), quantidade de musgo e tamanho do chapéu em 3ª pessoa são os ajustes mais prováveis.
