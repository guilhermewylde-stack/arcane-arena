# Arcane Arena

Arena brawler 3D de magos para PC: magias de empurrão, plataforma que encolhe sobre lava, último de pé vence.
Jogo **original** inspirado no gênero dos mods de arena de magos — nunca copiar nomes, personagens, arte, sons ou mapas de jogos existentes.

Stack: TypeScript, Three.js, Vite, Vitest. O produto é um **cliente de PC** (Electron, issue 011); o navegador é só para desenvolvimento e testes.
Jogo comercial autopublicado (site próprio, talvez Steam): só usar assets e dependências com licença para uso comercial, registrados em `docs/CREDITS.md`.

## Comandos

- `npm run dev` — jogo no navegador com hot reload
- `npm run check` — typecheck + testes (tem que passar antes de todo commit)
- `npm run build` — build de produção

## Arquitetura (módulos profundos, interfaces pequenas)

- `src/sim/` — simulação pura e determinística. Sem Three.js, sem DOM, sem `Math.random`, sem relógio real.
  Interface: `createWorld(config)` e `step(world, commands)`. Toda regra de jogo mora aqui e é coberta por testes.
- `src/render/` — só desenha o estado da simulação. `cameraRig.ts` é matemática pura (testável); `scene.ts` é Three.js.
- `src/main.ts` — cola: entrada → comandos → `step` em passo fixo (30 Hz) → render interpolado.
- Entrada nunca altera o mundo direto: sempre vira um `Command`. Isso mantém o caminho aberto para bots, replays e multiplayer.

## Método de trabalho (Matt Pocock)

Fluxo: PRD (`docs/PRD.md`) → issues em fatias verticais (`docs/issues/`) → uma issue por vez com TDD → handoff.

1. **Início da sessão**: ler só `docs/HANDOFF.md` e a issue indicada nele. Não ler o PRD inteiro nem outras issues sem necessidade.
2. **Uma issue por vez**, na ordem de `docs/issues/README.md`, respeitando dependências. Issues `HITL` exigem decisão do usuário antes de codar; `AFK` podem ser feitas direto.
3. **TDD** para tudo em `src/sim/` e matemática pura: teste vermelho → código mínimo → verde → refatorar. Testar comportamento pela interface pública, não detalhes internos.
4. **Verificar de verdade**: além de `npm run check`, abrir o jogo no navegador (Playwright) e conferir a fatia funcionando quando ela tem parte visual.
5. **Fechar a issue**: marcar `Status: concluída` no arquivo e no README das issues, commit e push.
6. **Orçamento de contexto**: a sessão não deve passar muito de ~300k tokens. Depois de ~220k, **não começar** uma nova issue. Uma issue já iniciada **nunca** é interrompida: termina-se, mesmo que passe do limite.
7. **Fim da sessão**: reescrever `docs/HANDOFF.md` (estado atual, próxima issue, pegadinhas descobertas), commit, push, e **mandar ao usuário, no chat, o prompt da próxima sessão** (o bloco de `docs/HANDOFF.md`).
8. Se uma issue se mostrar grande demais, dividir em novas issues em vez de esticar a sessão.

Idioma: docs, comentários e mensagens de commit em português; identificadores de código em inglês.
