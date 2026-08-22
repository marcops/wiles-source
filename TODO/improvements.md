## Bugs

- Committed secret — `Constants/CrashReportingConstants.swift:15`. `github_pat_...` token hardcoded, compiled into the binary. Not rotated yet (deliberately left as-is for now).


- permite remover todos os itens do sidebar mas ele segue ali

- o side bar esta mostrando o scrollbar errado, nao tem nada na vertical e traz, e no horizontal esta montando tb errado, nao tem nada que ocupasse tanto espaco e estava trazendo o calculo esta bem errado.

- implementar os testes unitarios que faltam porque alteramos muito, cobrir o maximo que puder 100% do que for possivel - so pode pular o que der muito trabalho e pouco retorno

## Low priority / undecided

-  o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos
- hide the back and forward, and increase the Title font? with on/off
- create the director view and traditional view?

- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does (reusing whichever view mode is active — Grid/List Column) and let the user navigate inside it normally. Double-clicking a file *inside* that zip should extract it to a temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet (`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature absorbs it.



## Produto

- **Maior lacuna competitiva: sem modo dual-pane.** É o recurso de assinatura do Path Finder/ForkLift/Commander One e não existe em nenhuma forma no Wiles. (eu realmente nao gosto desta feature nao vejo vantagem)

- Sem integração com nuvem/protocolo remoto além do badge passivo de iCloud e descoberta (não conexão) de SMB via Bonjour. (nao sei se vale a pena no momento que nuvem? drive e outros?)


- `FileShredder` não tem sheet própria (é só um serviço, diferente de toda feature irmã). 
passwordCompressSheetView/DuplicateCleanerSheetView: um sheet com a lista dos arquivos selecionados a apagar, uma escolha de método (rápido/sem sobrescrever vs. seguro/sobrescrevendo N vezes — o FileShredderService já tem essa lógica de chunk overwrite), um aviso claro de "isso é irreversível", barra de progresso durante o shred (arquivo grande pode demorar), e confirmação final antes de rodar — seguindo o ModalScaffoldView que todas as outras features já usam.
A troca é: mais fricção (um passo a mais antes de apagar) vs. mais segurança visual pra uma ação destrutiva e irreversível — hoje ela roda sem nenhuma tela intermediária. Quer que eu desenhe isso como plano antes de codar, ou é só curiosidade por enquanto?