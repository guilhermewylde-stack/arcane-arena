# 012 — Menu principal e configurar partida

Status: concluída · AFK · depende de 007

Menu principal e de pausa, configurar partida (bots, dificuldade, rodadas).
A issue original era grande demais e foi dividida: opções de vídeo → 016, teclas configuráveis → 017, opções de áudio → junto com a 010.

## Como ficou
- O jogo abre no menu principal (`game/menu.gd`), com o mundo parado ao fundo. Enter ou "Jogar" começa a partida.
- Esc pausa (e fecha a pausa); a pausa tem Continuar, Nova partida, Menu principal e Sair.
- Bots (1–7), dificuldade (Fácil/Normal/Difícil) e rodadas para vencer (1–9) ficam em `game/match_setup.gd` e são salvos em `user://settings.cfg` (seção `match`).
- F5 repete a partida com a mesma configuração.
