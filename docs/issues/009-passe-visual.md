# 009 — Passe visual

Status: concluída · HITL · depende de 006

Decidir com o usuário a direção de arte e a origem dos modelos (CC0 ou próprios). Modelos GLTF animados (parado, andar, lançar, atingido, morrer), partículas, shader de lava, rachaduras na borda, bloom e correção de cor. Registrar tudo em `docs/CREDITS.md`.

## Decisões do usuário
- Direção de arte: **sombrio vulcânico** (cena escura; a lava e as magias iluminam).
- Modelos: **CC0 baixado** — Mago do KayKit Adventurers (repositório público no GitHub; os sites de assets ficam bloqueados na rede da nuvem).
- Prioridade: arena e efeitos primeiro (coube tudo numa sessão).

## Feito
- `render/lava.gdshader` (crosta escura com veios que escorrem) e `render/rock.gdshader` (lajes de basalto; rachaduras incandescentes na faixa da borda, que acompanha o raio da arena; laterais acesas por baixo). Ruído calculado no próprio shader, sem texturas.
- `render/fx.gd`: rastros dos projéteis e do Cometa, faíscas nos acertos/explosões/teleportes, ondas de choque, chamas no mago que está na lava, brasas subindo no fundo.
- `render/mage_view.gd` + `render/mage_anim.gd` (lógica pura, testada): modelo animado com chapéu, capa, anel no chão e ponta do cajado na cor do jogador.
- Simulação: todo lançamento gera um evento `cast` (serve à animação e servirá ao áudio).
- Ambiente: luar frio de cima, clarão laranja de baixo, névoa avermelhada, bloom e correção de cor.

## Fica para o retorno do usuário
- Nada disso foi visto em Forward+ (só no renderizador de software da nuvem): brilho do bloom, escuridão do chão e tamanho do chapéu em 3ª pessoa são os ajustes mais prováveis.
