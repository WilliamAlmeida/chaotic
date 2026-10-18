# Exportar o Ecos de Aetheris (Android, Windows, Linux e Web)

O arquivo `export_presets.cfg` já traz quatro presets prontos: **Android**, **Windows Desktop**, **Linux** e **Web**. Todos incluem `*.json` nos filtros (sem isso as cartas não entram no executável) e deixam de fora as pastas `ferramentas/` e `capturas/`.

O projeto usa o renderizador **Compatibility (OpenGL 3 / GLES 3)**, que roda em celular e no navegador. A orientação está fixa em **paisagem** (`display/window/handheld/orientation = Sensor Landscape`), e o toque está configurado para gerar cliques de mouse (as cartas da mão respondem ao dedo) sem o contrário (o mouse não vira toque no desktop).

## 1. Instalar os templates de exportação

1. Abra o projeto no **Godot 4.3** (a mesma versão exata do editor: os templates são por versão).
2. **Editor → Gerenciar Templates de Exportação…** → **Baixar e Instalar**.
   Sem internet no editor, baixe `Godot_v4.3-stable_export_templates.tpz` em <https://godotengine.org/download> e use **Instalar do arquivo**.
3. Em **Projeto → Exportar…** os quatro presets aparecem. Um aviso vermelho embaixo da lista diz o que ainda falta (template ou SDK).

A pasta `exportado/` (caminho padrão dos presets) pode ser criada à mão; o Godot não cria pastas sozinho.

## 2. Android (APK)

### Ferramentas (uma vez só)

1. Instale o **Android Studio** (ou só o *command line tools*) e, pelo **SDK Manager**, marque: *Android SDK Platform 34*, *Build-Tools 34*, *Platform-Tools* e *Command-line Tools*.
2. Instale o **OpenJDK 17** (o Android Studio já traz um em `jbr/`).
3. No Godot: **Editor → Configurações do Editor → Exportar → Android** e aponte:
   - **Android SDK Path**: a pasta do SDK (ex.: `C:\Users\voce\AppData\Local\Android\Sdk` ou `~/Android/Sdk`);
   - **Java SDK Path**: a pasta do JDK 17.

### Keystore de depuração

Para testar no próprio celular basta uma *keystore* de debug. Gere uma vez:

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
```

e informe o caminho dela em **Configurações do Editor → Exportar → Android → Debug Keystore** (usuário `androiddebugkey`, senha `android`). Se você já tem o Android Studio, ele cria a mesma keystore em `~/.android/debug.keystore`.

Para publicar na loja, gere outra keystore (de *release*), guarde-a com carinho e preencha **Keystore → Release** no preset.

### Exportar

1. **Projeto → Exportar… → Android → Exportar Projeto…**. Desmarque *Exportar com Depuração* só quando for a versão final.
2. O APK sai em `exportado/ecos_de_aetheris.apk` (pacote `com.williamalmeida.ecosdeaetheris`, nome "Ecos de Aetheris", versão 0.1, só `arm64-v8a`, modo imersivo e vibração liberada).
3. O preset usa o exportador rápido (sem Gradle). Para gerar **AAB** para a Play Store, marque *Use Gradle Build* e *Export Format: AAB*; na primeira vez, instale o *Android Build Template* em **Projeto → Instalar modelo de build do Android…**.

### Testar no celular

**Opção A: deploy remoto pelo editor (um clique)**

1. No celular, ative **Opções do desenvolvedor → Depuração USB** e ligue o cabo (ou `adb pair` por Wi‑Fi no Android 11+).
2. No Godot, o ícone de **Android** aparece ao lado do botão ▶ na barra de cima quando o preset Android é *runnable* e o ADB é encontrado. Clique nele: o Godot instala o APK e abre o jogo. Em **Depurar → Implantar com depuração remota** você vê o console e os erros do celular no editor.

**Opção B: instalar o APK à mão**

```bash
adb install -r exportado/ecos_de_aetheris.apk
```

ou copie o APK para o aparelho (cabo, Drive, Telegram…) e abra-o no gerenciador de arquivos. O Android pede para permitir "instalar apps desconhecidos" na primeira vez.

Os controles de toque aparecem sozinhos num aparelho com tela sensível (`Jogo.toque_ativo()`). Para forçar, mude `"toque"` para `"sim"` nas opções (ou em `user://salvo.json`).

## 3. Windows

1. **Projeto → Exportar… → Windows Desktop → Exportar Projeto…**.
2. Sai um único `EcosDeAetheris.exe` em `exportado/windows/` (PCK embutido, 64 bits). Não precisa instalar nada no outro PC; o Windows Defender pode pedir confirmação por o arquivo não ser assinado.
3. Para assinar/ícone próprio, preencha *Codesign* e *Application → Icon* no preset (ícone `.ico`). Exportar para Windows a partir do Linux/macOS exige o **rcedit** apontado em **Configurações do Editor → Exportar → Windows** só se quiser trocar o ícone e a versão do `.exe`.

A exportação para **Linux** é igual (`exportado/linux/ecos_de_aetheris.x86_64`).

## 4. Web (HTML5)

1. **Projeto → Exportar… → Web → Exportar Projeto…** gera `exportado/web/index.html` mais `.wasm`, `.pck` e `.js`.
2. O preset usa a variante **sem threads** (*Thread Support* desligado), que roda em qualquer host estático (GitHub Pages, itch.io, Netlify) sem exigir cabeçalhos COOP/COEP. O áudio pode atrasar alguns milissegundos nesse modo, o que é aceitável para o jogo.
3. O navegador não abre `index.html` direto do disco. Para testar localmente use o botão **Executar no navegador** (ícone ao lado do ▶) ou um servidor simples:

   ```bash
   cd exportado/web && python3 -m http.server 8080
   ```

   e abra <http://localhost:8080>.
4. No celular, abra o mesmo endereço (o PC e o celular na mesma rede: use o IP do PC). Em Android/iOS o jogo detecta a tela de toque (`web_android` / `web_ios`) e mostra o joystick e os botões. Toque na tela uma vez para o áudio destravar (regra dos navegadores).

## 5. Checklist antes de enviar para alguém

- [ ] `*.json` está nos filtros do preset (já vem).
- [ ] Versão (`version/code` e `version/name` no Android; `product_version` no Windows) atualizada.
- [ ] Testou a luta no aparelho de destino: joystick, GOLPE, ESQUIVA, PULO, CÂNTICO (setas) e as 3 cartas da mão.
- [ ] No celular, o jogo abre em paisagem e a HUD não corta (base 1920x1080 com `stretch/aspect = expand`).
