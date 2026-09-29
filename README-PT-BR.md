# 🖼️ Correção Microsoft Photos (Windows 10 & 11)

<div align="center">

**🌐 Idiomas / Languages:**  
  <a href="README-PT-BR.md"><img src="https://img.shields.io/badge/Documenta%C3%A7%C3%A3o-Portugu%C3%AAs%20(Brasil)-green?style=for-the-badge" alt="PT-BR"></a>
  <a href="README-EN.md"><img src="https://img.shields.io/badge/Documentation-English-blue?style=for-the-badge" alt="EN"></a>
  <a href="CHANGELOG-PT-BR.md"><img src="https://img.shields.io/badge/Changelog-PT--BR-purple?style=for-the-badge" alt="Changelog PT-BR"></a>
  <a href="CHANGELOG-EN.md"><img src="https://img.shields.io/badge/Changelog-EN-darkblue?style=for-the-badge" alt="Changelog EN"></a>

</div>

---

Script avançado e automatizado para PowerShell desenvolvido para sanar de forma definitiva a falha crônica de inicialização, associação de rotas e aplicação de papéis de parede do aplicativo moderno **Microsoft Fotos** (*Microsoft Photos*) no Windows 10 e Windows 11.

---

## 🛑 O Problema Crônico: O que acontece na prática?

Se você utiliza o Windows 10 ou 11, é praticamente certo que já se deparou com este problema: **não importa quantas vezes você formate o computador ou reinstale o sistema, cedo ou tarde o bug crônico do Microsoft Fotos reaparece.**

### O Sintoma
Ao abrir uma imagem dando dois cliques nela e tentar definir essa imagem como **Papel de Parede da Área de Trabalho** ou **Tela de Bloqueio** diretamente pelo menu interno do visualizador (pelos três pontinhos ou botão direito dentro do app):
- ❌ **O papel de parede simplesmente não é aplicado.** O sistema falha silenciosamente ou ignora a solicitação.

### Os Contornos Inconvenientes (Antes deste script)
Até a criação desta correção, o usuário era obrigado a recorrer a contornos incômodos:
1. Ter que abrir primeiro o aplicativo Fotos pelo Menu Iniciar, navegar pelas pastas internas do app e abrir a imagem por lá para só então conseguir aplicar; OU
2. Não abrir a foto e ter que clicar com o botão direito diretamente no arquivo dentro do Windows Explorer para escolher "Definir como tela de fundo da área de trabalho".

### 🔍 A Causa Raiz
O aplicativo moderno da Microsoft utiliza uma rota de chamada via protocolo COM (`DelegateExecute` / AUMID / `AppX`). Devido a inconsistências no registro do Windows e permissões de sandbox, quando a imagem é aberta pela rota padrão de arquivos, o aplicativo perde o contexto de privilégios necessário para acionar a API de troca de papel de parede do sistema operacional.

---

## 💡 A Solução Definitiva Deste Script

Este script executa uma manobra de engenharia segura e definitiva no sistema:

- ⚙️ **Compilação e Instalação de Launcher Isolado:** Cria um inicializador ultraleve em `%LOCALAPPDATA%\MicrosoftPhotosFix` (`FotosModernRouteLauncherV2.exe`) compilado localmente em C# puro.
- 🎯 **Redirecionamento Inteligente de Rota:** Reassocia os manipuladores de arquivo para que as imagens abram instantaneamente preservando a identidade completa do processo pai, restaurando 100% a capacidade de definir papel de parede e tela de bloqueio direto pelo visualizador.
- 🛡️ **Backup Automático Completo:** Antes de alterar qualquer chave, salva um instantâneo do registro original em `HKCU:\Software\FotosModernoRouteFix`.
- 🔄 **Totalmente Reversível:** A qualquer momento, com apenas 1 comando ou clique (`-Desfazer`), todas as configurações originais da Microsoft são restauradas e a pasta temporária é limpa.
- 🖼️ **Suporte a 20 Formatos de Imagem:** `.jpg`, `.jpeg`, `.jpe`, `.jfif`, `.png`, `.bmp`, `.dib`, `.gif`, `.tif`, `.tiff`, `.webp`, `.heic`, `.heif`, `.hif`, `.avif`, `.jxl`, `.jxr`, `.wdp`, `.ico` e `.svg`.

---

## 🚀 Como Usar

### 1. Pré-requisitos
* **Windows 10** (Build 10240 ou superior) ou **Windows 11**.
* Executar com o **PowerShell** (não requer privilégios invasivos de kernel; atua no escopo seguro do usuário `HKCU`).

### 2. Modo Interativo (Menu Amigável no Terminal)
Basta clicar com o botão direito no arquivo `Microsoft-Photos-Fix.ps1` e selecionar **"Executar com o PowerShell"** (ou abrir o terminal na pasta e digitar):

