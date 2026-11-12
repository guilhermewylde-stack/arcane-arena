# Issues (fatias verticais)

Cada issue entrega algo jogável de ponta a ponta.
Fazer em ordem numérica, respeitando dependências. O jogo já é cliente nativo (Godot); a 011 trata só do instalador.
AFK = pode ser feita sem o usuário. HITL = precisa de decisão do usuário antes.

| # | Título | Tipo | Depende de | Status |
|---|--------|------|-----------|--------|
| 001 | Esqueleto andante: arena, mago, mover, zoom | AFK | — | concluída |
| 002 | Vida, lava e morte | AFK | 001 | concluída |
| 003 | Primeira magia: Brasa (projétil, dano, empurrão) | AFK | 002 | concluída |
| 004 | Bots | AFK | 003 | concluída |
| 005 | Rodadas: arena que encolhe, vitória, placar | AFK | 004 | concluída |
| 006 | Barra de magias e mais 6 magias | AFK | 003 | concluída |
| 007 | Ouro e loja entre rodadas | AFK | 005, 006 | concluída |
| 008 | Controles de 3ª pessoa (WASD + mira) | AFK | 003 | concluída |
| 009 | Passe visual: modelos, animações, partículas, lava, bloom | HITL | 006 | aberta |
| 010 | Áudio | HITL | 006 | aberta |
| 011 | Build Windows automático (export Godot + GitHub Actions) | AFK | 001 | concluída (usuário ainda confirma o `.exe`) |
| 012 | Menu principal e configurar partida | AFK | 007 | concluída |
| 013 | Multiplayer online | HITL | 007 | aberta |
| 014 | Site do jogo, instalador assinado e atualização automática | HITL | 011 | aberta |
| 015 | Steam: página, Steamworks, build e conquistas | HITL | 011, 012 | aberta |
| 016 | Opções de vídeo no menu | AFK | 011, 012 | concluída |
| 017 | Teclas configuráveis | AFK | 012 | concluída |

Não resta issue AFK: as abertas (009, 010, 013, 014, 015) são HITL. A 010 (áudio) inclui as opções de áudio do menu.
