# AGENTS.md — Projeto Microsoft Photos Fix (Windows 10 & 11)

> **Contexto para Agentes de IA (Antigravity / Claude / Gemini / Copilot)**:  
> Este documento descreve a arquitetura, regras de negócio, engenharia reversa do subsistema UWP, manobras de contorno (*workarounds*) e rotinas operacionais deste repositório.  
> Se você for um agente de IA assumindo este workspace em qualquer máquina, ambiente ou sessão, siga estritamente as diretrizes abaixo para manter o projeto íntegro, limpo e estável.

---

## 1. Visão Geral e Arquitetura do Problema

O aplicativo moderno **Microsoft Fotos** (*Microsoft Photos* — AUMID: `Microsoft.Windows.Photos_8wekyb3d8bbwe!App`) é um pacote UWP (Universal Windows Platform) empacotado pela Microsoft Store que executa sob a sandbox restritiva do Windows (**AppContainer**).

### A Falha Crônica
Em todas as versões do Windows 10 e Windows 11, existe uma falha persistente de projeto na rota padrão de abertura de imagens:
1. **O Sintoma**: Quando o usuário abre qualquer arquivo de imagem dando dois cliques no Windows Explorer e tenta usar as opções **"Definir como tela de fundo"** ou **"Definir como tela de bloqueio"** dentro do aplicativo Fotos (seja pelo menu de três pontos ou pelo botão direito):
   - O aplicativo falha silenciosamente ou ignora a ordem;
   - A imagem de fundo simplesmente **não é aplicada**.
2. **A Causa Raiz**: O manipulador COM padrão registrado no Windows Explorer usa a diretiva `DelegateExecute: {BFEC0C93-0B7D-4F2C-B09C-AFFFC4BDAE78}`. Ao abrir por essa rota indireta de shell, o processo `Photos.exe` inicializa sem herdar o token de privilégio de contexto do arquivo original necessário para despachar a chamada à API `IActiveDesktop` / `SystemParametersInfo(SPI_SETDESKWALLPAPER)`.
3. **Por que a rota de protocolo resolve**: Quando a imagem é ativada pelo manipulador de protocolo URI `ms-photos:viewer?fileName=<caminho_escapado>`, o aplicativo carrega a imagem em modo de visualização rica com contexto total do arquivo, liberando de forma imediata e definitiva as funções de definir papel de parede e tela de bloqueio.

---

## 2. Estrutura de Arquivos do Repositório

```
Microsoft-Photos-Fix/
├── Microsoft-Photos-Fix.ps1   # Script PowerShell Master (UI interativa, CLI silencioso e compilador C#)
├── README.md                  # Documentação principal para o GitHub (PT-BR padrão com links de idioma)
├── README-PT-BR.md            # Manual do usuário em Português do Brasil
├── README-EN.md               # Manual do usuário em Inglês
├── AGENTS.md                  # Especificação arquitetural técnica para agentes de IA (PT-BR)
├── AGENTS_EN.md               # Especificação técnica para agentes de IA (Inglês)
├── LICENSE                    # Licença MIT
└── .gitignore                 # Filtro de arquivos locais e temporários
```

---

## 3. As 10 Manobras Críticas de Engenharia

Ao refatorar, otimizar ou manter o código de `Microsoft-Photos-Fix.ps1`, **NUNCA altere ou remova** as 10 manobras a seguir:

### Manobra 1: Redirecionamento por Protocolo URI (`ms-photos:viewer?fileName=...`)
- **Mecanismo**: O lançador nativo recebe o caminho do arquivo `%1`, normaliza para caminho absoluto com `Path.GetFullPath()`, codifica os caracteres especiais com `Uri.EscapeDataString()` e dispara `Process.Start("ms-photos:viewer?fileName=" + uri)`.
- **Impacto**: Esta é a única rota que garante a ativação do Fotos com contexto total para troca de wallpaper, sem depender de janelas intermediárias do PowerShell.

### Manobra 2: Deleção do Alternate Data Stream (`:Zone.Identifier`)
- **Problema**: Imagens baixadas da web, Google Chrome, navegadores ou WhatsApp recebem o fluxo NTFS oculto `:Zone.Identifier` (Mark of the Web). O contêiner sandbox UWP do Fotos frequentemente bloqueia ou recusa carregar imagens marcadas quando acionado por protocolo.
- **Solução**: O lançador executa `DeleteFileW(fullPath + ":Zone.Identifier")` via P/Invoke da `kernel32.dll` antes de abrir a imagem.

### Manobra 3: Isolamento do Helper no `%LOCALAPPDATA%\MicrosoftPhotosFix`
- **Problema**: Gerar o binário compilado (`FotosModernRouteLauncherV2.exe`) na pasta de Downloads ou na pasta do repositório polui visualmente o diretório do usuário e corre o risco de ser deletado acidentalmente.
- **Solução**: O compilador C# embutido no script gera o executável no `%TEMP%` e move atomicamente para `%LOCALAPPDATA%\MicrosoftPhotosFix\FotosModernRouteLauncherV2.exe`. A pasta de trabalho do usuário permanece **exclusivamente com o script `.ps1`**.

