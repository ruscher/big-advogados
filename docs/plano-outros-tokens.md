# Plano de Implementação — "Outros Tokens" (Drivers & Middleware)

## Visão Geral

Criar uma nova seção **"Drivers & Tokens"** no BigCertificados que permita ao usuário:

1. Ver quais drivers/middleware de token estão instalados no sistema
2. Instalar os pacotes necessários com um clique (via `pacman`/`yay`)
3. Verificar se os serviços fundamentais (`pcscd`, `ccid`) estão ativos
4. Agrupar tokens por **região/uso** com disclosure progressiva

A seção vive dentro da aba **Sistemas** como um novo `Adw.PreferencesGroup`, ou pode ser promovida a uma aba própria se a complexidade justificar.

---

## 1. Arquitetura

### 1.1 Novo módulo: `src/certificate/driver_database.py`

Centraliza os metadados de drivers/middleware de token.

```
@dataclass(frozen=True)
class TokenDriver:
    name: str               # Nome legível ("SafeNet eToken")
    packages: list[str]     # Pacotes Arch/AUR ["etoken"]
    source: str             # "official" | "aur"
    category: str           # "base" | "brazil" | "europe" | "asia" | "other"
    description: str        # Breve descrição
    icon: str               # Ícone simbólico GTK
    pkcs11_so: str          # Caminho PKCS#11 .so (para verificação)
    url: str                # Link de referência
    check_cmd: str          # Comando para verificar instalação (ex: "which tokenadmin")
```

### 1.2 Categorias de Drivers

| Categoria       | Chave      | Descrição                                              |
|-----------------|------------|--------------------------------------------------------|
| **Base**        | `base`     | Fundamentais para qualquer token (pcscd, ccid, opensc) |
| **Brasil**      | `brazil`   | Tokens comuns no Brasil (SafeNet, Serasa, RF, GD Burti)|
| **Europa**      | `europe`   | eID europeus (Portugal, Bélgica, Alemanha, etc.)       |
| **Ásia/Outros** | `asia`     | eID asiáticos e demais (Japão, Coreia, Índia, etc.)    |
| **Hardware**    | `hardware` | Yubikey, Nitrokey, chaves FIDO2                        |
| **Ferramentas** | `tools`    | Utilitários (pkcs11-tools, OpenWebStart, nss-tools)    |

---

## 2. Banco de Dados de Drivers

### 2.1 Pacotes Base (obrigatórios)

| Pacote          | Repo    | Função                                     |
|-----------------|---------|---------------------------------------------|
| `pcsclite`      | oficial | PC/SC Smart Card Daemon                     |
| `ccid`          | oficial | Driver CCID genérico (maioria dos leitores) |
| `opensc`        | oficial | OpenSC — ferramentas e PKCS#11 genérico     |
| `nss`           | oficial | NSS (para `modutil`/`certutil`)             |

### 2.2 Tokens Brasileiros

