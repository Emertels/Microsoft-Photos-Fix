# Correção Microsoft Photos (Windows 10 & 11)

Script avançado e automatizado para PowerShell projetado para restaurar, estabilizar e corrigir a rota de inicialização e as associações de arquivos do aplicativo moderno **Microsoft Fotos** (*Microsoft Photos*) no Windows 10 e Windows 11.

---

## 📌 O que este script resolve?

No Windows 10 e 11, o aplicativo moderno do Fotos frequentemente apresenta falhas de rota de abertura, demora excessiva para carregar ao dar dois cliques em arquivos de imagem, ou perde suas associações corretas de registro (`DelegateExecute` / `AUMID`).

Este utilitário:
- ✅ **Corrige a rota de chamada** para que as imagens abram instantaneamente no aplicativo Fotos moderno.
- ✅ **Instala um inicializador leve e isolado** em `%LOCALAPPDATA%\MicrosoftPhotosFix` sem poluir pastas do sistema.
- ✅ **Cria backup automático** das chaves de registro afetadas antes de qualquer alteração (`HKCU:\Software\FotosModernoRouteFix`).
- ✅ **Suporte completo a 20 formatos de imagem**: `.jpg`, `.jpeg`, `.png`, `.bmp`, `.webp`, `.heic`, `.heif`, `.avif`, `.jxl`, `.svg`, `.ico`, `.tiff`, etc.
- ✅ **Totalmente reversível**: você pode desfazer as alterações e voltar ao padrão nativo do Windows a qualquer momento com apenas 1 clique ou comando.

---

## 🚀 Como Usar

### 1. Pré-requisitos
- **Windows 10** (Build 10240 ou superior) ou **Windows 11**.
- Executar no **PowerShell como Administrador** (ou com privilégios de usuário com acesso ao Registro HKCU).

### 2. Modo Interativo (Menu Amigável)
Basta clicar com o botão direito no script e escolher **"Executar com o PowerShell"** (ou abrir o terminal na pasta e executar):

```powershell
.\Correcao-Microsoft-Photos.ps1
```

O script exibirá um menu de terminal interativo com opções para:
1. **Aplicar a correção completa**
2. **Verificar status da rota atual**
3. **Desfazer alterações e restaurar padrão do Windows**
4. **Sair**

---

### 3. Linha de Comando / Automação (Parâmetros)

Você também pode executar o script silenciosamente ou em rotinas de pós-formatação e automação:

| Parâmetro | Descrição |
| :--- | :--- |
| `-Corrigir` | Aplica a correção de rota e associações imediatamente. |
| `-Status` | Exibe um relatório diagnóstico sobre o estado atual do aplicativo Fotos. |
| `-Desfazer` | Reverte todas as modificações do registro para o padrão nativo da Microsoft. |
| `-Silencioso` | Executa sem imprimir mensagens informativas na tela. |

#### Exemplos:
```powershell
# Aplicar correção direto
.\Correcao-Microsoft-Photos.ps1 -Corrigir

# Verificar diagnóstico atual
.\Correcao-Microsoft-Photos.ps1 -Status

# Reverter e desinstalar a correção
.\Correcao-Microsoft-Photos.ps1 -Desfazer
```

---

## 🛡️ Segurança e Reversibilidade
- O script **não** modifica arquivos do sistema protegidos pelo Windows Defender.
- Nenhuma alteração é destrutiva: as chaves originais do Windows são salvas antes de serem atualizadas.
- Ao executar com `-Desfazer`, a rotina limpa a pasta de instalação em `%LOCALAPPDATA%` e restaura as chaves originais.

---

## 👤 Autor
Desenvolvido por **Emerson Teles** ([@Emertels](https://github.com/Emertels))  
🎥 **YouTube:** [@emersonteles2379](https://www.youtube.com/@emersonteles2379)
