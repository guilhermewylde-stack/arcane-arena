# 011 — Build Windows automático

Status: aberta · AFK · depende de 001

## O que construir
`export_presets.cfg` para Windows x86_64. GitHub Actions: a cada push roda `tools/check.sh`; a cada tag exporta o `.exe` (com templates de exportação do Godot 4.6) e publica como artefato de release. Ícone e nome da janela. Opções de janela: tela cheia, resolução, vsync.

## Aceite
- [ ] CI roda os testes a cada push
- [ ] Tag gera `.exe` Windows baixável
- [ ] Usuário confirma que o `.exe` abre e roda no PC dele
