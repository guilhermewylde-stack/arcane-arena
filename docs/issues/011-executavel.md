# 011 — Build Windows automático

Status: concluída (falta só o usuário confirmar o `.exe` no PC dele) · AFK · depende de 001

## O que construir
`export_presets.cfg` para Windows x86_64. GitHub Actions: a cada push roda `tools/check.sh`; a cada tag exporta o `.exe` (com templates de exportação do Godot 4.6) e publica como artefato de release. Ícone e nome da janela. Opções de janela: tela cheia, resolução, vsync.

## Aceite
- [x] CI roda os testes a cada push
- [x] Tag gera `.exe` Windows baixável (o build já roda e sai como artefato a cada push; a publicação da release só será exercitada na primeira tag `v*`)
- [ ] Usuário confirma que o `.exe` abre e roda no PC dele

## Como ficou
- `export_presets.cfg` (preset "Windows", `.pck` embutido: um único `ArcaneArena.exe`), `tools/export_windows.sh` (baixa os templates na 1ª vez).
- `.github/workflows/ci.yml`: a cada push roda os testes e exporta o `.exe` (artefato `ArcaneArena-windows` na aba Actions); tag `v*` publica o mesmo arquivo como release.
- Ícone original em `assets/` (janela e `.exe`); versão em `project.godot` (`config/version`).
- Opções de janela em `game/settings.gd` → `user://settings.cfg` (`fullscreen`, `width`, `height`, `vsync`). F11 alterna e salva; a tela de opções entra na issue 016.
