---
name: push source
description: Rapidly commits and pushes only the source code to the private repository, bypassing releases and binaries.
---

# Push Source Skill

When the user invokes "push source" or explicitly asks to commit/push the source code quickly:

1. **Do not explain what you are going to do.** (Zero papo, jogo rápido).
2. Execute the commit and push immediately. Run the following command:
   `git add Sources/Wiles .agents && git commit -m "<generate appropriate message here>" && git push`
3. **Strict Constraints**: 
   - Never build the app.
   - Never create DMG/ZIP files.
   - Never push to the public tap/repository.
4. Once the command finishes, reply with a single, extremely brief confirmation sentence (e.g., "Feito! Source no repositório.").
