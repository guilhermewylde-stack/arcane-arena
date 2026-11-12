# 017 — Teclas configuráveis

Status: aberta · AFK · depende de 012

Tela "Teclas" no menu: trocar as teclas da barra de magias (visão de cima), do movimento e da seleção de magia (3ª pessoa), salvas em `user://settings.cfg`.
Hoje as teclas são constantes em `game/main.gd` (`SLOT_KEYS`, WASD em `_move_input`, 1–6) e os rótulos em `ArenaView.SLOT_LABELS`.
Fazer um módulo puro de mapa de teclas (padrões, validar, detectar conflito, salvar/ler) com TDD, e a barra de magias mostrando a tecla configurada.

## Aceite
- [ ] Trocar qualquer tecla de jogo pelo menu; conflito é avisado
- [ ] "Restaurar padrões"
- [ ] As teclas valem na próxima vez que o jogo abre e aparecem certas na barra e na ajuda