```powershell
.\Microsoft-Photos-Fix.ps1
```

O menu interativo será exibido na tela:
```text
=====================================================
         CORREÇÃO DO MICROSOFT FOTOS MODERNO         
=====================================================
 [STATUS ATUAL] -> NÃO INSTALADO / CORRIGIDO E ATIVO
-----------------------------------------------------
 1 - Aplicar / Atualizar correção
 2 - Desfazer correção (Restaurar padrão original)
 3 - Ver status detalhado
 0 ou Esc - Sair
-----------------------------------------------------
```

### 3. Execução Silenciosa e Automação (CLI)

Ideal para rotinas de pós-formatação, scripts de otimização ou administradores de TI:

| Parâmetro | Função |
| :--- | :--- |
| `-Corrigir` | Aplica a correção de rota, instala o launcher e ajusta o registro imediatamente. |
| `-Status` | Exibe o relatório de diagnóstico da rota e das associações atuais. |
| `-Desfazer` | Remove o launcher e restaura integralmente o padrão nativo da Microsoft. |
| `-Silencioso` | Executa a operação sem exibir mensagens na tela. |

#### Exemplos de comandos:
```powershell
# Aplicar a correção direto:
.\Microsoft-Photos-Fix.ps1 -Corrigir

# Consultar o diagnóstico atual do Fotos:
.\Microsoft-Photos-Fix.ps1 -Status

# Reverter e voltar ao padrão de fábrica do Windows:
.\Microsoft-Photos-Fix.ps1 -Desfazer
```

---

## 🛡️ Segurança e Integridade
* **Sem modificações destrutivas:** Nenhum arquivo nativo do Windows é excluído ou corrompido.
* **100% Transparente:** Código aberto em PowerShell e C# visível para auditoria.
* **Compatível com Windows Defender:** Não dispara falsos positivos por operar dentro dos padrões oficiais de registros de usuário do Windows.

---

## 👤 Sobre o Autor

Desenvolvido e mantido por **Emerson Teles** (conhecido na comunidade como **Emertels**).

Apaixonado por tecnologia, informática, jogos, manutenção de sistemas e tradução/localização de softwares e emuladores para o Português do Brasil (PT-BR).

### 🛠️ Projetos & Contribuições Notáveis:
- **Suítes de Automação & Utilitários no GitHub:**
  - **[Suite-Emuladores](https://github.com/Emertels/Suite-Emuladores)** — Suíte inteligente em PowerShell para download e atualização autônoma de 56 emuladores e frontends.
  - **[AI-Chat-Vault](https://github.com/Emertels/AI-Chat-Vault)** — Backup portátil e recuperação de conversas locais de 20 IAs agenticas e ferramentas de programação.
  - **[Microsoft-Photos-Fix](https://github.com/Emertels/Microsoft-Photos-Fix)** — Correção avançada em PowerShell e C# para rota de abertura e papel de parede no Microsoft Fotos.
  - **[Roccat-Syn-Pro-Air-Fix](https://github.com/Emertels/Roccat-Syn-Pro-Air-Fix)** — Suíte definitiva de estabilização, áudio e blindagem anti-queda para headset sem fio.
- **Emulação & Consoles:** Criador e arquiteto da **[PSBBN-Translator](https://github.com/Emertels/PSBBN-Translator)** para o PS2 (40 idiomas); localização e suporte a emuladores como **PSBBN**, **PCSX2**, **Dolphin**, **shadPS4**, **Azahar** e **RetroArch**.
- **Softwares & Utilitários:** Tradução 100% de **DSX** (DualSense X - Trusted Translator), **ASUS GPU Tweak III**, **dnGrep**, **XWidget** e ferramentas web (**DualSense Tester**, **DualShock Tools**).
- **Jogos:** Tradução de **Silent Hill 5: Homecoming**, projetos em andamento em **Silent Hill 4: The Room** e diversos outros aplicativos.

---

### 🌐 Conecte-se comigo & Comunidades Oficiais:

<div align="left">

[![GitHub](https://img.shields.io/badge/GitHub-Emertels-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/emertels)
[![Website](https://img.shields.io/badge/Website-Emerson_Teles-0070F3?style=for-the-badge&logo=googlechrome&logoColor=white)](https://emertels.github.io)
[![Discord](https://img.shields.io/badge/Discord-Emertels%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://emertels.github.io/discord)
[![X / Twitter](https://img.shields.io/badge/X_Twitter-@emertels-000000?style=for-the-badge&logo=x&logoColor=white)](https://x.com/emertels)
[![YouTube](https://img.shields.io/badge/YouTube-Emerson_Teles-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@emersonteles2379)
[![Telegram](https://img.shields.io/badge/Telegram-Aplicativos%20Mods-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/apksmodsandroid)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Apoiar%20Projeto-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white)](https://ko-fi.com/emertels)

</div>
