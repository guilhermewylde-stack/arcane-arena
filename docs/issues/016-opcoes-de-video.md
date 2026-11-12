# 016 — Opções de vídeo no menu

Status: concluída · AFK · depende de 011, 012

Tela "Opções" no menu principal e na pausa: tela cheia, resolução (lista das comuns que cabem no monitor) e vsync.
Usa `game/settings.gd` (já salva e aplica; hoje só o F11 mexe nele). Mudança vale na hora e fica salva.

## Aceite
- [x] Botão "Opções" no menu principal e na pausa
- [x] Trocar tela cheia, resolução e vsync pelo menu, com efeito imediato
- [x] As escolhas valem na próxima vez que o jogo abre

## Como ficou
- Página "Opções" em `game/menu.gd` (modo `options`), aberta do menu principal ou da pausa; Esc volta.
- `Settings.resolutions(monitor)` e `Settings.adjust(...)` (puros, testados); o menu emite `settings_changed` e `main.gd` aplica e salva. F11 passa pelo mesmo caminho.
- A troca de resolução e de vsync não foi exercitada no teste de fumaça (deixaria um `settings.cfg` na máquina e as rodadas seguintes mais lentas): conferir no PC.
