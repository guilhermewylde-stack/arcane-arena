# 017 — Teclas configuráveis

Status: concluída · AFK · depende de 012

Tela "Teclas" no menu: trocar as teclas da barra de magias (visão de cima), do movimento e da seleção de magia (3ª pessoa), salvas em `user://settings.cfg`.
Hoje as teclas são constantes em `game/main.gd` (`SLOT_KEYS`, WASD em `_move_input`, 1–6) e os rótulos em `ArenaView.SLOT_LABELS`.
Fazer um módulo puro de mapa de teclas (padrões, validar, detectar conflito, salvar/ler) com TDD, e a barra de magias mostrando a tecla configurada.

## Aceite
- [x] Trocar as teclas de magia e de movimento pelo menu; conflito no mesmo grupo troca as duas teclas de lugar
- [x] "Restaurar padrões"
- [x] As teclas valem na próxima vez que o jogo abre e aparecem certas na barra e na ajuda

## Como ficou
- `game/keymap.gd` (puro, testado): ações `slot_1..6` (magias na visão de cima) e `move_*` (andar em 3ª pessoa), salvas na seção `keys` de `user://settings.cfg`.
- Menu → Opções → Teclas: clicar na ação e apertar a tecla; Esc desiste; "Restaurar padrões".
- Os números 1–6 (escolher magia em 3ª pessoa, comprar na loja), Esc, Enter, F5 e F11 são fixos e não podem ser usados.
- Botões do mouse não são configuráveis (clique direito move, clique esquerdo lança).
