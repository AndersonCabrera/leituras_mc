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

O sistema é dividido em três verticais operacionais (RBAC - Role-Based Access Control):

### 📱 1. Aplicativo Mobile (Operação de Campo - Leituristas)
Desenhado para velocidade, confiabilidade em áreas sem internet e coleta de provas rigorosas.
*   **Arquitetura Offline-First (SQLite):** O aplicativo funciona 100% sem internet (ideal para subsolos e garagens). As leituras são guardadas numa "Caixa de Saída" local e sincronizadas com a nuvem de forma assíncrona assim que a conexão é restabelecida.
*   **Leitura Assistida por Inteligência Artificial (OCR):** Integração com API do Google Cloud Vision para ler o medidor através da câmera do telemóvel, extraindo os números automaticamente e evitando erros de digitação humana.
*   **Motor Anti-Fraude e Validação de Limites:** Cálculo automático do consumo em tempo real baseado no mês anterior. Se o consumo exceder um limite configurado (ex: > 1m³), o sistema trava e **obriga a captura de uma evidência fotográfica otimizada** (reduzida e compactada).
*   **Gestão Dinâmica de Roteiros:** O utilizador apenas tem acesso e visualiza os condomínios que lhe foram previamente atribuídos pela gestão.
*   **Acessibilidade e UX:** Suporte global nativo a Modo Claro/Modo Escuro (*Dark Mode*).

### 💻 2. Painel Administrativo (Empresas / Administradoras)
O centro de controlo para auditar leituras e faturar clientes finais com confiança.
*   **Auditoria Visual:** Painel para validação cruzada entre o número digitado e a fotografia capturada no ato da leitura.
*   **Trava Jurídica (Fechamento de Lote):** Sistema de bloqueio de período. Uma vez que o mês é "fechado" pela administradora, o Firebase Security Rules bloqueia a nível de servidor qualquer alteração de dados, garantindo inviolabilidade jurídica das faturas.
*   **Exportação White-Label:** Geração de relatórios PDF (Laudos) e Excel formatados com o Logotipo e CNPJ da administradora, agregando valor à marca do cliente perante os condomínios.

### ⚙️ 3. Painel Super Admin (Torre de Controlo - MC Prestadora)
A espinha dorsal para gestão do SaaS.
*   **Gestão Multi-Tenant:** Controlo centralizado para criar, suspender e gerir dezenas de Administradoras no mesmo banco de dados, com isolamento total de dados.
*   **Importação em Massa (Mass Onboarding):** Ferramenta web de parsing de texto/Excel que permite processar centenas de apartamentos e construir a arquitetura de um prédio no banco de dados em segundos.

---

## 🛠️ Stack Tecnológica & Arquitetura

*   **Front-end Mobile & Web:** Flutter (Dart). Código único compilado para iOS, Android e Web.
*   **Back-end (BaaS):** Firebase (Firestore, Storage, Authentication).
*   **Segurança:** Firestore Security Rules rígidas baseadas em `custom claims` / `cargos` (RBAC).
*   **Inteligência Artificial:** Google Cloud Vision API (Machine Learning para reconhecimento de texto em imagens).
*   **Persistência Local:** SQLite / SharedPreferences para fila de sincronização assíncrona.

---

## 🚀 Como Instalar e Rodar o Projeto

Este guia cobre a configuração do ambiente de desenvolvimento (PC) e a compilação para os dispositivos finais.

### Pré-requisitos
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (versão 3.x ou superior).
*   Git instalado.
*   [Android Studio](https://developer.android.com/studio) (para Android).
*   [Xcode](https://developer.apple.com/xcode/) (para iOS - *Requer macOS*).
*   CocoaPods (para gestão de dependências do iOS).

### 1. Configuração do Ambiente Local (PC)
1. **Clonar o Repositório:**
   
```bash
   git clone [https://github.com/SuaEmpresa/leituras-mc.git](https://github.com/SuaEmpresa/leituras-mc.git)
   cd leituras-mc
   

    Instalar Dependências:

Bash

   flutter pub get
   

    Chaves de API e Firebase:

        Certifique-se de colocar o arquivo google-services.json em android/app/.

        Certifique-se de colocar o arquivo GoogleService-Info.plist em ios/Runner/.

        Configure a sua chave do Cloud Vision API na classe de configuração (ex: AppConfig.cloudVisionApiKey).

    Rodar no Emulador / Web (Modo Debug):

Bash

   flutter run
   

2. Compilação para Android (APK / AppBundle)

Para gerar o ficheiro instalável para os telemóveis Android dos leituristas:

    Para gerar um APK (Instalação direta via USB/Download):

Bash

    flutter build apk --release
    

*O arquivo será gerado em: `build/app/outputs/flutter-apk/app-release.apk`*

    Para gerar um AppBundle (Para a Google Play Store):

Bash

    flutter build appbundle
    

3. Compilação para Apple / iOS

(Nota: É obrigatório o uso de um computador macOS para este passo).

    Instalar dependências nativas do iOS:

Bash

   cd ios
   pod install
   cd ..
   

    Abrir o projeto no Xcode para assinar (Code Signing):

Bash

   open ios/Runner.xcworkspace
   

No Xcode, vá a Signing & Capabilities, selecione a equipa (Team) de desenvolvimento da Apple e garanta que o Bundle Identifier está correto.
3. Gerar o executável (IPA):
Bash

   flutter build ipa
   

O arquivo .ipa gerado pode ser distribuído via Apple TestFlight ou publicado na App Store Connect.

© 2026 MC Prestadora de Serviços.
A inovar o setor condominial através de código.
