# Plano de Implementação — VidaaS Connect no BigCertificados

> **Versão:** 1.0  
> **Data:** 2026-03-31  
> **Status:** Em planejamento

---

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Arquitetura Atual do BigCertificados](#2-arquitetura-atual-do-bigcertificados)
3. [Como Funciona o VidaaS Connect](#3-como-funciona-o-vidaas-connect)
4. [Estratégia de Integração](#4-estratégia-de-integração)
5. [Módulo 1 — Detecção e Setup do pcscd + OpenSC](#5-módulo-1--detecção-e-setup-do-pcscd--opensc)
6. [Módulo 2 — VidaaS Cloud Manager (novo módulo)](#6-módulo-2--vidaas-cloud-manager-novo-módulo)
7. [Módulo 3 — Registro PKCS#11 nos Navegadores](#7-módulo-3--registro-pkcs11-nos-navegadores)
8. [Módulo 4 — Assinatura Digital de PDFs via VidaaS](#8-módulo-4--assinatura-digital-de-pdfs-via-vidaas)
9. [Módulo 5 — Interface Gráfica (UI)](#9-módulo-5--interface-gráfica-ui)
10. [Módulo 6 — Testes e Validação](#10-módulo-6--testes-e-validação)
11. [Dependências e Pacotes](#11-dependências-e-pacotes)
12. [Riscos e Mitigações](#12-riscos-e-mitigações)
13. [Cronograma de Fases](#13-cronograma-de-fases)
14. [Apêndice A — Referência Técnica VidaaS API](#apêndice-a--referência-técnica-vidaas-api)
15. [Apêndice B — Árvore de Arquivos Modificados/Criados](#apêndice-b--árvore-de-arquivos-modificadoscriados)

---

## 1. Visão Geral

O **VidaaS Connect** é um certificado digital **em nuvem** (tipo A1/A3 cloud) da **Valid Certificadora** que funciona como middleware entre o celular do usuário (onde o certificado fica armazenado) e o computador (onde é utilizado para assinar documentos e acessar sistemas).

### Objetivo

Implementar suporte **completo** ao VidaaS Connect no BigCertificados, incluindo:

- ✅ Detecção e configuração automática do ambiente (`pcscd`, `opensc`, `ccid`)
- ✅ Integração via PKCS#11 (token virtual local)
- ✅ Integração via API REST do VidaaS (assinatura remota)
- ✅ Registro automático em **todos os navegadores** (Firefox, Chrome, Brave, Chromium, Edge, Vivaldi)
- ✅ Assinatura de PDFs usando certificado VidaaS
- ✅ Interface gráfica integrada com fluxo guiado

### Dois Modos de Operação

| Modo | Mecanismo | Quando Usar |
|------|-----------|-------------|
| **PKCS#11 Local** | OpenSC emula token virtual via `opensc-pkcs11.so` | Quando o VidaaS Connect Desktop está instalado e rodando |
| **API REST Remota** | HTTPS direto para `api.vidaas.com.br` | Quando o usuário quer assinar sem instalar software local (assinatura apenas) |

---

## 2. Arquitetura Atual do BigCertificados

```
src/
├── application.py          # GtkApplication lifecycle (BigCertificadosApp)
├── window.py               # MainWindow — orquestra UI e A3Manager
├── main.py                 # Entry point
│
├── certificate/
│   ├── a1_manager.py       # Gerencia certificados A1 (PFX)
│   ├── a3_manager.py       # Gerencia tokens A3 via PKCS#11 (PyKCS11Lib)
│   ├── parser.py           # Parse de certificados X.509, OIDs ICP-Brasil
│   ├── pdf_signer.py       # Assina PDFs (A1 via endesive, A3 via _PKCS11HSM)
│   ├── stamp.py            # Gera carimbo visual da assinatura
│   └── token_database.py   # Base de tokens USB brasileiros (VID:PID → .so)
│
├── browser/
│   ├── browser_detect.py   # Detecta perfis Firefox/Chromium/Brave/Edge/Vivaldi
│   ├── brave_config.py     # Configuração específica do Brave
│   └── nss_config.py       # Registra módulos PKCS#11 via modutil/certutil
│
├── ui/
│   ├── a1_view.py          # Tela de certificados A1
│   ├── certificate_view.py # Exibe detalhes de certificados
│   ├── signer_view.py      # Tela de assinatura de PDFs (A1 e A3)
│   ├── token_detect_view.py # Tela de detecção de tokens USB
│   ├── systems_view.py     # Integração com sistemas (PJe, etc.)
│   ├── pin_dialog.py       # Diálogo de PIN do token
│   ├── lock_screen.py      # Tela de bloqueio
│   ├── password_settings.py # Configuração de senha
│   └── pjeoffice_installer.py # Instalação do PJe Office
│
└── utils/
    ├── udev_monitor.py     # Monitora eventos USB via udev
    ├── app_lock.py         # Lock de instância única
    ├── updater.py          # Verificação de atualizações
    └── xdg.py              # Diretórios XDG
```

### Pontos de Extensão Identificados

| Componente | Ponto de Extensão | O Que Precisa Mudar |
|------------|-------------------|---------------------|
| `A3Manager` | `load_module()` / `try_all_modules()` | Incluir `/usr/lib/opensc-pkcs11.so` como módulo VidaaS |
| `TokenDatabase` | `_TOKEN_LIST`, `_MODULE_TO_PACKAGE` | Adicionar entrada VidaaS Connect |
| `nss_config.py` | `register_pkcs11_module()` | Suportar registro do OpenSC para VidaaS |
| `pdf_signer.py` | `sign_pdf_a3()` | Suportar assinatura via API REST além de PKCS#11 |
| `signer_view.py` | `_on_cert_type_changed()` | Adicionar tipo "VidaaS Cloud" |
| `window.py` | `_do_scan()` | Detectar token virtual VidaaS (não apenas USB) |

---

## 3. Como Funciona o VidaaS Connect

### 3.1 Fluxo PKCS#11 (Token Virtual)

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  App VidaaS  │────▶│  VidaaS Connect  │────▶│  pcscd (daemon)  │
│  (celular)   │     │  Desktop/Daemon  │     │  + OpenSC        │
└──────────────┘     └──────────────────┘     └────────┬─────────┘
                                                       │
                                              opensc-pkcs11.so
                                                       │
                                              ┌────────▼─────────┐
                                              │  Navegadores /   │
                                              │  BigCertificados │
                                              └──────────────────┘
```

1. O certificado reside no celular (app VidaaS)
2. O VidaaS Connect Desktop cria um token virtual acessível via PC/SC
3. O daemon `pcscd` expõe esse token via interface PC/SC
4. O OpenSC traduz o acesso PC/SC para PKCS#11
5. Qualquer aplicação que use PKCS#11 (navegadores, BigCertificados) pode acessar o certificado

### 3.2 Fluxo API REST (Assinatura Remota)

```
┌──────────────────┐     HTTPS     ┌──────────────────┐
│  BigCertificados │──────────────▶│  api.vidaas.com.br│
│  (assinatura)    │◀──────────────│  (cloud HSM)     │
└──────────────────┘               └──────────────────┘
                                           │
                                   ┌───────▼────────┐
                                   │  App VidaaS    │
                                   │  (autorização) │
                                   └────────────────┘
```

1. BigCertificados envia hash do documento para API VidaaS
2. API envia push para app no celular pedindo autorização
3. Usuário autoriza no celular (biometria/PIN)
4. API retorna assinatura digital
5. BigCertificados incorpora assinatura no PDF

### 3.3 Caminhos Conhecidos do OpenSC no Arch Linux

```
/usr/lib/opensc-pkcs11.so              # Caminho padrão pacman
/usr/lib/pkcs11/opensc-pkcs11.so       # Alternativo
/usr/lib64/opensc-pkcs11.so            # 64-bit alternativo
/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so  # Debian-like
```

---

## 4. Estratégia de Integração

### 4.1 Princípio: Certificado VidaaS = A3 Cloud

O VidaaS é tratado internamente como um **subtipo de A3** — usa PKCS#11 igual a um token USB, mas:

- Não tem VID:PID USB (token virtual)
- Requer `pcscd` + `opensc` obrigatoriamente
- É detectado por enumeração de slots (não por udev)
- Pode exigir autorização remota (push no celular)

### 4.2 Novo Tipo de Certificado

```python
# Constantes em signer_view.py (existentes)
CERT_TYPE_A1 = "a1"
CERT_TYPE_A3 = "a3"

# Nova constante
CERT_TYPE_VIDAAS = "vidaas"
```

### 4.3 Diagrama de Classes (Novo)

```
                    ┌───────────────────┐
                    │    A3Manager      │  (existente, já reutilizado)
                    │  PKCS#11 genérico │
                    └───────┬───────────┘
                            │ usa
              ┌─────────────┼─────────────────┐
              │             │                  │
     ┌────────▼───┐  ┌─────▼──────┐  ┌───────▼──────────┐
     │ Token USB  │  │ VidaaS     │  │  VidaaSCloudAPI   │
     │ (hardware) │  │ PKCS#11    │  │  (REST, novo)     │
     │            │  │ (OpenSC)   │  │                   │
     └────────────┘  └────────────┘  └──────────────────┘
```

---

## 5. Módulo 1 — Detecção e Setup do pcscd + OpenSC

### 5.1 Novo arquivo: `src/utils/vidaas_deps.py`

Responsável por verificar e instalar dependências do VidaaS.

```python
"""VidaaS Connect dependency checker and installer."""

from __future__ import annotations

import logging
import shutil
import subprocess
from pathlib import Path
from typing import NamedTuple

log = logging.getLogger(__name__)


class DependencyStatus(NamedTuple):
    opensc_installed: bool
    pcscd_installed: bool
    ccid_installed: bool
    pcscd_running: bool
    opensc_module_path: str | None


OPENSC_SEARCH_PATHS = (
    "/usr/lib/opensc-pkcs11.so",
    "/usr/lib/pkcs11/opensc-pkcs11.so",
    "/usr/lib64/opensc-pkcs11.so",
    "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so",
)


def find_opensc_module() -> str | None:
    """Find the OpenSC PKCS#11 module on the system."""
    for path in OPENSC_SEARCH_PATHS:
        if Path(path).is_file():
            return path
    return None


def check_dependencies() -> DependencyStatus:
    """Check VidaaS-related system dependencies."""
    opensc_path = find_opensc_module()
    
    return DependencyStatus(
        opensc_installed=opensc_path is not None,
        pcscd_installed=shutil.which("pcscd") is not None,
        ccid_installed=Path("/usr/lib/pcsc/drivers").is_dir(),
        pcscd_running=_is_service_active("pcscd"),
        opensc_module_path=opensc_path,
    )


def _is_service_active(service: str) -> bool:
    """Check if a systemd service is active."""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", service],
            capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() == "active"
    except Exception:
        return False


def ensure_pcscd_running() -> bool:
    """Start and enable pcscd if not already running."""
    # ... implementação com pkexec para elevação
    pass


def get_missing_packages() -> list[str]:
    """Return list of packages that need to be installed."""
    missing = []
    status = check_dependencies()
    if not status.opensc_installed:
        missing.append("opensc")
    if not status.pcscd_installed:
        missing.append("pcsclite")
    if not status.ccid_installed:
        missing.append("ccid")
    return missing
```

### 5.2 Alterações em `token_database.py`

Adicionar entrada VidaaS na `_TOKEN_LIST`:

```python
# ── VidaaS Connect (Virtual Token / Cloud) ────────────────────────
TokenInfo(
    vendor="Valid Certificadora",
    model="VidaaS Connect",
    vid=0x0000, pid=0x0000,  # Token virtual, sem VID:PID USB
    pkcs11_module="opensc-pkcs11.so",
    search_paths=(
        "/usr/lib/opensc-pkcs11.so",
        "/usr/lib/pkcs11/opensc-pkcs11.so",
        "/usr/lib64/opensc-pkcs11.so",
    ),
    description="Certificado digital em nuvem VidaaS (Valid Certificadora)",
    is_reader=False,
),
```

### 5.3 Alterações em `_MODULE_TO_PACKAGE`

```python
"opensc-pkcs11.so": "opensc",  # Já existe, coberto
```

### 5.4 Detalhes de Implementação

| Tarefa | Arquivo | Função |
|--------|---------|--------|
| Checar se `opensc` está instalado | `vidaas_deps.py` | `check_dependencies()` |
| Checar se `pcscd` está rodando | `vidaas_deps.py` | `_is_service_active()` |
| Iniciar `pcscd` automaticamente | `vidaas_deps.py` | `ensure_pcscd_running()` |
| Listar pacotes faltantes | `vidaas_deps.py` | `get_missing_packages()` |
| Encontrar `opensc-pkcs11.so` | `vidaas_deps.py` | `find_opensc_module()` |

---

## 6. Módulo 2 — VidaaS Cloud Manager (novo módulo)

### 6.1 Novo arquivo: `src/certificate/vidaas_manager.py`

Manager para interação com certificados VidaaS, tanto via PKCS#11 quanto via API REST.

```python
"""Manager for VidaaS Connect cloud certificates."""

from __future__ import annotations

import logging
import threading
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path
from typing import Optional

log = logging.getLogger(__name__)


class VidaaSMode(Enum):
    PKCS11 = auto()   # Token virtual via OpenSC
    REST_API = auto()  # API remota direta


class VidaaSConnectionState(Enum):
    DISCONNECTED = auto()
    CHECKING_DEPS = auto()
    STARTING_PCSCD = auto()
    SCANNING_SLOTS = auto()
    WAITING_AUTH = auto()   # Aguardando autorização no celular
    CONNECTED = auto()
    ERROR = auto()


@dataclass
class VidaaSStatus:
    state: VidaaSConnectionState
    message: str = ""
    mode: VidaaSMode | None = None
    slot_label: str = ""


class VidaaSManager:
    """Manages VidaaS Connect certificate lifecycle."""

    def __init__(self, a3_manager: A3Manager) -> None:
        self._a3 = a3_manager
        self._state = VidaaSConnectionState.DISCONNECTED
        self._mode: VidaaSMode | None = None
        self._lock = threading.Lock()
        self._opensc_path: str | None = None

    @property
    def state(self) -> VidaaSConnectionState:
        return self._state

    def detect_vidaas_token(self) -> bool:
        """Attempt to detect VidaaS virtual token via PKCS#11."""
        ...

    def connect_pkcs11(self) -> VidaaSStatus:
        """Connect via PKCS#11 (OpenSC) mode."""
        ...

    def connect_api(self, credentials: dict) -> VidaaSStatus:
        """Connect via REST API mode."""
        ...

    def list_certificates(self) -> list[CertificateInfo]:
        """List certificates from VidaaS token."""
        ...

    def sign_hash(self, hash_bytes: bytes, algorithm: str) -> bytes:
        """Sign a hash using the VidaaS certificate."""
        ...

    def disconnect(self) -> None:
        """Disconnect from VidaaS."""
        ...
```

### 6.2 Detecção de Token Virtual VidaaS

O VidaaS não é detectado via USB. A detecção segue este fluxo:

```
1. Verificar dependências (opensc, pcscd, ccid)
2. Garantir que pcscd está rodando
3. Carregar opensc-pkcs11.so no A3Manager
4. Enumerar slots
5. Verificar se algum slot tem label contendo "VidaaS" ou "Valid"
6. Se encontrou → PKCS#11 mode disponível
```

### 6.3 Integração com A3Manager Existente

O `VidaaSManager` **reutiliza** o `A3Manager` para operações PKCS#11:

```python
def detect_vidaas_token(self) -> bool:
    """Detect a VidaaS virtual token in PKCS#11 slots."""
    from src.utils.vidaas_deps import find_opensc_module, check_dependencies

    status = check_dependencies()
    if not status.pcscd_running:
        return False

    opensc = find_opensc_module()
    if opensc is None:
        return False

    self._opensc_path = opensc
    if not self._a3.load_module(opensc):
        return False

    slots = self._a3.get_slots()
    for slot in slots:
        label_lower = slot.label.lower()
        if any(kw in label_lower for kw in ("vidaas", "valid", "cloud")):
            return True

    # Mesmo sem label VidaaS, se existem slots com OpenSC, podem ser VidaaS
    return len(slots) > 0
```

### 6.4 API REST — Endpoints Esperados

> **Nota:** A API REST do VidaaS não é documentada publicamente. A implementação
> abaixo é baseada no padrão de APIs de certificados em nuvem (CAdES/PAdES) e
> deverá ser ajustada quando houver acesso à documentação oficial.

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/auth/token` | POST | Autenticação OAuth2 / obtenção de token |
| `/certificates` | GET | Listar certificados disponíveis |
| `/certificates/{id}` | GET | Detalhes de um certificado |
| `/sign` | POST | Solicitar assinatura (envia hash) |
| `/sign/{transaction_id}/status` | GET | Verificar status da assinatura |
| `/sign/{transaction_id}/result` | GET | Obter resultado (assinatura) |

### 6.5 Novo arquivo: `src/certificate/vidaas_api.py`

```python
"""VidaaS Connect REST API client."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from enum import Enum, auto
from typing import Optional

log = logging.getLogger(__name__)


class VidaaSAuthMethod(Enum):
    OAUTH2 = auto()
    API_KEY = auto()


@dataclass
class VidaaSCredentials:
    client_id: str
    client_secret: str
    username: str
    # OTP / push auth handled by VidaaS backend


@dataclass
class VidaaSCertificate:
    cert_id: str
    subject_cn: str
    issuer_cn: str
    not_before: str
    not_after: str
    key_type: str
    cert_pem: str


class VidaaSSignatureStatus(Enum):
    PENDING = auto()       # Aguardando autorização no celular
    AUTHORIZED = auto()    # Autorizado, processando
    COMPLETED = auto()     # Assinatura pronta
    REJECTED = auto()      # Rejeitado pelo usuário
    EXPIRED = auto()       # Timeout da autorização
    ERROR = auto()


@dataclass
class VidaaSSignatureResult:
    status: VidaaSSignatureStatus
    transaction_id: str = ""
    signature_bytes: bytes = b""
    error_message: str = ""


class VidaaSAPIClient:
    """HTTP client for VidaaS Connect REST API.
    
    IMPORTANT: This is a scaffold. The actual API endpoints and 
    authentication flow must be confirmed with Valid Certificadora's
    official documentation or SDK.
    """

    BASE_URL = "https://api.vidaas.com.br"

    def __init__(self, credentials: VidaaSCredentials) -> None:
        self._credentials = credentials
        self._access_token: str | None = None

    def authenticate(self) -> bool:
        """Authenticate with VidaaS API using OAuth2."""
        ...

    def list_certificates(self) -> list[VidaaSCertificate]:
        """List certificates available in the cloud HSM."""
        ...

    def request_signature(
        self,
        cert_id: str,
        hash_bytes: bytes,
        hash_algorithm: str = "sha256",
    ) -> str:
        """Request a signature. Returns transaction_id.
        
        This triggers a push notification to the user's phone.
        """
        ...

    def check_signature_status(
        self, transaction_id: str,
    ) -> VidaaSSignatureResult:
        """Poll signature status until complete or timeout."""
        ...

    def get_signature(
        self, transaction_id: str,
    ) -> VidaaSSignatureResult:
        """Retrieve the completed signature bytes."""
        ...
```

---

## 7. Módulo 3 — Registro PKCS#11 nos Navegadores

### 7.1 Alterações em `nss_config.py`

Adicionar função específica para registrar VidaaS em todos os navegadores:

```python
def register_vidaas_in_all_browsers() -> dict[str, bool]:
    """Register OpenSC PKCS#11 module (VidaaS) in all browser profiles."""
    from src.utils.vidaas_deps import find_opensc_module

    opensc = find_opensc_module()
    if opensc is None:
        log.error("OpenSC module not found — cannot register VidaaS")
        return {}

    results: dict[str, bool] = {}
    profiles = find_all_profiles()
    seen_dbs: set[str] = set()

    for profile in profiles:
        db_key = str(profile.nss_db_path)
        if db_key in seen_dbs:
            results[f"{profile.browser} ({profile.name})"] = True
            continue
        seen_dbs.add(db_key)

        success = register_pkcs11_module(
            profile.nss_db_path,
            opensc,
            module_name="VidaaS_Connect",
        )
        results[f"{profile.browser} ({profile.name})"] = success

    return results
```

### 7.2 Suporte a Shared NSS DB

Navegadores Chromium-based usam `~/.pki/nssdb/` compartilhado:

```python
def register_vidaas_in_shared_nssdb() -> bool:
    """Register OpenSC in the shared NSS database used by Chromium browsers."""
    from src.utils.vidaas_deps import find_opensc_module

    shared_db = Path.home() / ".pki" / "nssdb"
    if not shared_db.is_dir():
        ensure_nss_db(shared_db)  # Já existe essa função

    opensc = find_opensc_module()
    if opensc is None:
        return False

    return register_pkcs11_module(
        shared_db, opensc, module_name="VidaaS_Connect",
    )
```

### 7.3 Navegadores Suportados

| Navegador | DB NSS | Método de Registro |
|-----------|--------|--------------------|
| Firefox | `~/.mozilla/firefox/<profile>/` | `modutil` por perfil |
| Google Chrome | `~/.pki/nssdb/` | `modutil` compartilhado |
| Chromium | `~/.pki/nssdb/` | `modutil` compartilhado |
| Brave | `~/.pki/nssdb/` | `modutil` compartilhado |
| Vivaldi | `~/.pki/nssdb/` | `modutil` compartilhado |
| Microsoft Edge | `~/.pki/nssdb/` | `modutil` compartilhado |

### 7.4 Verificação de Navegadores em Execução

Antes de registrar módulos, é prudente verificar se o navegador está fechado (NSS DB pode estar locked):

```python
def is_browser_running(browser_name: str) -> bool:
    """Check if a browser process is running."""
    process_names = {
        "Firefox": "firefox",
        "Google Chrome": "chrome",
        "Chromium": "chromium",
        "Brave": "brave",
        "Vivaldi": "vivaldi",
        "Microsoft Edge": "msedge",
    }
    proc_name = process_names.get(browser_name)
    if proc_name is None:
        return False
    try:
        result = subprocess.run(
            ["pgrep", "-x", proc_name],
            capture_output=True, timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False
```

---

## 8. Módulo 4 — Assinatura Digital de PDFs via VidaaS

### 8.1 Alterações em `pdf_signer.py`

#### Nova função: `sign_pdf_vidaas()`

```python
def sign_pdf_vidaas(
    pdf_path: str,
    vidaas_manager: VidaaSManager,
    cert_info: CertificateInfo,
    output_path: str,
    options: Optional[SignatureOptions] = None,
) -> SignatureResult:
    """Sign a PDF using VidaaS Connect certificate.

    Supports both PKCS#11 (local) and API REST (remote) modes.
    """
    if vidaas_manager.mode == VidaaSMode.PKCS11:
        # Reutiliza sign_pdf_a3() com o A3Manager já conectado
        cert_der = vidaas_manager.get_cert_der()
        return sign_pdf_a3(
            pdf_path, vidaas_manager._a3, cert_der, output_path, options,
        )
    elif vidaas_manager.mode == VidaaSMode.REST_API:
        return _sign_pdf_vidaas_api(
            pdf_path, vidaas_manager, cert_info, output_path, options,
        )
```

#### Assinatura via API REST

```python
def _sign_pdf_vidaas_api(
    pdf_path: str,
    vidaas_manager: VidaaSManager,
    cert_info: CertificateInfo,
    output_path: str,
    options: Optional[SignatureOptions] = None,
) -> SignatureResult:
    """Sign PDF via VidaaS REST API (remote signing)."""
    import hashlib

    pdf_bytes = Path(pdf_path).read_bytes()
    
    # Calcular hash do PDF
    pdf_hash = hashlib.sha256(pdf_bytes).digest()
    
    # Solicitar assinatura remota (push para celular)
    transaction_id = vidaas_manager.api_client.request_signature(
        cert_id=cert_info.serial_number,
        hash_bytes=pdf_hash,
        hash_algorithm="sha256",
    )
    
    # Poll até autorização (com timeout)
    # ... implementação com callback para UI atualizar status
    
    # Incorporar assinatura no PDF
    # ... usar endesive para embutir a assinatura CMS
```

### 8.2 Classe HSM Adapter para VidaaS API

```python
class _VidaaSRemoteHSM:
    """HSM adapter for endesive — signs via VidaaS REST API."""

    def __init__(
        self,
        api_client: VidaaSAPIClient,
        cert_id: str,
        cert_der: bytes,
    ) -> None:
        self._api = api_client
        self._cert_id = cert_id
        self._cert_der = cert_der

    def certificate(self) -> tuple:
        return (self._cert_id, self._cert_der)

    def sign(self, keyid: object, data: bytes, hashalgo: str) -> bytes:
        """Sign data via VidaaS API (triggers push notification)."""
        import hashlib

        hash_func = getattr(hashlib, hashalgo, hashlib.sha256)
        data_hash = hash_func(data).digest()

        tx_id = self._api.request_signature(
            self._cert_id, data_hash, hashalgo,
        )

        # Poll with timeout
        import time
        for _ in range(120):  # 2 minutos de timeout
            result = self._api.check_signature_status(tx_id)
            if result.status == VidaaSSignatureStatus.COMPLETED:
                return result.signature_bytes
            if result.status in (
                VidaaSSignatureStatus.REJECTED,
                VidaaSSignatureStatus.EXPIRED,
                VidaaSSignatureStatus.ERROR,
            ):
                raise RuntimeError(
                    f"VidaaS signing failed: {result.error_message}"
                )
            time.sleep(1)

        raise TimeoutError("VidaaS signature authorization timeout")
```

### 8.3 Integração com `signer_view.py`

Adicionar VidaaS como tipo de certificado na UI de assinatura:

```python
CERT_TYPE_A1 = "a1"
CERT_TYPE_A3 = "a3"
CERT_TYPE_VIDAAS = "vidaas"  # NOVO
```

---

## 9. Módulo 5 — Interface Gráfica (UI)

### 9.1 Novo arquivo: `src/ui/vidaas_view.py`

Tela dedicada para VidaaS Connect com fluxo guiado:

```
┌─────────────────────────────────────────────────────┐
│  VidaaS Connect                              [?]    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │  Status do Sistema                          │    │
│  │                                             │    │
│  │  ✅ OpenSC instalado                        │    │
│  │  ✅ pcscd rodando                           │    │
│  │  ✅ ccid instalado                          │    │
│  │  ⚠️  VidaaS Connect Desktop não detectado   │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │  Modo de Conexão                            │    │
│  │                                             │    │
│  │  ○ PKCS#11 (token virtual local)            │    │
│  │  ○ API REST (assinatura remota)             │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
│  ┌─ Certificados Encontrados ──────────────────┐    │
│  │  🔒 João da Silva - e-CPF A3               │    │
│  │     Válido até: 15/06/2027                  │    │
│  │     Emissor: AC Valid                       │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
│  [ Configurar Navegadores ]  [ Desconectar ]        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 9.2 Componentes GTK4/Adwaita

| Widget | Uso |
|--------|-----|
| `AdwStatusPage` | Estado quando VidaaS não detectado |
| `AdwPreferencesGroup` | Grupos de status e configuração |
| `AdwActionRow` | Linhas de status com checkmarks |
| `AdwSwitchRow` | Toggle modo PKCS#11 / API |
| `AdwExpanderRow` | Certificados detectados (expansível) |
| `Gtk.Button` | Ações: configurar, conectar, desconectar |
| `AdwBanner` | Alertas (navegador rodando, deps faltando) |

### 9.3 Fluxo de Setup Guiado

```
┌──────────────┐
│ Verificar    │──▶ Deps OK? ──▶ Sim ──▶ ┌──────────────┐
│ Dependências │                          │ Detectar     │
└──────────────┘       │                  │ Token VidaaS │
                       ▼ Não              └──────┬───────┘
                ┌──────────────┐                 │
                │ Instalar     │         Token encontrado?
                │ Pacotes      │                 │
                │ (pacman)     │           Sim ──┤── Não
                └──────────────┘                 │       │
                                          ┌──────▼───┐   │
                                          │ Listar   │   ▼
                                          │ Certs    │ Mostrar
                                          └──────┬───┘ instrução
                                                 │
                                          ┌──────▼──────────┐
                                          │ Configurar      │
                                          │ Navegadores     │
                                          │ (auto)          │
                                          └──────┬──────────┘
                                                 │
                                          ┌──────▼──────────┐
                                          │ Pronto para     │
                                          │ usar!           │
                                          └─────────────────┘
```

### 9.4 Integração na MainWindow

Adicionar aba/seção VidaaS no `AdwNavigationView` ou `AdwViewStack`:

```python
# Em window.py, método _build_ui():

# Adicionar VidaaS como nova página no ViewStack
self._vidaas_view = VidaaSView(self._a3_manager)
self._view_stack.add_titled(
    self._vidaas_view, "vidaas", "VidaaS Connect",
)
```

### 9.5 Diálogo de Autorização Remota

Quando usar modo API REST, mostrar diálogo de espera:

```
┌─────────────────────────────────────────────┐
│                                             │
│         📱 Aguardando Autorização           │
│                                             │
│   Abra o aplicativo VidaaS no seu          │
│   celular e autorize a assinatura.          │
│                                             │
│   ┌─────────────────────────────────┐       │
│   │  ████████████████░░░░░░░░░░░░░  │       │
│   │  Tempo restante: 1:42           │       │
│   └─────────────────────────────────┘       │
│                                             │
│              [ Cancelar ]                   │
│                                             │
└─────────────────────────────────────────────┘
```

Widget: `AdwDialog` com `Gtk.ProgressBar` e `GLib.timeout_add()` para countdown.

### 9.6 Tela de Instalação de Dependências

```
┌─────────────────────────────────────────────┐
│  Configurar VidaaS Connect                  │
├─────────────────────────────────────────────┤
│                                             │
│  Pacotes necessários:                       │
│                                             │
│  ❌ opensc — Biblioteca PKCS#11            │
│  ❌ pcsclite — Daemon PC/SC               │
│  ✅ ccid — Drivers de leitores             │
│                                             │
│  Comando para instalar:                     │
│  ┌─────────────────────────────────────┐    │
│  │ sudo pacman -S opensc pcsclite     │ 📋 │
│  └─────────────────────────────────────┘    │
│                                             │
│  [ Instalar Automaticamente ]               │
│  [ Verificar Novamente ]                    │
│                                             │
└─────────────────────────────────────────────┘
```

A instalação automática usa `pkexec` para elevação:

```python
def install_packages(packages: list[str]) -> bool:
    """Install packages via pacman with privilege elevation."""
    cmd = ["pkexec", "pacman", "-S", "--noconfirm", "--needed"] + packages
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return result.returncode == 0
```

---

## 10. Módulo 6 — Testes e Validação

### 10.1 Testes Unitários

| Teste | Arquivo | O Que Valida |
|-------|---------|-------------|
| `test_vidaas_deps.py` | `tests/` | Detecção de deps, find_opensc_module |
| `test_vidaas_manager.py` | `tests/` | Estado, detecção de token, login |
| `test_vidaas_api_mock.py` | `tests/` | Client API com mock HTTP |
| `test_nss_vidaas.py` | `tests/` | Registro em navegadores |
| `test_pdf_sign_vidaas.py` | `tests/` | Assinatura PDF via PKCS#11 e API |

### 10.2 Testes de Integração

```
1. Instalar dependências (opensc, pcsclite, ccid) em VM limpa
2. Instalar VidaaS Connect Desktop (se disponível para Linux)
3. Conectar VidaaS via celular
4. Verificar que BigCertificados detecta o token
5. Registrar em Firefox e Brave
6. Acessar site PJe e verificar login com certificado
7. Assinar PDF pelo BigCertificados
```

### 10.3 Matriz de Compatibilidade

| Cenário | Firefox | Chrome | Brave | Edge |
|---------|---------|--------|-------|------|
| Detectar VidaaS PKCS#11 | ✅ | ✅ | ✅ | ✅ |
| Login em site com certificado | ✅ | ✅ | ✅ | ⚠️ |
| Assinar PDF (PKCS#11) | ✅ | N/A | N/A | N/A |
| Assinar PDF (API REST) | ✅ | ✅ | ✅ | ✅ |

### 10.4 Sites Para Validação

- PJe (Processo Judicial Eletrônico): `https://pje.trt*.jus.br`
- e-SAJ: `https://esaj.tjsp.jus.br`
- SEI (Sistema Eletrônico de Informações)
- Portal e-CAC (Receita Federal): `https://cav.receita.fazenda.gov.br`
- Gov.br com certificado digital

---

## 11. Dependências e Pacotes

### 11.1 Pacotes do Sistema (pacman)

| Pacote | Função | Obrigatório |
|--------|--------|-------------|
| `opensc` | Biblioteca PKCS#11, `opensc-pkcs11.so` | ✅ Sim |
| `pcsclite` | Daemon PC/SC (`pcscd`) | ✅ Sim |
| `ccid` | Drivers de leitores de smart card | ✅ Sim |
| `pcsc-tools` | Ferramentas de diagnóstico (`pcsc_scan`) | ❌ Opcional |
| `nss` | Ferramentas NSS (`modutil`, `certutil`) | ✅ Já é dep |

### 11.2 Dependências Python (requirements.txt)

| Pacote | Uso | Novo? |
|--------|-----|-------|
| `PyKCS11` | Acesso PKCS#11 | Já existe |
| `cryptography` | Parse de certificados | Já existe |
| `endesive` | Assinatura de PDFs | Já existe |
| `requests` | Chamadas HTTP para API REST | **Novo** |

> **Nota:** `requests` é a única dependência Python **nova** necessária. 
> Alternativa: usar `urllib.request` da stdlib para evitar uma dependência extra.

### 11.3 Alterações no PKGBUILD

```bash
depends=(
    # ... existentes ...
    'pcsclite'          # Já listado
    'ccid'              # Já listado
    'opensc'            # Já listado
    # Nenhum novo pacote de sistema necessário!
)

optdepends=(
    'pcsc-tools: Diagnóstico de leitores PC/SC'
)
```

---

## 12. Riscos e Mitigações

### 12.1 Riscos Técnicos

| # | Risco | Impacto | Probabilidade | Mitigação |
|---|-------|---------|---------------|-----------|
| R1 | VidaaS Connect Desktop não tem versão Linux oficial | Alto | Alta | Modo PKCS#11 via OpenSC como solução primária |
| R2 | API REST do VidaaS não documentada publicamente | Alto | Alta | Implementar scaffold; ajustar quando API estiver disponível |
| R3 | Token virtual não detectado pelo OpenSC | Médio | Média | Fallback: detecção manual de slots; guia para o usuário |
| R4 | NSS DB locked quando navegador rodando | Baixo | Alta | Detectar processo e avisar usuário; retry automático |
| R5 | Timeout na autorização pelo celular | Médio | Média | UI com countdown claro; botão de retry |
| R6 | Incompatibilidade com versões futuras do OpenSC | Baixo | Baixa | Testos de regressão; monitorar changelog |

### 12.2 Mitigações Adicionais

- **Fallback PKCS#11 genérico:** Se o OpenSC não detectar o token VidaaS, permitir que o usuário selecione manualmente o módulo `.so`
- **Modo diagnóstico:** Botão "Diagnóstico" que executa `pcsc_scan` e mostra o resultado, ajudando no suporte
- **Log detalhado:** Toda interação com VidaaS logada em nível DEBUG para troubleshooting
- **Guia offline:** Incluir instruções de configuração manual no `docs/manual-usuario.md`

---

## 13. Cronograma de Fases

### Fase 1 — Infraestrutura e Dependências

- [ ] Criar `src/utils/vidaas_deps.py` (verificação de dependências)
- [ ] Adicionar entrada VidaaS no `token_database.py`
- [ ] Implementar detecção automática do `pcscd`
- [ ] Tela de instalação de dependências na UI

### Fase 2 — Integração PKCS#11

- [ ] Criar `src/certificate/vidaas_manager.py`
- [ ] Implementar detecção de token virtual
- [ ] Integrar com `A3Manager` existente
- [ ] Listar certificados VidaaS
- [ ] Login com PIN via PKCS#11

### Fase 3 — Registro nos Navegadores

- [ ] Implementar `register_vidaas_in_all_browsers()` em `nss_config.py`
- [ ] Suporte Firefox (por perfil)
- [ ] Suporte Chromium-based (shared nssdb)
- [ ] Detecção de navegador rodando (aviso)
- [ ] Verificação pós-registro

### Fase 4 — Assinatura de PDFs

- [ ] Implementar `sign_pdf_vidaas()` em `pdf_signer.py`
- [ ] Integrar no `signer_view.py` (tipo VIDAAS)
- [ ] Carimbo visual com dados do certificado VidaaS
- [ ] Batch signing com VidaaS

### Fase 5 — API REST (Assinatura Remota)

- [ ] Criar `src/certificate/vidaas_api.py`
- [ ] Implementar autenticação OAuth2
- [ ] Implementar fluxo de assinatura remota
- [ ] UI de autorização com countdown
- [ ] HSM adapter remoto para endesive

### Fase 6 — Interface Gráfica Completa

- [ ] Criar `src/ui/vidaas_view.py`
- [ ] Tela de status do sistema
- [ ] Fluxo de setup guiado
- [ ] Integração na MainWindow (nova aba)
- [ ] Diálogo de autorização remota
- [ ] Tela de diagnóstico

### Fase 7 — Testes e Documentação

- [ ] Testes unitários
- [ ] Testes de integração
- [ ] Atualizar `docs/manual-usuario.md`
- [ ] Atualizar `README.md`
- [ ] Atualizar `PKGBUILD`

---

## Apêndice A — Referência Técnica VidaaS API

> **Status:** Scaffold baseado em padrões de APIs de certificados em nuvem.  
> Atualizar quando a documentação oficial estiver disponível.

### Autenticação OAuth2

```http
POST /auth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={client_id}
&client_secret={client_secret}
```

### Listar Certificados

```http
GET /certificates
Authorization: Bearer {access_token}
```

### Solicitar Assinatura

```http
POST /sign
Authorization: Bearer {access_token}
Content-Type: application/json

{
    "certificate_id": "...",
    "hash": "base64_encoded_hash",
    "hash_algorithm": "sha256",
    "signature_type": "CAdES"
}
```

### Verificar Status

```http
GET /sign/{transaction_id}/status
Authorization: Bearer {access_token}
```

---

## Apêndice B — Árvore de Arquivos Modificados/Criados

```
src/
├── certificate/
│   ├── vidaas_manager.py       # NOVO — Manager VidaaS Connect
│   ├── vidaas_api.py           # NOVO — Client REST API
│   ├── a3_manager.py           # MODIFICADO — suporte a detecção VidaaS
│   ├── pdf_signer.py           # MODIFICADO — sign_pdf_vidaas()
│   └── token_database.py       # MODIFICADO — entrada VidaaS
│
├── browser/
│   └── nss_config.py           # MODIFICADO — register_vidaas_in_all_browsers()
│
├── ui/
│   ├── vidaas_view.py          # NOVO — Tela VidaaS Connect
│   └── signer_view.py          # MODIFICADO — tipo CERT_TYPE_VIDAAS
│
├── utils/
│   └── vidaas_deps.py          # NOVO — Verificação de dependências
│
└── window.py                   # MODIFICADO — aba VidaaS no ViewStack

docs/
├── plano-vidaas-connect.md     # ESTE DOCUMENTO
└── manual-usuario.md           # MODIFICADO — instruções VidaaS

requirements.txt                # MODIFICADO — adicionar requests (se necessário)
PKGBUILD                        # MODIFICADO — optdepends pcsc-tools
```

### Resumo de Impacto

| Tipo | Quantidade |
|------|-----------|
| Arquivos **novos** | 4 |
| Arquivos **modificados** | 8 |
| Linhas estimadas de código novo | ~1200-1500 |
| Novas dependências Python | 0-1 (requests, opcional) |
| Novas dependências sistema | 0 (já listadas no PKGBUILD) |

---

*Documento gerado como plano de referência para implementação do suporte
VidaaS Connect no BigCertificados.*
