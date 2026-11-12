# Arcane Arena

Arena brawler 3D de magos para PC: magias de empurrão, plataforma que encolhe sobre lava, último de pé vence.
Jogo **original** inspirado no gênero dos mods de arena de magos — nunca copiar nomes, personagens, arte, sons ou mapas de jogos existentes.

Stack: **Godot 4.6** (GDScript, renderizador Forward+). O produto é um cliente de PC nativo (Windows primeiro).
Jogo comercial autopublicado (site próprio, talvez Steam): só usar assets e addons com licença para uso comercial, registrados em `docs/CREDITS.md`.

## Comandos

- `bash tools/setup_godot.sh` — instala o Godot em `~/.local/bin/godot` (rodar no início de cada sessão na nuvem)
- `bash tools/check.sh` — importa o projeto e roda os testes (tem que passar antes de todo commit)
- `bash tools/smoke.sh <pasta>` — roda o jogo de verdade e salva capturas `top.png` e `third.png`
- `bash tools/export_windows.sh` — exporta `build/ArcaneArena.exe` (o CI faz isso a cada push; tag `v*` publica release)
- No PC do usuário: abrir `project.godot` no editor Godot 4.6 e apertar F5

## Arquitetura (módulos profundos, interfaces pequenas)

- `sim/` — simulação pura e determinística (`RefCounted`). Sem nós, sem cena, sem `Input`, sem `randf()` global, sem relógio real.
  Interface: `SimWorld.new(config)` e `step(commands)`. Toda regra de jogo mora aqui e é coberta por testes.
  O chão é 2D: `Vector2(x, y)` da simulação é `(x, z)` no mundo 3D.
- `render/` — só desenha o estado da simulação. `camera_rig.gd` é matemática pura (testável); `arena_view.gd` monta a cena.
- `game/main.gd` — cola: entrada → comandos → `step` em passo fixo (30 Hz) → render interpolado.
- Entrada nunca altera o mundo direto: sempre vira um comando (`queue_command`). Isso mantém o caminho aberto para bots, replays e multiplayer.
- `tests/` — `test_*.gd` estendem `tests/test_case.gd`; métodos `test_*` são descobertos por `tests/run_tests.gd`.
- Scripts se referenciam por `preload("res://...")`, não por `class_name` (funciona em modo headless sem cache do editor).
- A cena é montada por código (sem `.tscn` além de `main.tscn`). Direção de arte: fantasia semi-realista (proporções naturais, paleta terrosa, luz quente de fim de tarde; **nada de aspecto cartoon**) — estilo próprio, sem copiar o visual de nenhum jogo. Shaders em `render/*.gdshader`, efeitos em `render/fx.gd`, mago em `render/mage_view.gd` (figura montada e animada por código).

## Método de trabalho (Matt Pocock)

Fluxo: PRD (`docs/PRD.md`) → issues em fatias verticais (`docs/issues/`) → uma issue por vez com TDD → handoff.

1. **Início da sessão**: ler só `docs/HANDOFF.md` e a issue indicada nele. Não ler o PRD inteiro nem outras issues sem necessidade.
2. **Uma issue por vez**, na ordem de `docs/issues/README.md`, respeitando dependências. Issues `HITL` exigem decisão do usuário antes de codar; `AFK` podem ser feitas direto.
3. **TDD** para tudo em `sim/` e matemática pura: teste vermelho → código mínimo → verde → refatorar. Testar comportamento pela interface pública, não detalhes internos.
4. **Verificar de verdade**: além de `tools/check.sh`, rodar `tools/smoke.sh` e olhar as capturas quando a fatia tem parte visual (estender `tests/smoke.gd` para exercitar a novidade).
5. **Fechar a issue**: marcar `Status: concluída` no arquivo e no README das issues, commit e push.
6. **Orçamento de contexto**: a sessão não deve passar muito de ~300k tokens. Depois de ~220k, **não começar** uma nova issue. Uma issue já iniciada **nunca** é interrompida: termina-se, mesmo que passe do limite.
7. **Fim da sessão**: reescrever `docs/HANDOFF.md` (estado atual, próxima issue, pegadinhas descobertas), commit, push, e **mandar ao usuário, no chat, o prompt da próxima sessão** (o bloco de `docs/HANDOFF.md`).
8. Se uma issue se mostrar grande demais, dividir em novas issues em vez de esticar a sessão.

Idioma: docs, comentários e mensagens de commit em português; identificadores de código em inglês.