### Manobra 4: Proteção Anti-Autodeleção na Tarefa Agendada (`Remove-OldLaunchers`)
- **Problema Crítico**: A tarefa agendada que roda no logon executa a cópia do script que reside em `%LOCALAPPDATA%\MicrosoftPhotosFix\`. Se a função de limpeza verificar `$script:CurrentFolder` sem validar se é o próprio diretório de instalação, **a tarefa deletará seu próprio executável `.exe` em cada reinicialização do PC**, quebrando a associação e abrindo o diálogo *"Como deseja abrir este arquivo .jpg?"*.
- **Solução Imutável**:
  ```powershell
  $currFull = [IO.Path]::GetFullPath($script:CurrentFolder).TrimEnd('\')
  $instFull = [IO.Path]::GetFullPath($script:InstallDir).TrimEnd('\')
  if ($currFull -ne $instFull) {
      # Remove executáveis residuais da pasta de trabalho, mas NUNCA do InstallDir!
  }
  ```

### Manobra 5: Alvo Cirúrgico no ProgID de Imagens (`AppX4mntx4h978m1v9gtzv0ewksfd6pmwsre`)
- **Problema Crítico**: O aplicativo Fotos registra mais de 8 ProgIDs no registro do Windows (incluindo reprodutor de vídeo, rolo de câmera e interfaces COM internas). Modificar o `DelegateExecute` de ProgIDs auxiliares causa colapso na inicialização do subsistema UWP com erro fatal:
  > **`Photos.exe - Erro de aplicativo (0xc0000142)` (`STATUS_DLL_INIT_FAILED`)**
- **Solução**: O script filtra estritamente por extensões suportadas e associações ativas (`UserChoice` / `OpenWithProgids`), atuando exclusivamente no ProgID de fotos primário (`AppX4mntx4h978m1v9gtzv0ewksfd6pmwsre`). Os demais ProgIDs do sistema permanecem intactos.

### Manobra 6: Menu Interativo Fluido com `Clear-Host` e Tecla Única (`ReadKey`)
- **Problema**: O uso tradicional de `Read-Host` em loops de terminal gera acúmulo infinito de menus na tela a cada comando executado, além de engolir quebras de linha que geram mensagens falsas de "Opção inválida".
- **Solução**:
  - Limpeza de tela ativa (`Clear-Host`) antes de cada desenho do menu;
  - Leitura não-bloqueante por tecla única via `[Console]::ReadKey($true)` (com fallback automático para `Read-Host` em terminais redirecionados);
  - Pressionar `1`, `2`, `3`, `0` executa a opção instantaneamente;
  - Tecla `Enter` limpa e volta ao menu principal;
  - Tecla `Esc` fecha a janela na hora.

### Manobra 7: Codificação UTF-8 com BOM Obrigatória
- **Problema**: O Windows PowerShell 5.1 interpreta scripts salvos em UTF-8 puro (sem BOM) como Windows-1252/ANSI, corrompendo palavras com acentuação (`ç`, `ã`, `é`, etc.) e gerando mojibake no terminal.
- **Solução**: Todos os scripts `.ps1` deste repositório devem ser salvos rigorosamente com **UTF-8 com BOM** (`[System.Text.UTF8Encoding]::new($true)`).

### Manobra 8: Persistência Pós-Atualização (Tarefa Agendada)
- **Mecanismo**: Registra uma tarefa em `TaskScheduler` (`\Fotos moderno - manter rota corrigida`) com dois disparadores:
  1. `LogonTrigger` (Trigger 9): Garante a integridade a cada inicialização de sessão do usuário;
  2. `EventTrigger` (Trigger 0): Monitora o canal `Microsoft-Windows-AppXDeploymentServer/Operational` pelo Evento `822` (atualização de pacotes da Microsoft Store). Se a Store atualizar o Fotos e resetar as chaves, a rota é reaplicada automaticamente em segundo plano.

### Manobra 9: Notificação Shell em Tempo Real (`SHChangeNotify`)
- **Mecanismo**: Após alterar as chaves de registro em `HKCU:\Software\Classes`, o script invoca a API nativa do Windows via P/Invoke:
  ```csharp
  [DllImport("shell32.dll")]
  public static extern void SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);
  ```
  Com `eventId = 0x08000000` (`SHCNE_ASSOCCHANGED`).
- **Impacto**: O Windows Explorer atualiza seu cache interno de ícones e associações instantaneamente, sem necessidade de reiniciar o processo `explorer.exe` ou fazer logoff.

### Manobra 10: Reversibilidade Total e Restauração de Snapshot (`-Desfazer`)
- **Mecanismo**: Antes de gravar qualquer rota, o script faz snapshot de `(default)` e `DelegateExecute` em `HKCU:\Software\FotosModernoRouteFix\<ProgId>`.
- **Restauração**: O parâmetro `-Desfazer` (ou opção 2 do menu) restaura os valores exatos de `DelegateExecute`, remove as chaves customizadas, exclui a tarefa agendada, purga a pasta em `%LOCALAPPDATA%\MicrosoftPhotosFix` e notifica o shell, devolvendo a máquina ao padrão de fábrica da Microsoft.

---

## 4. Diretrizes e Regras Estritas para Agentes

1. **Compatibilidade PowerShell 5.1**: Todo código deve ser testado e compatível com o Windows PowerShell 5.1 nativo (não utilize comandos exclusivos do PowerShell 7+ que não existam no 5.1).
2. **Escopo HKCU (Sem Privilégios Elevados Obrigatórios)**: O script foi desenhado para atuar no escopo do usuário atual (`HKCU`), dispensando elevação de Administrador forçada. Não mova rotas para `HKLM`.
3. **Nomes de Arquivos no Git**:
   - O arquivo principal do repositório no GitHub deve ser mantido como `Microsoft-Photos-Fix.ps1` (sem espaços), facilitando comandos no terminal e scripts de automação.
4. **Sincronização com o GitHub**:
   - O repositório remoto oficial é: `https://github.com/Emertels/Microsoft-Photos-Fix.git` (branch `main`).
   - Mantenha sempre os arquivos `README.md`, `README-PT-BR.md`, `README-EN.md`, `AGENTS.md` e `AGENTS_EN.md` alinhados com qualquer alteração nas opções ou parâmetros do script.
