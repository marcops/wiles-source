import Foundation

public struct PermissionService: Sendable {
    /// Dispara os prompts de permissão do macOS (TCC) para as pastas principais
    /// no momento em que o app abre. Isso evita que o usuário seja interrompido
    /// múltiplas vezes enquanto navega, pedindo tudo de uma vez.
    public static func requestInitialPermissions() {
        let fm = FileManager.default
        let folders: [URL] = [
            fm.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        Task.detached(priority: .background) {
            for folder in folders {
                // Apenas tentar ler o diretório já dispara o prompt nativo do macOS
                // caso o app ainda não tenha permissão.
                _ = try? fm.contentsOfDirectory(atPath: folder.path)
            }
        }
    }
}
