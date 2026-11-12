# 009 — Passe visual

Status: concluída · HITL · depende de 006

Decidir com o usuário a direção de arte e a origem dos modelos (CC0 ou próprios). Modelos GLTF animados (parado, andar, lançar, atingido, morrer), partículas, shader de lava, rachaduras na borda, bloom e correção de cor. Registrar tudo em `docs/CREDITS.md`.

## Decisões do usuário
- Direção de arte: primeiro **sombrio vulcânico**; o usuário não gostou e pediu algo na linha de fantasia clara e colorida (citou Magicka como referência de clima). A 2ª versão (clara, com boneco cabeçudo do KayKit) também foi rejeitada por parecer **cartoon**. 3ª versão, a atual: **fantasia semi-realista** — proporções naturais, paleta terrosa, sol baixo de fim de tarde. Visual próprio: o estilo do jogo citado não é reproduzido.
- Modelos: o Mago do KayKit (CC0) foi usado e depois **removido** (era o que mais dava ar de cartoon). O mago atual é montado e animado por código.
- Prioridade: arena e efeitos primeiro (coube tudo numa sessão).

## Feito
- `render/lava.gdshader` (crosta de pedra com veios incandescentes que escorrem) e `render/rock.gdshader` (lajes gastas com grão, bordas escurecidas e musgo nas juntas; juntas incandescentes na faixa da borda, que acompanha o raio da arena; laterais acesas por baixo). Ruído calculado no próprio shader, sem texturas.
- `render/fx.gd`: rastros dos projéteis e do Cometa, faíscas nos acertos/explosões/teleportes, ondas de choque, chamas no mago que está na lava, brasas subindo no fundo.
- `render/mage_view.gd` + `render/mage_anim.gd` (lógica pura, testada): figura de manto, chapéu, barba e cajado feita de primitivas, com poses por código (parado, correr, lançar, atingido, cair); manto num tom terroso da cor do jogador.
- Simulação: todo lançamento gera um evento `cast` (serve à animação e servirá ao áudio).
- Ambiente: céu de fim de tarde, sol baixo dourado com sombras longas, clarão da lava por baixo, névoa leve, SSAO (só Forward+) e bloom discreto.

## Fica para o retorno do usuário
- Nada disso foi visto em Forward+ (só no renderizador de software da nuvem): o limite real é a falta de arte feita à mão: para subir de nível é preciso modelos e texturas de artista (comprados ou encomendados) em 3ª pessoa são os ajustes mais prováveis.
