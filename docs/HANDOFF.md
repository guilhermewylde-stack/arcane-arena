# Handoff — prompt da próxima sessão

Copie o bloco abaixo como primeira mensagem da próxima sessão (com o repositório `arcane-arena` selecionado).

```
Projeto Arcane Arena (Godot 4.6). Leia CLAUDE.md e docs/HANDOFF.md e siga o método de trabalho de lá.
Comece rodando bash tools/setup_godot.sh.
Próxima issue: docs/issues/002-vida-lava-morte.md. Faça com TDD, confira com tools/smoke.sh,
feche a issue, faça commit e push. Se sobrar orçamento de contexto (< ~220k), siga para a 003.
No fim, atualize docs/HANDOFF.md e me mande o prompt da sessão seguinte.
```

## Estado atual
- Motor: Godot 4.6, GDScript. O protótipo inicial em TypeScript/Three.js foi descartado.
- Issue 001 concluída: arena, um mago, mover com botão direito, zoom de cima ↔ 3ª pessoa.
- 11 testes passando (`bash tools/check.sh`).

## Pegadinhas
- Com a câmera em yaw 0 (olhando para +z), a direita da tela é **-x** do mundo. É esperado.
- Na nuvem não há Vulkan: o teste de fumaça usa `--rendering-method gl_compatibility` (renderização por software). As cores e o brilho diferem um pouco do Forward+ que o jogador vê; não ajustar arte fina com base nessas capturas.
- Erros de ALSA/áudio na saída do teste de fumaça são do contêiner, não do jogo.
- Usar `preload` por caminho em vez de `class_name` (ver CLAUDE.md).
- O render recebe as posições do tick anterior para interpolar; ao adicionar entidades novas (projéteis etc.), interpolar do mesmo jeito.
- Build Windows ainda não existe (issue 011); para jogar, abrir `project.godot` no editor Godot 4.6 e apertar F5.
