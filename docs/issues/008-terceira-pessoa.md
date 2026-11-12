# 008 — Controles de 3ª pessoa

Status: concluída · AFK · depende de 003

Com zoom próximo: WASD move relativo à câmera, mouse gira a câmera/mira (mouse capturado), clique esquerdo lança a magia selecionada. Transição suave entre os dois esquemas ao dar zoom. Mira (retículo) no chão.

## Como ficou
- Zoom abaixo de `CameraRig.THIRD_PERSON_ZOOM` (0.3) liga a 3ª pessoa: mouse capturado, câmera de ombro, retículo no chão.
- W A S D viram o comando `steer_command` (direção relativa à câmera); o mouse gira a mira (horizontal) e afasta/aproxima o retículo (vertical).
- 1–6 escolhem a magia da barra; clique esquerdo lança no retículo. Scroll ou Esc voltam à visão de cima.
- Na loja e no fim da partida o cursor é solto, mesmo com zoom próximo.
