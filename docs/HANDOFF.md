# Handoff — prompt da próxima sessão

Copie o bloco abaixo como primeira mensagem da próxima sessão (com o repositório `arcane-arena` selecionado).

```
Projeto Arcane Arena (Godot 4.6). Leia CLAUDE.md e docs/HANDOFF.md e siga o método de trabalho de lá.
Comece rodando bash tools/setup_godot.sh.
Todas as issues AFK estão concluídas; as abertas (010 áudio, 013 multiplayer, 014 site, 015 Steam) são HITL.
Antes de codar, me faça as perguntas da issue que eu escolher abaixo e espere minhas respostas:
Issue escolhida: <010 ou 013, ou "ajustes" para só corrigir o que achei jogando>
Meu retorno depois de jogar o .exe: <o que achei do visual novo (magos, chão, lava, magias), controles, câmera, balanceamento, bugs>
No fim, atualize docs/HANDOFF.md e me mande o prompt da sessão seguinte.
```

## Estado atual
- Motor: Godot 4.6, GDScript.
- Concluídas: 001–009, 011, 012, 016, 017. Abertas (todas HITL): 010, 013, 014, 015.
- Visual (009): direção **fantasia semi-realista, sem aspecto cartoon** (3ª tentativa: o usuário rejeitou a sombria e a clara/cartoon; a referência dele é Magicka — não reproduzir o estilo desse jogo, fazer visual próprio); mago de proporções naturais montado por código, lava com crosta e veios, pedra gasta, sol de fim de tarde. Só foi visto no renderizador de software da nuvem.
- 126 testes passando (`bash tools/check.sh`); o CI do GitHub roda os testes e exporta o `.exe` a cada push.
- O jogo abre no menu principal; a partida padrão é 1 jogador + 3 bots `normal`, primeiro a 3 rodadas. Todos começam só com Brasa.
- **O usuário ainda não jogou nada à mão.** Tudo que é sensação (sensibilidade do mouse, câmera de ombro, distância da mira, dano, empurrão, preços, tempos) é chute inicial. O primeiro passo útil é ele baixar o `.exe` e contar o que achou.

## Pendências do usuário
- Baixar o `ArcaneArena.exe`: GitHub → aba Actions → última execução do "CI" → artefato `ArcaneArena-windows` (precisa estar logado). Confirmar que abre e roda (último item do aceite da 011). O Windows deve mostrar o aviso do SmartScreen, porque o `.exe` não é assinado (assinatura é a issue 014).
- Para publicar uma release baixável sem login: criar uma tag `v*` (ex.: `git tag v0.1.0 && git push origin v0.1.0`). Esse caminho do workflow ainda não foi exercitado.
- Olhar o visual novo no PC (Forward+) e dizer o que ajustar: o que ainda incomoda (magos, chão, lava, magias). Se quiser acabamento de jogo comercial, decidir se compra/encomenda modelos e texturas.
- Decidir a próxima issue HITL (010 áudio ou 013 multiplayer).

## Mapa rápido
### Simulação (`sim/`)
- `spells.gd`: tabela de magias (só dados) com `behavior`, preços e `per_level`. `Spells.stats(id, nível)`.
  Comportamentos: `projectile` (opcionais `pull`, `turn_rate`), `teleport`, `nova`, `shield`, `delayed_area`.
- `sim_world.gd`:
  - Comandos: `move_command` (andar até um ponto), `steer_command` (andar numa direção até mandar parar; WASD), `cast_command`, `buy_command`, `ready_command`. `move` e `steer` se cancelam: vale o último.
  - Estado: `mages`, `projectiles`, `hazards`, `events` (do último `step`), `phase`, `scores`, `gold`, `shop_ready`.
  - Fases: `countdown` → `round` → `round_end` → `shop` → ... → `match_end`. Sem `rounds_to_win` o mundo é livre (é o que os testes de magia e a 1ª parte do teste de fumaça usam).
  - Eventos: `cast` (todo lançamento; `target` = quem lançou), `hit`, `fizzle`, `reflect`, `blink`, `nova`, `shield`, `explosion`. O áudio (010) pode se pendurar neles.
- `bot.gd`: `Bot.new(mage_id, seed, dificuldade)` e `think(world) -> comandos`.

### Jogo (`game/`)
- `main.gd`: cola. Entrada → comandos (`queue_command`) → `step` a 30 Hz → `view.draw_world`. Com `menu.visible` o mundo não avança. `start_match(setup)` (do menu) e `restart(config)` (F5 e testes) começam partida e fecham o menu.
- `menu.gd`: `CanvasLayer` com 4 modos (`main`, `pause`, `options`, `keys`); só emite sinais (`start_requested`, `settings_changed`, `keymap_changed`...). Cada controle é registrado com os modos em que aparece (`_only`).
- `settings.gd` (janela), `match_setup.gd` (bots, dificuldade, rodadas), `keymap.gd` (teclas): dados puros e testados; cada um é uma seção de `user://settings.cfg` (`window`, `match`, `keys`), gravada com `Settings.write_section` sem apagar as outras.

