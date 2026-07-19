# 🏢 Leituras MC - Sistema Inteligente de Gestão de Consumo

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

> **Projeto Carro-Chefe | Setor de Engenharia & Tecnologia - MC Prestadora de Serviços**

O **Leituras MC** é uma plataforma SaaS B2B ponta-a-ponta desenvolvida para revolucionar a forma como Administradoras de Condomínios e Empresas de Leitura gerem o consumo de Água, Gás e Energia. 

Ao combinar uma arquitetura **Multi-Tenant**, operação **Offline-First**, e reconhecimento ótico via **Inteligência Artificial (Google Cloud Vision)**, este ecossistema digitaliza, audita e blinda contra fraudes todo o processo de faturamento de utilidades em condomínios.

---

## ✨ Principais Funcionalidades

O sistema é estruturado em três verticais operacionais nativas com Controlo de Acesso Baseado em Cargos (RBAC):

### 📱 1. Aplicativo Mobile (Operação de Campo - Leituristas)
Desenhado para velocidade, confiabilidade em áreas sem internet e coleta de provas rigorosas.
*   **Arquitetura Offline-First (SQLite):** O aplicativo funciona 100% sem internet (ideal para subsolos e garagens). As leituras são guardadas numa "Caixa de Saída" local e sincronizadas com a nuvem de forma assíncrona assim que a conexão é restabelecida.
*   **Leitura Assistida por Inteligência Artificial (OCR):** Integração com a API do Google Cloud Vision para ler o medidor através da câmera do telemóvel, extraindo os números automaticamente e evitando erros de digitação humana.
*   **Motor Anti-Fraude e Validação de Limites:** Cálculo automático do consumo em tempo real baseado no mês anterior. Se o consumo exceder um limite configurado (ex: > 1m³), o sistema trava e **obriga a captura de uma evidência fotográfica** otimizada e compactada.
*   **Gestão Dinâmica de Roteiros:** O funcionário de campo apenas tem acesso e visualiza os condomínios que lhe foram previamente atribuídos pelo gestor.
*   **Acessibilidade e UX:** Suporte global nativo a Modo Claro/Modo Escuro (*Dark Mode*) controlável via interface.

### 💻 2. Painel Administrativo (Empresas / Administradoras)
O centro de controlo para auditar leituras e faturar clientes finais com confiança.
*   **Auditoria Visual:** Painel para validação cruzada entre o número digitado e a fotografia capturada pelo leiturista no ato da leitura.
*   **Trava Jurídica (Fechamento de Lote):** Sistema de bloqueio de período. Uma vez que o mês é "fechado" pela administradora, o Firebase Security Rules bloqueia a nível de servidor qualquer alteração de dados, garantindo a inviolabilidade jurídica das faturas.
*   **Exportação White-Label:** Geração de relatórios PDF oficiais (Laudos) e planilhas Excel formatados dinamicamente com o Logotipo, CNPJ e Razão Social da administradora específica.
*   **Gestão de Equipes:** Criação e revogação de acessos para leituristas em tempo real.

### ⚙️ 3. Painel Super Admin (Torre de Controlo - MC Prestadora)
A espinha dorsal para a gestão do SaaS como um negócio escalável.
*   **Gestão Multi-Tenant:** Controlo centralizado para criar, suspender e gerir dezenas de Administradoras no mesmo banco de dados, com isolamento total e seguro de informações.
*   **Importação em Massa (Mass Onboarding):** Ferramenta web de parsing de texto/planilhas que permite processar centenas de apartamentos e construir a árvore estrutural de um prédio complexo no banco de dados em segundos.

---

## 🛠️ Stack Tecnológica & Arquitetura

*   **Front-end Mobile & Web:** Flutter (Dart). Código único otimizado para compilação nativa em iOS, Android e Web.
*   **Back-end (BaaS):** Firebase (Firestore Database, Cloud Storage, Authentication).
*   **Segurança:** Firestore Security Rules rígidas baseadas em `custom claims` / `cargos` validando permissões a cada transação.
*   **Inteligência Artificial:** Google Cloud Vision API (Machine Learning em nuvem para extração de texto em imagens).
*   **Persistência Local:** SQLite para gestão robusta de fila de sincronização assíncrona.

---

## 🚀 Como Instalar e Rodar o Projeto

Este guia cobre a configuração inicial do ambiente de desenvolvimento (Computador) e o processo de compilação para os dispositivos finais (Android e Apple).

### Pré-requisitos do Sistema
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (versão 3.x ou superior).
*   Git instalado.
*   [Android Studio](https://developer.android.com/studio) (para Android).
*   [Xcode](https://developer.apple.com/xcode/) (para iOS - *Requer ambiente macOS*).
*   CocoaPods (para gestão de dependências do iOS).

### 1. Configuração do Ambiente Local (Computador)
1. **Clonar o Repositório:**
   ```bash
   git clone [https://github.com/SuaEmpresa/leituras-mc.git](https://github.com/SuaEmpresa/leituras-mc.git)
   cd leituras-mc
   ```

2. **Instalar Dependências:**
   ```bash
   flutter pub get
   ```

3. **Configuração de Chaves de API e Firebase:**
   * Descarregue o arquivo `google-services.json` da consola do Firebase e coloque-o no diretório `android/app/`.
   * Descarregue o arquivo `GoogleService-Info.plist` da consola do Firebase e coloque-o no diretório `ios/Runner/`.
   * Configure a chave de acesso do Google Cloud Vision API dentro da classe `AppConfig` do projeto.

4. **Rodar no Emulador / Navegador Web (Modo Debug):**
   ```bash
   flutter run
   ```

### 2. Compilação para Android (APK / AppBundle)
Para gerar o ficheiro instalável para os telemóveis Android da equipa de campo:

*   **Para gerar um arquivo APK (Instalação direta via link/USB):**
    ```bash
    flutter build apk --release
    ```
    *O executável será gerado no diretório: `build/app/outputs/flutter-apk/app-release.apk`*

*   **Para gerar um AppBundle (Padrão exigido para a Google Play Store):**
    ```bash
    flutter build appbundle
    ```

### 3. Compilação para Apple / iOS
*(Atenção: A compilação para iOS exige obrigatoriamente a utilização de um computador com macOS).*

1. **Instalar dependências nativas do sistema iOS:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. **Abrir o projeto no Xcode para assinar o código (Code Signing):**
   ```bash
   open ios/Runner.xcworkspace
   ```
   *No Xcode, aceda à secção `Signing & Capabilities`, selecione a sua equipa (Team) do Apple Developer Program e confirme que o Bundle Identifier (`com.suaempresa.leiturasmc`) está correto.*

3. **Gerar o executável nativo (IPA):**
   ```bash
   flutter build ipa
   ```
   *O arquivo `.ipa` gerado pode ser distribuído para os leituristas através do Apple TestFlight ou publicado oficialmente na App Store Connect.*

---

**© 2026 MC Prestadora de Serviços.**
*A inovar e auditar o setor condominial através de engenharia de software de ponta.*
