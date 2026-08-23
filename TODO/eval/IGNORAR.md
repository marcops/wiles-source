# Arquivos que podem ser ignorados nesta rodada de revisão

Estes arquivos são triviais (enums simples, protocolos vazios, structs de constantes/tokens, wrappers de uma linha) — foram cobertos pelos 5 agentes na revisão linha-a-linha e não geraram nenhum achado real em nenhuma categoria (Bug/Performance/Architecture/Simplification/Product-UX). Não há necessidade de dedicar atenção a eles nesta passada.

### Protocolos/enums vazios ou quase-vazios
- `Features/ArchiveInspector/ArchiveInspectionServiceProtocol.swift` (6 linhas) — protocolo simples
- `Features/DuplicateCleaner/DuplicateScanResult.swift` (6 linhas) — struct de resultado simples
- `Models/ClipboardAction.swift` (6 linhas) — enum simples
- `Services/ColumnTextSpec.swift` (7 linhas) — struct de spec
- `Services/UndoRecord.swift` (7 linhas) — struct de registro
- `Models/SidebarItem.swift` (8 linhas) — enum/struct simples
- `Services/PathCopyVariant.swift` (8 linhas) — enum simples
- `Features/SmartFolders/SmartFolderServiceProtocol.swift` (9 linhas) — protocolo simples
- `Views/Components/Modal/ModalFooterButton.swift` (9 linhas) — struct de botão simples

### Tokens/constantes/chaves de preferência
- `Models/ViewMode.swift` (10 linhas)
- `Views/Content/LabelWidthKey.swift` (10 linhas) — PreferenceKey
- `Views/Content/URLFrameKey.swift` (10 linhas) — PreferenceKey
- `Views/Modals/FolderPickerTarget.swift` (10 linhas)
- `Views/Theme/MotionTokens.swift` (10 linhas) — apenas constantes de animação
- `Constants/HTTPStatus.swift` (11 linhas)
- `Constants/IconSizeToken.swift` (11 linhas) — apenas constantes
- `Models/DirectoryCacheEntry.swift` (11 linhas)
- `Models/DirectoryLoadResult.swift` (11 linhas)
- `Models/RuleConditionType.swift` (11 linhas)
- `Services/DetailedFileProperties.swift` (11 linhas)
- `Views/Header/PathSegment.swift` (11 linhas)
- `Models/AppState/SearchScope.swift` (12 linhas)
- `Services/ExifMetadata.swift` (12 linhas)
- `Services/NetworkShare.swift` (12 linhas)
- `Services/HapticService.swift` (13 linhas)
- `App/Commands/LocalizedCommands.swift` (15 linhas)
- `Features/DiskSpaceVisualizer/DiskUsageReport.swift` (15 linhas)
- `Constants/AppConstants.swift` (20 linhas)
- `Models/AppState/AppState+Error.swift` (20 linhas)

### Wrappers/structs simples sem lógica de negócio
- `Views/Components/SharedViewHelpers.swift` (14 linhas)
- `Features/DuplicateCleaner/DuplicateGroup.swift` (16 linhas)
- `Models/AppState/Stores/ModalStore.swift` (16 linhas) — apenas flags de apresentação
- `Models/ClipboardState.swift` (16 linhas)
- `Services/DefaultFolderHandlerService.swift` (17 linhas)
- `Views/Components/TranslucentVisualEffectView.swift` (17 linhas) — wrapper NSVisualEffectView
- `Constants/KeyCode.swift` (18 linhas)
- `Features/ArchiveInspector/ArchiveEntryItem.swift` (18 linhas)
- `Services/RealWorkspaceOpener.swift` (18 linhas)
- `Views/Components/FileContextMenuModifier.swift` (18 linhas)
- `Features/SmartFolders/SmartFolder.swift` (19 linhas)
- `Models/AutoOrganizationRule.swift` (19 linhas)
- `Services/WorkspaceOpening.swift` (19 linhas)
- `Views/Components/QLPreviewUnavailableView.swift` (20 linhas)
- `Views/Modals/HelpTab.swift` (20 linhas)

**Nota:** arquivos pequenos que *geraram* algum achado (ex.: `BatchRenameMode.swift`, `UndoActionType.swift`, `SymlinkMode.swift`, `ThumbnailServiceProtocol.swift`, `CrashReportingConstants.swift`, `FilePermissionsService.swift`, `CursorModifier.swift`, `CustomCropRegion.swift`) **não** estão nesta lista — mesmo sendo curtos, têm um problema real documentado em `BUG.md`/`ARCHITECTURE.md`/etc. e merecem atenção.

Arquivos monitor/lifecycle de alto risco (`GlobalKeyMonitor`, `KeyboardSelectionNavigator`, `KeyboardZoomController`, `TerminalViewCache`) foram checados a fundo e considerados limpos — também não estão listados aqui, pois "sem achados" ali é um resultado positivo de uma verificação importante, não trivialidade do arquivo.
