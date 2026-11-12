# Handoff — prompt da próxima sessão

Copie o bloco abaixo como primeira mensagem da próxima sessão (com o repositório `arcane-arena` selecionado).

```
Projeto Arcane Arena (Godot 4.6). Leia CLAUDE.md e docs/HANDOFF.md e siga o método de trabalho de lá.
Comece rodando bash tools/setup_godot.sh.
Próxima issue: docs/issues/005-rodadas.md. Faça com TDD, confira com tools/smoke.sh,
feche a issue, faça commit e push. Se sobrar orçamento de contexto (< ~220k), siga para a 006.
No fim, atualize docs/HANDOFF.md e me mande o prompt da sessão seguinte.
```

## Estado atual
- Motor: Godot 4.6, GDScript.
- Issues 001–004 concluídas: arena, mover, zoom; vida, lava e morte; magia Brasa (Q) com dano e empurrão; bots.
- 43 testes passando (`bash tools/check.sh`).
- O jogo abre com o jogador (id 0) e 3 bots de dificuldade `normal` (`WORLD_CONFIG`, `BOT_DIFFICULTY` e `BOT_SEED` em `game/main.gd`).
  Ainda não há rodadas: quem morre fica morto até apertar F5.

## Mapa rápido da simulação (`sim/`)
- `spells.gd`: tabela de magias (só dados). Magia nova = entrada nova na tabela; hoje toda magia é projétil reto.
- `sim_world.gd`: comandos `move_command` e `cast_command`; `mages`, `projectiles` e `events` (o que aconteceu no último `step`: `hit`, `fizzle`).
- Mago: `hp`, `alive`, `vel` (empurrão, com atrito), `cooldowns` (tick em que a magia fica pronta).
- O empurrão cresce com a vida que falta (`KNOCKBACK_DAMAGE_SCALING`). A lava tira `LAVA_DPS` por segundo fora de `arena_radius`.
- `snapshot_positions()` devolve `{ mages: {...}, projectiles: {...} }`.
- `bot.gd`: `Bot.new(mage_id, seed, dificuldade)` e `think(world) -> comandos`, uma vez por tick. Não altera o mundo; o único estado é o RNG com semente.
  Prioridades de movimento: desviar de projétil → voltar para a arena → circular o inimigo mais próximo. Lança Brasa quando o inimigo está ao alcance.
  `main.gd` junta os comandos dos bots em `_pending` antes de cada `step`; `bots_enabled = false` deixa os outros magos parados (usado pelo teste de fumaça).

## Balanceamento a observar (não é bug)
- No começo da partida os bots 1 e 3 escolhem o jogador como alvo (empate de distância cai no id menor). Um jogador parado é jogado na lava em ~2 s e morre em ~5 s.
  Os empurrões de vários acertos se somam. Vale rever na 005 (posições iniciais, alvo dos bots) ou quando o usuário jogar e der retorno.

## Pegadinhas
- Com a câmera em yaw 0 (olhando para +z), a direita da tela é **-x** do mundo. É esperado.
- Na nuvem não há Vulkan: o teste de fumaça usa `--rendering-method gl_compatibility` (renderização por software). As cores e o brilho diferem um pouco do Forward+ que o jogador vê; não ajustar arte fina com base nessas capturas.
- O teste de fumaça roda a ~4 quadros por segundo na nuvem: os 1040 quadros levam uns 4 minutos. Rodar com timeout longo (10 min) e evitar repetir à toa. Ele é guiado por número de quadro (`--fixed-fps 60`); ao mudar velocidades ou posições iniciais, recalcular os quadros em `tests/smoke.gd`.
- `tools/smoke.sh` agora falha (exit 1) se o log tiver `SCRIPT ERROR` ou `FALHA`; o log completo fica em `<pasta>/smoke.log`.
- Erros de ALSA/áudio na saída do teste de fumaça são do contêiner, não do jogo.
- Usar `preload` por caminho em vez de `class_name` (ver CLAUDE.md).
- Um arquivo de teste que não compila agora conta como falha em `tests/run_tests.gd` (antes passava calado).
- Testes de magia usam `arena_radius` enorme para a lava não interferir; os de lava usam raio 5.
- O render recebe as posições do tick anterior para interpolar; entidades novas devem entrar em `snapshot_positions()` e ser interpoladas do mesmo jeito.
- Efeitos visuais de um tick chegam por `world.events` → `view.show_events()`, chamado em `main.gd` logo após cada `step` (os eventos são apagados no `step` seguinte).
- F5 reinicia o mundo (depuração). A vista reaproveita os nós dos magos entre reinícios.
- Build Windows ainda não existe (issue 011); para jogar, abrir `project.godot` no editor Godot 4.6 e apertar F5.
