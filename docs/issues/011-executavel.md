# 011 — Cliente de PC

Status: aberta · AFK · depende de 001 · **fazer antes da 002**

O jogo é um cliente de PC instalável, não um site. O navegador é só ferramenta de desenvolvimento e de teste automático.

## O que construir
Empacotar com Electron: janela própria sem interface de navegador, tela cheia (F11/Alt+Enter), sem menu, sem zoom/atalhos de navegador, cursor preso à janela quando em jogo. `npm run client` abre o cliente em desenvolvimento; `npm run dist` gera o instalador Windows. GitHub Actions gera o instalador a cada tag e publica como artefato de release.

## Aceite
- [ ] `npm run client` abre o jogo em janela própria
- [ ] Build Windows (instalador .exe) gerado pelo GitHub Actions
- [ ] Renderização com GPU (WebGL2) confirmada no cliente
- [ ] Testes e teste de fumaça no navegador continuam funcionando
