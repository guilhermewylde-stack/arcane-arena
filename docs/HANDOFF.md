# Handoff — prompt da próxima sessão

Copie o bloco abaixo como primeira mensagem da próxima sessão (com o repositório `arcane-arena` selecionado).

```
Projeto Arcane Arena (Godot 4.6). Leia CLAUDE.md e docs/HANDOFF.md e siga o método de trabalho de lá.
Comece rodando bash tools/setup_godot.sh.
Próxima issue: docs/issues/008-terceira-pessoa.md. Faça com TDD, confira com tools/smoke.sh,
feche a issue, faça commit e push. Se sobrar orçamento de contexto (< ~220k), siga para a 011
(a 009 e a 010 são HITL: precisam de decisão minha antes).
No fim, atualize docs/HANDOFF.md e me mande o prompt da sessão seguinte.
```

## Estado atual
- Motor: Godot 4.6, GDScript.
- Issues 001–007 concluídas: arena, mover, zoom; vida, lava e morte; 7 magias com barra Q W E R D F; bots; rodadas com arena que encolhe e placar; ouro e loja entre rodadas.
- 87 testes passando (`bash tools/check.sh`).
- O jogo abre numa partida de 1 jogador + 3 bots (`normal`), primeiro a 3 rodadas (`WORLD_CONFIG`, `BOT_DIFFICULTY`, `BOT_SEED` em `game/main.gd`). Todos começam só com Brasa.
- O usuário ainda não jogou nada disso à mão: todo balanceamento (dano, empurrão, preços, ouro, tempos) é chute inicial.

## Mapa rápido da simulação (`sim/`)
- `spells.gd`: tabela de magias (só dados) com `behavior`, preços (`cost`, `upgrade_cost`) e `per_level`. `Spells.stats(id, nível)` devolve os números já no nível (máx. `MAX_LEVEL` = 3).
  Comportamentos: `projectile` (opcionais `pull`, `turn_rate`), `teleport`, `nova`, `shield`, `delayed_area`. Magia nova de um comportamento existente = só uma entrada na tabela.
- `sim_world.gd`:
  - Comandos: `move_command`, `cast_command`, `buy_command`, `ready_command`.
  - Estado: `mages`, `projectiles`, `hazards` (áreas que vão explodir), `events` (do último `step`), `phase`, `scores`, `gold`, `shop_ready`.
  - Fases: `countdown` → `round` → `round_end` → `shop` → `countdown` ... → `match_end`. Sem `rounds_to_win` na config o mundo é livre (sempre `round`, sem encolher) — é o que os testes de magia e a 1ª parte do teste de fumaça usam. `shop_seconds: 0` pula a loja.
  - Mago: `hp`, `alive`, `vel` (empurrão, com atrito), `cooldowns`, `spells` ({id: nível}, a ordem é a da barra), `shield_until`, `last_hit_by`.
  - Ouro: por dano em outros magos, por abate (último a acertar), por vitória e por rodada jogada (constantes `GOLD_*`).
  - `snapshot_positions()` devolve `{ mages: {...}, projectiles: {...} }`.
- `bot.gd`: `Bot.new(mage_id, seed, dificuldade)` e `think(world) -> comandos`, uma vez por tick. Não altera o mundo; o único estado é o RNG com semente.
  Movimento: desviar de projétil → voltar para a arena → circular o inimigo mais próximo (empate de distância é sorteado). Magias: uma regra por comportamento em `_spell_target`. Na loja: compra o que o ouro alcança e avisa que está pronto.
- `main.gd` junta os comandos dos bots em `_pending` antes de cada `step`; `bots_enabled = false` deixa os outros magos parados; `restart(config)` aceita outra config.
- `arena_view.gd` emite os sinais `buy_requested`/`ready_requested` (cliques na loja); `main.gd` os transforma em comandos.

## Ideias anotadas (fora do escopo feito)
- A Fagulha Teleguiada orbita sem acertar um alvo colado (raio de curva = velocidade / `turn_rate` ≈ 4). Ajustar números se incomodar.
- O jogador morto vira espectador (câmera no centro), mas não pode trocar de alvo de câmera.
- Com a barra de 6 espaços e 7 magias, não há como vender ou trocar uma magia comprada.
- Um jogador parado ainda morre rápido: os bots miram quem estiver mais perto.

## Pegadinhas
- Com a câmera em yaw 0 (olhando para +z), a direita da tela é **-x** do mundo. É esperado.
- Na nuvem não há Vulkan: o teste de fumaça usa `--rendering-method gl_compatibility` (renderização por software). As cores e o brilho diferem um pouco do Forward+ que o jogador vê; não ajustar arte fina com base nessas capturas.
- O teste de fumaça roda a ~8 quadros por segundo na nuvem (janela de 1120x630): leva de 4 a 5 minutos. Rodar com timeout de 10 min e evitar repetir à toa. As capturas saem nesse tamanho, então o HUD parece pequeno nelas. Ele é guiado por número de quadro (`--fixed-fps 60`); ao mudar velocidades ou posições iniciais, recalcular os quadros em `tests/smoke.gd`.
- `tools/smoke.sh` agora falha (exit 1) se o log tiver `SCRIPT ERROR` ou `FALHA`; o log completo fica em `<pasta>/smoke.log`.
- Erros de ALSA/áudio na saída do teste de fumaça são do contêiner, não do jogo.
- Usar `preload` por caminho em vez de `class_name` (ver CLAUDE.md).
- Um arquivo de teste que não compila agora conta como falha em `tests/run_tests.gd` (antes passava calado).
- Testes de magia usam `arena_radius` enorme para a lava não interferir; os de lava usam raio 5.
- O render recebe as posições do tick anterior para interpolar; entidades novas devem entrar em `snapshot_positions()` e ser interpoladas do mesmo jeito.
- Efeitos visuais de um tick chegam por `world.events` → `view.show_events()`, chamado em `main.gd` logo após cada `step` (os eventos são apagados no `step` seguinte).
- F5 começa uma partida nova. A vista reaproveita os nós dos magos entre partidas.
- No teste de fumaça, trocar a config do jogo só a partir do 1º quadro de `_process`: em `_initialize` o `_ready` do jogo ainda não rodou e desfaz a troca.
- A 2ª parte do teste de fumaça é uma partida real de bots e termina por estado (fim da 2ª rodada), não por número de quadro; a duração varia se o balanceamento mudar.
- Build Windows ainda não existe (issue 011); para jogar, abrir `project.godot` no editor Godot 4.6 e apertar F5.
