voce deve ler o EVAL.MD.

Deve executar ele ou seja, ver e buscar todos os erros.
Quando terminar, comece a corrigir todos os findings by id,  e APAGUE ELES, eu nao quero ver eles mais no arquivo.
Se voce tiver duvida pule este e va para o proximo EU NAO VOU RESPONDER NADA NESTE MOMENTO SO QUANDO VOCE TERMINAR TUDO.

Para corrigir voce deve, criar o teste unitario, codificar, e depois so rodar o BUILD.

Quanto terminar de corrigir TODOS do finding by IID, entao voce vai rodar o VALIDATE.SH corrigir tudo lint etc, fazer commit e push.æ

Quando terminar este ciclo voce DEVE AGUARDAR 3H
E fazer tudo de novo desta vez ATE COM OS ARQUIVOS QUE ESTAO NO IGNORAR.

depois que terminar este 2 ciclo vai fazer de novo mas desta vez pode pular os arquivos que estao no IGNORAR,

SE TEM ALGUMA DUVIDA PERGUNTA AGORA, depois nao vou mais responder so quando terminar

nao faça teses unitarios de UI UX pode ignorar esta regra e nem precisa fazer / colocar nada em backlog de ui ux.

estes: só unitários de lógica. Nada de UI test / UI_TEST_BACKLOG.
Fim de ciclo: validate.sh → 1 commit (Conventional Commits, inglês) → git push origin/main.
Escopo: corrijo todos os findings by ID (incl. refactors A/O); os que eu ficar em dúvida eu pulo e ficam no arquivo.
Loop infinito a cada 3h, alternando: ciclo ímpar pula IGNORAR.md, ciclo par inclui esses arquivos.

