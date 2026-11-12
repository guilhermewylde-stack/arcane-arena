# PRD — Arcane Arena

## Problema
Quero um jogo de PC de arena de magos: partidas curtas e caóticas em que a habilidade está em mirar, desviar e empurrar os outros para fora da plataforma.

## Solução
Jogo 3D original. 2 a 8 magos numa plataforma circular cercada de lava. Magias causam dano e **empurrão**; quanto mais dano acumulado, mais longe o mago voa. A plataforma encolhe ao longo da rodada. Fora dela, a lava queima. O último de pé vence a rodada; entre rodadas, ouro compra e melhora magias. Vence quem ganhar mais rodadas.

## Histórias de usuário
1. Como jogador, movo meu mago com o botão direito na visão de cima.
2. Como jogador, uso o scroll para ir da visão de cima (estilo MOBA) até 3ª pessoa atrás do mago, e jogo em qualquer uma.
3. Como jogador, em 3ª pessoa movo com WASD e miro com o mouse.
4. Como jogador, lanço magias por teclas (Q W E R D F) mirando com o cursor, com recarga visível.
5. Como jogador, sou empurrado ao ser atingido, mais longe quanto mais dano já levei.
6. Como jogador, levo dano contínuo na lava e vejo minha vida e a dos outros.
7. Como jogador, vejo a plataforma encolher e sou pressionado para o centro.
8. Como jogador, enfrento bots que andam, desviam e lançam magias.
9. Como jogador, entre rodadas gasto ouro numa loja para comprar e evoluir magias.
10. Como jogador, vejo placar, vencedor da rodada e da partida.
11. Como jogador, tenho menu, opções de vídeo/áudio e teclas configuráveis.
12. Como jogador, instalo e rodo o jogo no Windows como um executável.
13. Como jogador, jogo online com amigos (fase posterior).
14. Como interessado, conheço o jogo num site próprio, com trailer, capturas e download/compra.
15. Como jogador, encontro e compro o jogo na Steam (possível, a decidir).

## Decisões de implementação
- **Cliente de PC, não jogo de navegador**: o produto é um executável instalável (Electron) com janela própria; o navegador é só ferramenta de desenvolvimento e teste.
- **Stack**: TypeScript + Three.js + Vite; cliente via Electron. Escolhida por ser totalmente testável e verificável em sessões de agente (testes headless + navegador).
- **Simulação determinística** em passo fixo de 30 Hz, separada do render; entrada vira `Command`. Base para bots, replays e netcode.
- **Física 2D** no plano do chão (posição, velocidade, atrito); altura é só visual.
- **Magias** definidas como dados (tabela) + poucos comportamentos (projétil, área, teleporte, gancho, escudo), para a loja e o balanceamento serem só números.
- **Multiplayer**: servidor autoritativo rodando a mesma `src/sim`, WebSocket, predição no cliente. Só depois do jogo solo estar divertido.
- **Visual**: câmera de cima com perspectiva, luz direcional com sombras, personagens estilizados low-poly, efeitos de partículas e bloom. Arte própria ou de licença livre (CC0), sempre registrada em `docs/CREDITS.md`.

## Distribuição
Jogo comercial autopublicado para PC (Windows primeiro). Canal principal: site próprio com download do instalador. Steam é uma possibilidade futura, então nada pode impedi-la:
- Todo asset (modelos, sons, fontes, música) precisa de licença que permita **uso comercial**; registrar origem e licença em `docs/CREDITS.md`. Dependências de código só com licenças permissivas (MIT/BSD/Apache).
- Nome, magias, personagens e arte 100% próprios; verificar disponibilidade do nome final (marca, domínio, Steam) antes de divulgar — "Arcane Arena" é nome de trabalho.
- Electron é compatível com Steam (integração Steamworks via biblioteca nativa, overlay, conquistas) — tratar numa issue própria.
- Instalador assinado e atualização automática entram junto com o site.

## Conjunto inicial de magias (nomes próprios)
Brasa (projétil), Passo Etéreo (teleporte curto), Vendaval (empurrão em área), Corrente (puxa o alvo), Égide (reflete projéteis), Cometa (área com atraso), Fagulha Teleguiada (projétil que persegue).

## Testes
Toda regra de jogo é testada pela interface de `src/sim` (`createWorld`/`step`). Render é verificado por teste de fumaça no navegador.

## Fora de escopo (por enquanto)
Matchmaking, contas, ranking, mobile, controle (gamepad), editor de mapas, monetização.