| Pacote             | Repo | Token/Fabricante                          | .so PKCS#11                       |
|--------------------|------|-------------------------------------------|-----------------------------------|
| `etoken`           | AUR  | SafeNet eToken 5100/5110 (Thales)         | `/usr/lib/libeToken.so`           |
| `libaet`           | AUR  | Token Serasa (G&D / Valid)                | `/usr/lib/libaetpkss.so.3`       |
| `safesignidentityclient` | AUR | GD Burti / StarSign (SafeSign)     | `/usr/lib/libaetpkss.so.3`       |
| `libiccbridge`     | AUR  | Token Receita Federal / Kryptus           | `/usr/lib/libiccbridge.so`        |
| `scmccid`          | AUR  | Leitor SCM Microsystems (GD Burti)        | (driver, não PKCS#11)             |
| `openwebstart-bin` | AUR  | OpenWebStart (JNLP para Certisign/Serpro) | —                                 |

### 2.3 eID Europeus (mais usados)

| Pacote           | Repo | País/Doc                    |
|------------------|------|-----------------------------|
| `pteid-mw`       | AUR  | Cartão de Cidadão — Portugal|
| `beid-mw`        | AUR  | eID — Bélgica               |
| `ausweisapp2`    | AUR  | eID — Alemanha              |
| `cie-middleware`  | AUR  | CNS/CIE — Itália            |
| `estonian-eid-mw`| AUR  | eID — Estônia               |

### 2.4 Hardware de Segurança

| Pacote                    | Repo    | Dispositivo               |
|---------------------------|---------|---------------------------|
| `yubikey-personalization` | oficial | Yubikey (personalização)  |
| `yubikey-manager`         | oficial | Yubikey Manager (GUI)     |
| `nitrokey-app`            | AUR     | Nitrokey (GUI)            |

### 2.5 Ferramentas Complementares

| Pacote          | Repo    | Função                                         |
|-----------------|---------|------------------------------------------------|
| `pkcs11-tools`  | oficial | CLI para inspecionar tokens PKCS#11            |
| `pcsc-tools`    | oficial | Ferramentas de diagnóstico PC/SC               |

---

## 3. Design UX/UI

### 3.1 Localização na Interface

A seção **Drivers & Tokens** será um `Adw.PreferencesGroup` na aba **Sistemas**, posicionado **entre** o grupo "PJeOffice Pro" e o grupo "Navegadores".

Alternativa: se a aba Sistemas ficar muito longa, promover para uma aba própria com ícone `drive-removable-media-symbolic`.

### 3.2 Wireframe da Seção

```
┌─────────────────────────────────────────────────────────┐
│  Drivers & Tokens — Middleware de Certificados          │
│  Instale os drivers necessários para seu token.         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ▼ Pacotes Base (Obrigatórios)                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ ✅ pcsclite      PC/SC Smart Card Daemon        │    │
│  │ ✅ ccid          Driver CCID genérico            │    │
│  │ ✅ opensc        OpenSC — PKCS#11 genérico       │    │
│  │ ⚠️  nss-tools    Ferramentas NSS (modutil)       │    │
│  │                                                  │    │
│  │ [Instalar Pendentes]                             │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ▶ Tokens Brasileiros (SafeNet, Serasa, GD Burti...)    │
│  ▶ eID Europeus (Portugal, Bélgica, Alemanha...)        │
│  ▶ Hardware de Segurança (Yubikey, Nitrokey)            │
│  ▶ Ferramentas Complementares                           │
│                                                         │
│  ───────────────────────────────────────────────        │
│  ⚙️  Status do Serviço pcscd                            │
│     ● Ativo                          [Reiniciar]       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.3 Componentes GTK4/libadwaita

| Elemento                  | Widget                     | Função                                       |
|---------------------------|----------------------------|----------------------------------------------|
| Grupo principal           | `Adw.PreferencesGroup`     | Container da seção                           |
| Categoria expandível      | `Adw.ExpanderRow`          | Agrupa drivers por região/tipo                |
| Driver individual         | `Adw.ActionRow`            | Nome + status + botão instalar                |
| Status (instalado/não)    | `Gtk.Image` + CSS class    | `emblem-ok-symbolic` (verde) ou `dialog-warning-symbolic` (amarelo) |
| Botão instalar            | `Gtk.Button`               | Ícone `folder-download-symbolic`              |
| Botão instalar todos      | `Adw.ActionRow` clicável   | "Instalar Pacotes Pendentes"                  |
| Status pcscd              | `Adw.ActionRow`            | Mostra se `pcscd.service` está ativo          |
| Toggle pcscd              | Botão no suffix            | Iniciar/reiniciar o serviço                   |

### 3.4 Fluxo de Instalação

```
Usuário clica "Instalar" em um driver
     │
     ▼
Verifica se é pacote oficial ou AUR
     │
     ├── Oficial → pkexec pacman -S --noconfirm <pacote>
     │
     └── AUR → Abre terminal com: yay -S <pacote>
                (requer interação do usuário para confirmações)
     │
     ▼
Mostra spinner durante instalação
     │
     ▼
Atualiza ícone de status (✅ ou ❌)
     │
     ▼
Se pacote base → recarrega status serviço pcscd
```

### 3.5 Fluxo "Instalar Pacotes Pendentes" (Base)

```
Usuário clica "Instalar Pendentes"
     │
     ▼
Filtra pacotes base não instalados
     │
     ▼
pkexec pacman -S --noconfirm pcsclite ccid opensc ...
     │
     ▼
Habilita e inicia pcscd:
  pkexec systemctl enable --now pcscd.service
     │
     ▼
Atualiza todos os status
```

### 3.6 Paleta de Status

| Estado                | Ícone                            | CSS class   |
|-----------------------|----------------------------------|-------------|
| Instalado             | `emblem-ok-symbolic`             | `success`   |
| Não instalado         | `software-update-available-symbolic` | `dim-label` |
| Instalando…           | `Gtk.Spinner`                    | —           |
| Erro na instalação    | `dialog-error-symbolic`          | `error`     |
| Serviço ativo         | `media-playback-start-symbolic`  | `success`   |
| Serviço inativo       | `media-playback-pause-symbolic`  | `warning`   |

---

## 4. Implementação — Etapas

### Etapa 1: `driver_database.py` (dados)

Criar o dataclass `TokenDriver` e a lista completa organizada por categoria. Incluir função utilitária:

```python
def check_installed(driver: TokenDriver) -> bool:
    """Verifica se os pacotes do driver estão instalados."""
    # Usa `pacman -Q <pacote>` para verificar
    ...

def get_missing_base_packages() -> list[TokenDriver]:
    """Retorna pacotes base que não estão instalados."""
    ...

def get_drivers_by_category() -> dict[str, list[TokenDriver]]:
    """Agrupa drivers por categoria."""
    ...
```

### Etapa 2: `driver_installer.py` (lógica de instalação)

```python
def install_official_packages(
    packages: list[str],
    on_progress: Callable[[str], None],
    on_done: Callable[[bool, str], None],
) -> None:
    """Instala pacotes do repositório oficial via pkexec pacman."""
    ...

def install_aur_package(
    package: str,
    on_done: Callable[[bool, str], None],
) -> None:
    """Instala pacote AUR (abre terminal interativo com yay)."""
    ...

def check_pcscd_status() -> tuple[bool, bool]:
    """Retorna (is_running, is_enabled)."""
    ...

def restart_pcscd(on_done: Callable[[bool, str], None]) -> None:
    """Reinicia o serviço pcscd via pkexec."""
    ...
```

### Etapa 3: `src/ui/drivers_view.py` (interface)

Nova view com a seção completa de drivers. Pode ser:

- **Opção A**: Um grupo dentro de `SystemsView` (se couber)
- **Opção B**: Uma view separada adicionada como sub-aba no `Adw.ViewStack` da aba Sistemas

A view terá:
1. Grupo "Pacotes Base" com status de cada pacote e botão "Instalar Pendentes"
2. `ExpanderRow` por categoria (Brasil, Europa, Ásia, Hardware, Ferramentas)
3. Dentro de cada expander: `ActionRow` por driver com status + botão Install
4. Grupo "Status do Serviço" para `pcscd`

```python
class DriversSection:
    """Builder para a seção de drivers dentro de SystemsView."""
    
    def build(self, parent_box: Gtk.Box) -> None:
        """Constrói e adiciona os grupos ao parent_box."""
        self._build_base_group(parent_box)
        self._build_category_groups(parent_box)
        self._build_service_status(parent_box)
    
    def _build_base_group(self, parent: Gtk.Box) -> None:
        """Grupo de pacotes base obrigatórios."""
        ...
    
    def _build_category_groups(self, parent: Gtk.Box) -> None:
        """Expanders por categoria de token."""
        ...
    
    def _build_service_status(self, parent: Gtk.Box) -> None:
        """Status e controle do serviço pcscd."""
        ...
    
    def refresh_status(self) -> None:
        """Atualiza o status de instalação de todos os drivers."""
        ...
```

### Etapa 4: Integração em `systems_view.py`

Inserir a `DriversSection` entre o grupo PJeOffice e o grupo Navegadores:

```python
# Em SystemsView.__init__:
content.append(pjeoffice_group)

# Nova seção de drivers
from src.ui.drivers_view import DriversSection
self._drivers = DriversSection()
self._drivers.build(content)

# Seção de navegadores (já existe)
self._build_browser_section(content)
```

### Etapa 5: Testes e Refinamento

1. Verificar detecção de pacotes em sistema limpo
2. Testar instalação de pacotes oficiais (pcsclite, ccid, opensc)
3. Testar instalação de pacotes AUR (etoken, libaet)
4. Verificar status do pcscd
5. Testar em diferentes resoluções de tela
6. Validar que os `ExpanderRow` começam colapsados (exceto "Pacotes Base" se houver pendentes)

---

## 5. Banco Completo de Drivers (para `driver_database.py`)

### 5.1 Base

```python
TokenDriver("PC/SC Daemon",     ["pcsclite"],       "official", "base", "Smart Card daemon para comunicação com tokens",         "system-run-symbolic",    "", "https://pcsclite.apdu.fr/", "systemctl is-active pcscd"),
TokenDriver("CCID Driver",      ["ccid"],            "official", "base", "Driver genérico para leitores CCID/USB",                "drive-removable-media-symbolic", "", "", ""),
TokenDriver("OpenSC",           ["opensc"],          "official", "base", "Ferramentas e módulo PKCS#11 genérico para smart cards", "dialog-password-symbolic", "/usr/lib/opensc-pkcs11.so", "https://github.com/OpenSC/OpenSC", "which opensc-tool"),
TokenDriver("NSS Tools",        ["nss"],             "official", "base", "modutil e certutil para configuração de navegadores",   "applications-internet-symbolic", "", "", "which modutil"),
```

### 5.2 Tokens Brasileiros

```python
TokenDriver("SafeNet eToken 5100/5110", ["etoken"],                "aur", "brazil", "Token USB mais usado no Brasil (Thales/SafeNet)",       "dialog-password-symbolic", "/usr/lib/libeToken.so",    "https://www.serpro.gov.br/links-fixos-superiores/pss-serpro/drivers_token", ""),
TokenDriver("Token Serasa (G&D/Valid)", ["libaet"],                "aur", "brazil", "Middleware AET para tokens Serasa Experian",              "dialog-password-symbolic", "/usr/lib/libaetpkss.so.3", "", ""),
TokenDriver("SafeSign (GD Burti/StarSign)", ["safesignidentityclient"], "aur", "brazil", "Gerenciador para tokens GD Burti e StarSign Crypto USB", "dialog-password-symbolic", "/usr/lib/libaetpkss.so.3", "https://safesign.gdamericadosul.com.br/", "which tokenadmin"),
TokenDriver("Token Receita Federal", ["libiccbridge"],             "aur", "brazil", "Middleware ICC Bridge para tokens da Receita Federal",    "dialog-password-symbolic", "/usr/lib/libiccbridge.so", "", ""),
TokenDriver("Leitor SCM (GD Burti)", ["scmccid"],                 "aur", "brazil", "Driver para leitores SCM Microsystems",                   "drive-removable-media-symbolic", "", "", ""),
TokenDriver("OpenWebStart",      ["openwebstart-bin"],             "aur", "brazil", "Executa JNLP — necessário para Certisign e Serpro",       "applications-internet-symbolic", "", "", "which javaws"),
```

### 5.3 eID Europeus

```python
TokenDriver("Cartão de Cidadão (Portugal)", ["pteid-mw"],          "aur", "europe", "Middleware do Cartão de Cidadão português", ...),
TokenDriver("eID Belga",               ["beid-mw"],               "aur", "europe", "Middleware do cartão de identidade belga", ...),
TokenDriver("eID Alemão (AusweisApp)",  ["ausweisapp2"],           "aur", "europe", "Aplicação para autenticação com eID alemão", ...),
TokenDriver("eID Francês",             ["french-eid-mw"],          "aur", "europe", "Middleware do cartão de identidade francês", ...),
TokenDriver("eID Italiano (CIE/CNS)",  ["cie-middleware"],         "aur", "europe", "Middleware Carta d'Identità Elettronica italiana", ...),
TokenDriver("eID Espanhol (DNIe)",     ["dnie-mw"],               "aur", "europe", "Middleware do DNI electrónico espanhol", ...),
TokenDriver("eID Austríaco",           ["aet-mw"],                "aur", "europe", "Middleware do cartão de identidade austríaco", ...),
TokenDriver("eID Suíço",              ["swiss-eid-mw"],           "aur", "europe", "Middleware do eID suíço", ...),
TokenDriver("eID Holandês",           ["dutch-eid-mw"],           "aur", "europe", "Middleware do eID holandês", ...),
TokenDriver("eID Sueco",              ["swedish-eid-mw"],         "aur", "europe", "Middleware do eID sueco", ...),
TokenDriver("eID Norueguês",          ["norwegian-eid-mw"],       "aur", "europe", "Middleware do eID norueguês", ...),
TokenDriver("eID Finlandês",          ["finnish-eid-mw"],         "aur", "europe", "Middleware do eID finlandês", ...),
TokenDriver("eID Dinamarquês",        ["danish-eid-mw"],          "aur", "europe", "Middleware do eID dinamarquês", ...),
TokenDriver("eID Estoniano",          ["estonian-eid-mw"],        "aur", "europe", "Middleware do eID estoniano", ...),
TokenDriver("eID Polonês",            ["polish-eid-mw"],          "aur", "europe", "Middleware do eID polonês", ...),
TokenDriver("eID Tcheco",             ["czech-eid-mw"],           "aur", "europe", "Middleware do eID tcheco", ...),
TokenDriver("eID Romeno",             ["romanian-eid-mw"],        "aur", "europe", "Middleware do eID romeno", ...),
TokenDriver("eID Búlgaro",            ["bulgarian-eid-mw"],       "aur", "europe", "Middleware do eID búlgaro", ...),
TokenDriver("eID Croata",             ["croatian-eid-mw"],        "aur", "europe", "Middleware do eID croata", ...),
TokenDriver("eID Esloveno",           ["slovenian-eid-mw"],       "aur", "europe", "Middleware do eID esloveno", ...),
TokenDriver("eID Grego",              ["greek-eid-mw"],           "aur", "europe", "Middleware do eID grego", ...),
TokenDriver("eID Cipriota",           ["cypriot-eid-mw"],         "aur", "europe", "Middleware do eID cipriota", ...),
TokenDriver("eID Maltês",             ["maltese-eid-mw"],         "aur", "europe", "Middleware do eID maltês", ...),
TokenDriver("eID Letão",              ["latvian-eid-mw"],         "aur", "europe", "Middleware do eID letão", ...),
TokenDriver("eID Lituano",            ["lithuanian-eid-mw"],      "aur", "europe", "Middleware do eID lituano", ...),
TokenDriver("eID Sérvio",             ["serbian-eid-mw"],         "aur", "europe", "Middleware do eID sérvio", ...),
TokenDriver("eID Montenegrino",       ["montenegrin-eid-mw"],     "aur", "europe", "Middleware do eID montenegrino", ...),
TokenDriver("eID Macedônio",          ["macedonian-eid-mw"],      "aur", "europe", "Middleware do eID macedônio", ...),
TokenDriver("eID Albanês",            ["albanian-eid-mw"],        "aur", "europe", "Middleware do eID albanês", ...),
TokenDriver("eID Kosovar",            ["kosovar-eid-mw"],         "aur", "europe", "Middleware do eID kosovar", ...),
TokenDriver("eID Moldavo",            ["moldovan-eid-mw"],        "aur", "europe", "Middleware do eID moldavo", ...),
```

### 5.4 eID Leste Europeu / Ásia Central

```python
TokenDriver("eID Russo",              ["russian-eid-mw"],         "aur", "asia", ...),
TokenDriver("eID Ucraniano",          ["ukrainian-eid-mw"],       "aur", "asia", ...),
TokenDriver("eID Bielorrusso",        ["belarusian-eid-mw"],      "aur", "asia", ...),
TokenDriver("eID Georgiano",          ["georgian-eid-mw"],        "aur", "asia", ...),
TokenDriver("eID Armênio",            ["armenian-eid-mw"],        "aur", "asia", ...),
TokenDriver("eID Azerbaijano",        ["azerbaijani-eid-mw"],     "aur", "asia", ...),
TokenDriver("eID Cazaque",            ["kazakh-eid-mw"],          "aur", "asia", ...),
TokenDriver("eID Uzbeque",            ["uzbek-eid-mw"],           "aur", "asia", ...),
TokenDriver("eID Turcomeno",          ["turkmen-eid-mw"],         "aur", "asia", ...),
TokenDriver("eID Tadjique",           ["tajik-eid-mw"],           "aur", "asia", ...),
TokenDriver("eID Quirguiz",           ["kyrgyz-eid-mw"],          "aur", "asia", ...),
```

### 5.5 eID Ásia / Pacífico

```python
TokenDriver("eID Chinês",             ["chinese-eid-mw"],         "aur", "asia", ...),
TokenDriver("eID Japonês",            ["japanese-eid-mw"],        "aur", "asia", ...),
TokenDriver("eID Coreano",            ["korean-eid-mw"],          "aur", "asia", ...),
TokenDriver("eID Vietnamita",         ["vietnamese-eid-mw"],      "aur", "asia", ...),
TokenDriver("eID Tailandês",          ["thai-eid-mw"],            "aur", "asia", ...),
TokenDriver("eID Malaio",             ["malaysian-eid-mw"],       "aur", "asia", ...),
TokenDriver("eID Indonésio",          ["indonesian-eid-mw"],      "aur", "asia", ...),
TokenDriver("eID Filipino",           ["filipino-eid-mw"],        "aur", "asia", ...),
TokenDriver("eID Indiano",            ["indian-eid-mw"],          "aur", "asia", ...),
TokenDriver("eID Paquistanês",        ["pakistani-eid-mw"],       "aur", "asia", ...),
TokenDriver("eID Mongol",             ["mongolian-eid-mw"],       "aur", "asia", ...),
```

### 5.6 Hardware de Segurança

```python
TokenDriver("YubiKey (Personalização)",  ["yubikey-personalization"], "official", "hardware", "Personalização de chaves Yubikey", ...),
TokenDriver("YubiKey Manager",           ["yubikey-manager"],        "official", "hardware", "Gerenciador GUI para Yubikey", ...),
TokenDriver("Nitrokey",                  ["nitrokey-app"],           "aur",      "hardware", "Gerenciador GUI para Nitrokey", ...),
```

### 5.7 Ferramentas

```python
TokenDriver("PKCS#11 Tools",      ["pkcs11-tools"], "official", "tools", "CLI p/ inspecionar tokens PKCS#11", ...),
TokenDriver("PC/SC Tools",        ["pcsc-tools"],   "official", "tools", "Ferramentas de diagnóstico PC/SC", ...),
```

---

## 6. Referências

### Threads do fórum BigLinux
- [Lista de instalação de tokens](https://forum.biglinux.com.br/d/4829)
- [SafeNet 5100](https://forum.biglinux.com.br/d/2629)
- [GD Burti](https://forum.biglinux.com.br/d/1908)
- [Usando token no BigLinux](https://forum.biglinux.com.br/d/72)

### Drivers oficiais
- [SERPRO — Drivers de Tokens](https://www.serpro.gov.br/links-fixos-superiores/pss-serpro/drivers_token)
- [SafeSign (GD América do Sul)](https://safesign.gdamericadosul.com.br/)
- [CCD SERPRO — Downloads](https://certificados.serpro.gov.br/arserpro/pages/information/drivers_token_download.jsf)

### Tokens SERPRO homologados
- **DX-Token** — DinKey (Taglio)
- **eToken PRO** — SafeNet/Thales
- **eToken 5100/5110** — SafeNet/Thales
- **StarSign Crypto USB Token S** — G&D Burti (novo modelo)
- **StarSign Crypto USB** — G&D Burti (modelo antigo)
- **WatchData** — Watchdata/ProxKey

### Notas de compatibilidade

| Token | Pacote AUR | .so PKCS#11 | Observações |
|-------|-----------|-------------|-------------|
| SafeNet 5100/5110 | `etoken` | `libeToken.so` | Instalar `etoken` do AUR, **não** o .deb do Serpro |
| GD Burti/StarSign | `safesignidentityclient` | `libaetpkss.so.3` | Se `tokenadmin` não abre: instalar `scmccid` + atualizar sistema |
| DX-Token (Taglio) | `opensc` | `opensc-pkcs11.so` | Funciona com driver genérico OpenSC |
| WatchData | Requer .deb manual | `libwdpksc.so` | Sem pacote AUR atualmente; possível usar OpenSC |

---

## 7. Priorização

| Prioridade | Item | Justificativa |
|------------|------|---------------|
| P0 | Pacotes base (pcsclite, ccid, opensc) | Obrigatório para qualquer token |
| P0 | Status pcscd | Diagnóstico fundamental |
| P1 | Tokens brasileiros | Público-alvo principal |
| P1 | SafeSign / GD Burti | Token mais problemático (wxgtk compat) |
| P2 | Hardware (Yubikey, Nitrokey) | Útil para devs e entusiastas |
| P2 | Ferramentas (pkcs11-tools) | Debug de problemas |
| P3 | eID europeus / asiáticos | Mercado secundário, mas amplia alcance |

---

## 8. Diagrama UX

```
┌─────────────────────────────────────────────────────────┐
│  ABA: Sistemas                                          │
│                                                         │
│  ┌─ Sistemas Judiciais Eletrônicos ─────────────────┐   │
│  │  ▶ Tribunais Superiores                          │   │
│  │  ▶ Bahia                                         │   │
│  │  ▶ São Paulo                                     │   │
│  │  ...                                             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─ PJeOffice Pro — Assinador Digital ──────────────┐   │
│  │  ✅ PJeOffice Pro — Instalado (v2.1.0)           │   │
│  │  ...                                             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─ Drivers & Tokens ──────────────────────────────  ┐  │
│  │                                                    │  │
│  │  ▼ Pacotes Base (Obrigatórios)                     │  │
│  │    ✅ pcsclite    PC/SC Smart Card Daemon           │  │
│  │    ✅ ccid        Driver CCID genérico              │  │
│  │    ✅ opensc      OpenSC — PKCS#11                  │  │
│  │    ⚠️  nss-tools  [Instalar]                        │  │
│  │                                                    │  │
│  │  ▶ Tokens Brasileiros (SafeNet, Serasa, GD...)     │  │
│  │  ▶ eID Europeus (30 países)                        │  │
│  │  ▶ eID Ásia & Outros (15 países)                   │  │
│  │  ▶ Hardware de Segurança (Yubikey, Nitrokey)       │  │
│  │  ▶ Ferramentas Complementares                      │  │
│  │                                                    │  │
│  │  ⚙️ Serviço pcscd: ● Ativo   [Reiniciar]          │  │
│  │                                                    │  │
│  └────────────────────────────────────────────────── ┘  │
│                                                         │
│  ┌─ Navegadores — Configuração para PJe ────────────┐   │
│  │  ✅ Firefox                                       │   │
│  │  ✅ Google Chrome                                 │   │
│  │  ✅ Brave                                         │   │
│  │  ...                                             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 9. Arquivo de Saída

Estrutura de arquivos a serem criados / modificados:

```
src/
├── certificate/
│   └── driver_database.py    ← NOVO (banco de dados de drivers)
├── ui/
│   └── drivers_view.py       ← NOVO (construtor da seção Drivers & Tokens)
│   └── systems_view.py       ← MODIFICADO (integra DriversSection)
```

---

## 10. Considerações Técnicas

### 10.1 Detecção de pacotes instalados

```python
def is_package_installed(pkg: str) -> bool:
    result = subprocess.run(
        ["pacman", "-Q", pkg],
        capture_output=True, timeout=5,
    )
    return result.returncode == 0
```

### 10.2 Instalação de pacotes oficiais

```python
def install_official(packages: list[str]) -> tuple[bool, str]:
    result = subprocess.run(
        ["pkexec", "pacman", "-S", "--noconfirm", "--needed"] + packages,
        capture_output=True, text=True, timeout=120,
    )
    return result.returncode == 0, result.stderr or result.stdout
```

### 10.3 Instalação AUR (requer interação)

Para pacotes AUR, não é possível instalar silenciosamente. A abordagem:

```python
def install_aur(package: str) -> None:
    helper = shutil.which("yay") or shutil.which("paru")
    if helper:
        # Abre terminal externo com o comando
        subprocess.Popen([
            "xdg-terminal-exec", helper, "-S", package,
        ])
```

### 10.4 Status do pcscd

```python
def get_pcscd_status() -> dict:
    result = subprocess.run(
        ["systemctl", "is-active", "pcscd.service"],
        capture_output=True, text=True, timeout=5,
    )
    is_active = result.stdout.strip() == "active"
    
    result2 = subprocess.run(
        ["systemctl", "is-enabled", "pcscd.service"],
        capture_output=True, text=True, timeout=5,
    )
    is_enabled = result2.stdout.strip() == "enabled"
    
    return {"active": is_active, "enabled": is_enabled}
```

### 10.5 Thread safety

Todas as operações de instalação e verificação rodam em threads separadas usando o padrão existente do projeto:

```python
def _start_install(self, driver: TokenDriver) -> None:
    threading.Thread(
        target=self._install_thread,
        args=(driver,),
        daemon=True,
    ).start()

def _install_thread(self, driver: TokenDriver) -> None:
    ok, msg = install_package(driver)
    GLib.idle_add(self._on_install_done, driver, ok, msg)
```
