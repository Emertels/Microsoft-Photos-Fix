# 🖼️ Correção Microsoft Photos (Windows 10 & 11)

<div align="center">

**🌐 Idiomas / Languages:**  
[![Português Brasil](https://img.shields.io/badge/Idioma-Portugu%C3%AAs%20(Brasil)-green?style=for-the-badge)](README-PT-BR.md)
[![English](https://img.shields.io/badge/Language-English-blue?style=for-the-badge)](README-EN.md)

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
==================================================
   CORREÇÃO ROTA MICROSOFT FOTOS (WINDOWS 10/11)  
==================================================
1. Aplicar correção completa
2. Verificar status da rota atual
3. Desfazer alterações e restaurar padrão
4. Sair
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

## 👤 Autor
Desenvolvido por **Emerson Teles**  
💻 **GitHub:** [@Emertels](https://github.com/Emertels)  
🎥 **YouTube:** [@emersonteles2379](https://www.youtube.com/@emersonteles2379)
