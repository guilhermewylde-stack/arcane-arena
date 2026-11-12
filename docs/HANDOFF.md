# Handoff — prompt da próxima sessão

Copie o bloco abaixo como primeira mensagem da próxima sessão (com o repositório `arcane-arena` selecionado).

```
Projeto Arcane Arena. Leia CLAUDE.md e docs/HANDOFF.md e siga o método de trabalho de lá.
Próxima issue: docs/issues/011-executavel.md (cliente de PC). Confira o cliente abrindo de verdade,
feche a issue, faça commit e push. Se sobrar orçamento de contexto (< ~220k), siga para a 002
e depois a 003, com TDD.
No fim, atualize docs/HANDOFF.md e me mande o prompt da sessão seguinte.
```

## Estado atual
- Issue 001 concluída: arena, um mago, mover com botão direito, zoom de cima ↔ 3ª pessoa.
- 11 testes passando (`npm run check`).
- O jogo ainda só roda no navegador (`npm run dev`); o cliente de PC é a issue 011, a próxima.

## Pegadinhas
- Com a câmera em yaw 0 (olhando para +z), a direita da tela é **-x** do mundo. É esperado.
- Teste de fumaça no navegador: `npm run build && npx vite preview --port 4173`, depois Playwright com
  `chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] })`; o estado fica em `window.__game`.
- `render()` recebe o mundo anterior e o atual para interpolar; ao adicionar entidades novas, interpolar do mesmo jeito.