### Render (`render/`)
- `camera_rig.gd`: matemática pura. 3ª pessoa quando `zoom < THIRD_PERSON_ZOOM` (0.3); `move_direction` (WASD relativo à câmera), `aim_point` (retículo), câmera de ombro (`NEAR.shoulder`).
- `mage_anim.gd`: lógica pura que escolhe a animação (morto > atingido > lançando > correndo > parado). `mage_view.gd`: o modelo, as peças na cor do jogador, escudo e chamas.
- `fx.gd`: fábrica de materiais que brilham e partículas (`trail`, `sparks`, `flames`, `embers`). `lava.gdshader` e `rock.gdshader` (uniformes `energy`; `edge_radius`, `pulse`).
- `arena_view.gd`: desenha tudo. `mage_clip(id)` diz a animação em cartaz (o teste de fumaça usa). `aim_yaw`/`aim_distance`/`selected_slot`/`slot_labels` são escritos pelo `main.gd`. Fora da 3ª pessoa `aim_yaw` acompanha o `facing` do mago, para a câmera entrar por trás dele.

## Controles
- Visão de cima: botão direito move; Q W E R D F (configuráveis) lançam no cursor.
- 3ª pessoa (scroll para perto): W A S D (configuráveis) movem relativo à câmera; mouse capturado gira a mira (horizontal) e afasta/aproxima o retículo (vertical); 1–6 escolhem a magia; clique esquerdo lança no retículo.
- Esc: pausa/menu. F5: repete a partida. F11: tela cheia. Na loja: 1–7 compram, Espaço/Enter encerram.

## Ideias anotadas (fora do escopo feito)
- Em 3ª pessoa a câmera não tem inclinação vertical (o mouse vertical só move o retículo) e o mago vira para onde anda, não para onde mira.
- Opções de áudio no menu entram junto com a 010. Sensibilidade do mouse (`MOUSE_TURN`, `MOUSE_AIM` em `main.gd`) ainda não é opção.
- Visual: o mago é de primitivas (cones e esferas) com poses por código; um modelo esculpido e texturizado à mão seria o próximo salto. Sem ícones de magia (a barra ainda é de quadrados coloridos) e sem arte de menu.
- A Fagulha Teleguiada orbita sem acertar um alvo colado. Com 7 magias e barra de 6, a 7ª comprada não entra na barra e não há como vender.
- O jogador morto vira espectador (câmera no centro), sem trocar de alvo. Um jogador parado morre rápido: os bots miram quem está mais perto.
- "Menu principal" na pausa deixa a partida parada ao fundo até "Jogar" começar outra.
- O CI usa `actions/*@v4` (aviso de Node 20 obsoleto): atualizar as versões quando incomodar.

## Pegadinhas
- Com a câmera em yaw 0 (olhando para +z), a direita da tela é **-x** do mundo (`CameraRig.screen_right`).
- Na nuvem não há Vulkan: o teste de fumaça usa `gl_compatibility` (software). Cores e brilho diferem do Forward+; não ajustar arte fina por essas capturas.
- O teste de fumaça leva de 4 a 5 minutos (timeout de 10 min). É guiado por número de quadro (`--fixed-fps 60`): os quadros negativos são do menu, o teste de pausa congela o contador, e a 2ª parte termina por estado. Ao mudar velocidades ou posições iniciais, recalcular os quadros em `tests/smoke.gd`.
- No teste de fumaça a entrada vai por `Input.parse_input_event` (teclas, mouse). Ao capturar o mouse, o servidor gráfico da nuvem solta movimentos por conta própria: a mira do teste desvia um pouco (por isso a tolerância). No PC isso precisa ser conferido à mão.
- O teste de fumaça não troca opções de janela: um `settings.cfg` com seção `window` faria as rodadas seguintes abrirem em 1600x900 (bem mais lentas). `main.gd` só aplica a janela se `Settings.has_saved()`.
- O teste do arquivo de opções quebrado imprime um `ERROR: ConfigFile parse error` no `check.sh`: é esperado.
- `tools/smoke.sh` falha (exit 1) se o log tiver `SCRIPT ERROR` ou `FALHA`; o log fica em `<pasta>/smoke.log`. Erros de ALSA/áudio são do contêiner.
- Sites de assets (kenney.nl, quaternius.com, itch.io, opengameart.org) são bloqueados na rede da nuvem, mas repositórios **públicos do GitHub** podem ser clonados (`git clone` direto): o KayKit veio assim (depois removido).
- O mago olha para +z, igual ao `facing`; a direita dele é -x (mão do cajado). Os nomes de animação de `MageAnim` (`Idle`, `Spellcast_Shoot`...) vêm do antigo modelo KayKit e hoje só nomeiam poses.
- Os shaders precisam funcionar em Forward+ e em `gl_compatibility` (teste de fumaça): nada de recursos exclusivos de um deles.
- Mago morto na pedra fica caído até a borda passar por ele; só afunda na lava.
- Usar `preload` por caminho em vez de `class_name`. Um teste que não compila conta como falha.
- Testes de magia usam `arena_radius` enorme para a lava não interferir; os de lava usam raio 5.
- O render recebe as posições do tick anterior para interpolar; entidades novas devem entrar em `snapshot_positions()`.
- Efeitos visuais de um tick chegam por `world.events` → `view.show_events()`, logo após cada `step`.
- A vista reaproveita os nós dos magos entre partidas e esconde os que sobram quando a partida nova tem menos magos.
- No teste de fumaça, trocar a config do jogo só a partir do 1º quadro de `_process`.
- Exportação: `tools/export_windows.sh` baixa ~1,2 GB de templates na 1ª vez (no CI ficam em cache). O preset exclui `tests/`, `tools/` e `docs/`. Não dá para rodar o `.exe` na nuvem (sem Wine): só o usuário confirma.
- `gh` na nuvem não tem GraphQL: usar `gh run list/view` e `gh api repos/...` (REST).
