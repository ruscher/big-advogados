# BigCertificados — Plano de UX/UI Design

## Índice

1. [Diagnóstico da UI Atual](#1-diagnóstico-da-ui-atual)
2. [Princípios de Design](#2-princípios-de-design)
3. [Arquitetura de Navegação Proposta](#3-arquitetura-de-navegação-proposta)
4. [Layout por Tela](#4-layout-por-tela)
5. [Padrões de Interação](#5-padrões-de-interação)
6. [Componentes Reutilizáveis](#6-componentes-reutilizáveis)
7. [Responsive / Adaptive](#7-responsive--adaptive)
8. [Acessibilidade](#8-acessibilidade)
9. [Priorização e Fases](#9-priorização-e-fases)

---

## 1. Diagnóstico da UI Atual

### Problemas Identificados

| #  | Problema | Gravidade | Onde |
|----|----------|-----------|------|
| P1 | **6 abas no ViewSwitcher do header** — overflow visual, labels truncam em janelas menores | Alta | window.py |
| P2 | **Tokens e Certificados A1 são abas separadas** mas são ambos "certificados" — fragmentação de conceito | Alta | Nav principal |
| P3 | **Sistemas Judiciais é um scroll infinito** com 8+ expanderRows + PJeOffice + drivers tudo junto | Alta | systems_view.py |
| P4 | **Signer View (1100 linhas)** combina seleção de PDFs, seleção de certificado, opções de assinatura e resultados — monolítico | Alta | signer_view.py |
| P5 | **VidaaS Connect** tem 3 estados internos (welcome→setup→connected) com stack proprio, duplicando padrão de navegação | Média | vidaas_view.py |
| P6 | **Sem hierarquia visual clara** — todas as abas têm o mesmo peso visual, mas o fluxo de trabalho típico é: conectar token → ver certificados → assinar documento | Média | Nav geral |
| P7 | **Certificados A3 só aparecem após PIN** — antes disso é uma StatusPage vazia que parece "quebrada" | Média | certificate_view.py |
| P8 | **Busca global** escondida atrás de Ctrl+F com pouca indicação visual | Baixa | window.py |
| P9 | **Nenhum onboarding** — usuário novo vê abas técnicas sem orientação | Média | - |
| P10 | **Ações de menu (Dependências, Navegadores)** estão desconectadas do fluxo principal | Baixa | Menu hamburger |

### Métricas Atuais

- **Abas top-level**: 6 (Tokens, A1, Certificados, Sistemas, Assinador, VidaaS) — demais para ViewSwitcher
- **Cliques para assinar um PDF com A3**: ~8 (mudar aba → detectar token → PIN → voltar Assinador → selecionar PDF → selecionar cert → configurar → assinar)
- **Profundidade máxima**: 3 (aba → expander → row com ação)
- **Scroll máximo**: systems_view com 39 sistemas + PJeOffice + drivers

---

## 2. Princípios de Design

### GNOME HIG (Human Interface Guidelines)

1. **Foco na tarefa** — eliminar passos desnecessários entre a intenção e a ação
2. **Progressive disclosure** — mostrar o mínimo necessário, revelar complexidade sob demanda
3. **Consistência** — mesmos padrões em todas as telas
4. **Responsive** — funcionar de 360px a 1920px de largura

### Princípios Específicos do BigCertificados

1. **O certificado é o centro** — tudo gira em torno de ter um certificado válido e usá-lo
2. **Fluxo linear** — Certificados → Usar (assinar, acessar sistema) → Configurar (navegadores, drivers)
3. **Status sempre visível** — o usuário precisa saber a qualquer momento se tem um certificado ativo
4. **Zero dependência de conhecimento técnico** — termos como PKCS#11, NSS, pcscd devem ficar em camadas secundárias

---

## 3. Arquitetura de Navegação Proposta

### Opção Recomendada: `AdwNavigationSplitView` (Sidebar + Content)

Substitui o ViewSwitcher por uma sidebar persistente (desktop) que colapsa em mobile (< 500px).

```
┌──────────────────────────────────────────────────────┐
│  ◉ BigCertificados                          ☰ Menu   │
├────────────────┬─────────────────────────────────────┤
│                │                                     │
│  🏠 Início     │     [ Conteúdo da seção ativa ]     │
│                │                                     │
│  ─────────     │                                     │
│  CERTIFICADOS  │                                     │
│  🔑 Tokens A3  │                                     │
│  📄 Cert. A1   │                                     │
│  ☁️ VidaaS     │                                     │
│                │                                     │
│  ─────────     │                                     │
│  FERRAMENTAS   │                                     │
│  ✍️ Assinador  │                                     │
│  ⚖️ Sistemas   │                                     │
│                │                                     │
│  ─────────     │                                     │
│  CONFIGURAÇÃO  │                                     │
│  🔧 Dependen.  │                                     │
│  🌐 Navegad.   │                                     │
│                │                                     │
└────────────────┴─────────────────────────────────────┘
```

### Justificativa

| Critério | ViewSwitcher (atual) | NavigationSplitView (proposta) |
|----------|---------------------|-------------------------------|
| Itens suportados | 3-5 idealmente | Ilimitado com scroll |
| Categorização | Sem agrupamento | Seções com headers |
| Espaço para labels | Limitado (trunca) | Largura total |
| Mobile | ViewSwitcherBar no bottom | Sidebar colapsa, menu aparece |
| Ícones + texto | Ambos visíveis, mas apertado | Sempre espaço suficiente |
| Hierarquia visual | Flat | Agrupado por contexto |
| Acesso a configuração | Escondido no menu ☰ | Visível na sidebar |

### Hierarquia de Navegação

```
Sidebar (Nível 1)
├── Início                    → Dashboard / Overview / Onboarding
│
├── ─── CERTIFICADOS ───
│   ├── Tokens USB             → Detecção + PIN + Certificados A3
│   ├── Certificado A1         → Importar PFX + Detalhes
│   └── VidaaS Connect        → Setup + Certificados na nuvem
│
├── ─── FERRAMENTAS ───
│   ├── Assinador de PDFs     → Sidebar interna (PDFs | Certificado | Opções | Resultados)
│   └── Sistemas Judiciais    → Sidebar interna (Estados | PJeOffice | Drivers)
│
└── ─── CONFIGURAÇÃO ───
    ├── Dependências           → Diálogo existente, mas como página
    └── Navegadores            → Status NSS + Configurar
```

### Alternativa: `AdwOverlaySplitView`

Se for necessário dar mais espaço ao conteúdo, o `AdwOverlaySplitView` permite que a sidebar sobreponha o conteúdo em telas menores, com um botão de toggle. Recomendado para o **Assinador** e **Sistemas** como segundo nível de sidebar:

```
Sistemas Judiciais:
┌───────────────┬─────────────────────────────────┐
│  ESTADOS      │                                 │
│  🏛️ Superiores │   [ Lista de links do estado   │
│  🗺️ Bahia      │     selecionado na sidebar ]    │
│  🗺️ São Paulo  │                                 │
│  🗺️ Distrito F │   PJe — TJBA 1ª Instância →    │
│  🗺️ Rio de Jan │   PJe — TJBA 2ª Instância →    │  
│  🗺️ Minas Ger  │   PJe — TRF1 1ª Instância →   │
│  🗺️ Rio G. Sul │   PROJUDI — TJBA →              │
│  🗺️ Paraná     │   e-SAJ — TJBA →                │
│  ────────     │                                 │
│  FERRAMENTAS  │                                 │
│  🛠️ PJeOffice  │                                 │
│  📦 Drivers    │                                 │
│  🌐 Brave/NSS │                                 │
└───────────────┴─────────────────────────────────┘
```

---

## 4. Layout por Tela

### 4.1. Tela Início (Dashboard)

**Objetivo**: Dar ao usuário uma visão geral instantânea e orientar próximos passos.

**Widget**: `AdwStatusPage` (estado vazio) ou Cards layout (com certificados)

```
┌─────────────────────────────────────────────┐
│           BigCertificados                   │
│                                             │
│  ┌─ Card ──────────────────────────────┐    │
│  │  🔑 Token A3 conectado              │    │
│  │  SafeSign · e-CPF João da Silva     │    │
│  │  Validade: 12/2027 (540 dias)   ✓   │    │
│  │  [ Ver certificados ] [ Assinar ]   │    │
│  └──────────────────────────────────────┘    │
│                                             │
│  ┌─ Card ──────────────────────────────┐    │
│  │  📄 Certificado A1                  │    │
│  │  e-CNPJ Escritório Silva Ltda       │    │
│  │  Validade: 03/2026 (2 dias!) ⚠️     │    │
│  │  [ Ver detalhes ] [ Renovar ]       │    │
│  └──────────────────────────────────────┘    │
│                                             │
│  ┌─ Card ──────────────────────────────┐    │
│  │  ☁️ VidaaS Connect                  │    │
│  │  Não configurado                    │    │
│  │  [ Configurar agora → ]             │    │
│  └──────────────────────────────────────┘    │
│                                             │
│  ─── Ações Rápidas ───                      │
│  [ 📝 Assinar PDF ]  [ ⚖️ Acessar PJe ]   │
│  [ 🔧 Verificar deps ]                     │
│                                             │
└─────────────────────────────────────────────┘
```

**Sem certificados (onboarding)**:
```
┌─────────────────────────────────────────────┐
│                                             │
│        🔐                                    │
│   Bem-vindo ao BigCertificados              │
│                                             │
│   Comece conectando seu certificado:        │
│                                             │
│   [ 🔑  Conectar Token USB ]                │
│   [ 📄  Importar Certificado A1 ]           │
│   [ ☁️  Configurar VidaaS Connect ]         │
│                                             │
└─────────────────────────────────────────────┘
```

### 4.2. Tokens USB (A3)

**Atual**: 2 abas separadas (Tokens + Certificados) → **Proposta**: unificar em uma tela com estados

```
Estado 1: Nenhum token
┌─ AdwStatusPage ─────────────────────────┐
│  🔌 Nenhum token USB detectado          │
│  Conecte seu token e clique em buscar   │
│  [ 🔍 Buscar dispositivos ]             │
└──────────────────────────────────────────┘

Estado 2: Token detectado (sem PIN)
┌─ PreferencesGroup ──────────────────────┐
│  Dispositivos Conectados                │
│  ┌ ActionRow ────────────────────────┐  │
│  │ 🔑 SafeSign eToken 5110          │  │
│  │ USB 04e6:5816 · Driver OK    → │  │
│  └───────────────────────────────────┘  │
└──────────────────────────────────────────┘
→ Clicar na row → abre PIN dialog

Estado 3: Autenticado (mostra certificados inline)
┌─ PreferencesGroup ──────────────────────┐
│  Dispositivos Conectados                │
│  ┌ ExpanderRow ──────────────────────┐  │
│  │ 🔑 SafeSign eToken · 2 certs ▼  │  │
│  │ ┌ ActionRow ──────────────────┐  │  │
│  │ │ 📜 JOAO DA SILVA             │  │  │
│  │ │ CPF: 123.456.789-00          │  │  │
│  │ │ OAB: 12345/BA · Válido ✓    │  │  │
│  │ │ [ Detalhes ] [ Assinar → ]  │  │  │
│  │ └────────────────────────────┘  │  │
│  │ ┌ ActionRow ──────────────────┐  │  │
│  │ │ 📜 Cert. Autenticação        │  │  │
│  │ │ Válido até 12/2027 ✓        │  │  │
│  │ └────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

**Vantagem**: Uma tela, zero navegação. Token → PIN → certificados, tudo no mesmo lugar.

### 4.3. Certificado A1

Mantém o design atual (funciona bem). Mudanças menores:

- Mover para dentro da seção "Certificados" da sidebar
- Adicionar botão "Assinar PDF →" direto na tela de detalhes (navegação cruzada)
- Banner de alerta para certificados prestes a expirar

### 4.4. VidaaS Connect

**Já refatorado com abas** (Dependências | Conexão | Diagnóstico). Mantém.

Ajustes propostos:
- Quando conectado, mostrar certificados inline (como tokens A3) em vez de página separada
- Ação "Assinar PDF →" direto da lista de certificados

### 4.5. Assinador de PDFs

**Problema principal**: Tela monolítica de 1100 linhas, scroll longo.

**Proposta**: Wizard em 4 passos com `AdwCarousel` ou `GtkAssistant`-style (Stack + progress indicator):

```
Passo 1/4: Selecionar PDFs
┌─────────────────────────────────────────────┐
│  [ 1 📄 PDFs ] ── [ 2 🔑 Cert ] ── [ 3 ⚙️ ] ── [ 4 ✅ ]  │
│                                             │
│  ┌─ Drop zone ─────────────────────────┐    │
│  │                                     │    │
│  │  📁 Arraste PDFs aqui              │    │
│  │  ou [ Selecionar arquivos ]         │    │
│  │                                     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─ Lista de PDFs adicionados ─────────┐    │
│  │  📄 contrato.pdf         120 KB  ✕  │    │
│  │  📄 procuracao.pdf        45 KB  ✕  │    │
│  └─────────────────────────────────────┘    │
│                                             │
│            [ Limpar ] [ Próximo → ]         │
└─────────────────────────────────────────────┘

Passo 2/4: Selecionar Certificado
┌─────────────────────────────────────────────┐
│  Tipo de certificado:                       │
│  [ A1 (arquivo) | A3 (token) | VidaaS ]    │
│                                             │
│  ┌─ Certificado selecionado ───────────┐    │
│  │  🔑 JOAO DA SILVA                  │    │
│  │  CPF: 123.456.789-00 · OAB: 12345  │    │
│  │  Válido ✓                           │    │
│  │  [ Trocar certificado ]             │    │
│  └─────────────────────────────────────┘    │
│                                             │
│         [ ← Voltar ] [ Próximo → ]          │
└─────────────────────────────────────────────┘

Passo 3/4: Opções de Assinatura
┌─────────────────────────────────────────────┐
│  ┌─ EntryRow ──────────────────────────┐    │
│  │  Razão: Assinatura de documento     │    │
│  └─────────────────────────────────────┘    │
│  ┌─ EntryRow ──────────────────────────┐    │
│  │  Local: Brasil                      │    │
│  └─────────────────────────────────────┘    │
│  ┌─ SwitchRow ─────────────────────────┐    │
│  │  Assinatura visível         [  ✓ ]  │    │
│  └─────────────────────────────────────┘    │
│  ┌─ ComboRow ──────────────────────────┐    │
│  │  Posição: Última página         ▾   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│         [ ← Voltar ] [ ✍️ Assinar ]         │
└─────────────────────────────────────────────┘

Passo 4/4: Resultado
┌─────────────────────────────────────────────┐
│                                             │
│             ✅ Assinado com sucesso          │
│        2 de 2 documentos assinados          │
│                                             │
│  ┌─ ActionRow ─────────────────────────┐    │
│  │  📄 contrato_assinado.pdf    ✓  📁  │    │
│  └─────────────────────────────────────┘    │
│  ┌─ ActionRow ─────────────────────────┐    │
│  │  📄 procuracao_assinada.pdf  ✓  📁  │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  [ 📁 Abrir pasta ] [ ✍️ Assinar mais ]     │
└─────────────────────────────────────────────┘
```

### 4.6. Sistemas Judiciais

**Proposta**: `AdwNavigationSplitView` interno (sidebar de estados + conteúdo de links).

```
┌───────────────┬─────────────────────────────────────┐
│  TRIBUNAIS    │                                     │
│  🏛️ Superiores │  Bahia — Sistemas Judiciais         │
│               │                                     │
│  ESTADOS      │  ┌─ PJe ─────────────────────────┐  │
│  🗺️ BA         │  │ TJBA 1ª Instância         →  │  │
│  🗺️ SP         │  │ TJBA 2ª Instância         →  │  │
│  🗺️ DF         │  │ TRF1 1ª Instância         →  │  │
│  🗺️ RJ         │  │ TRF1 2ª Instância         →  │  │
│  🗺️ MG         │  │ TRT5 (Bahia)              →  │  │
│  🗺️ RS         │  └─────────────────────────────┘  │
│  🗺️ PR         │                                     │
│               │  ┌─ Outros Sistemas ─────────────┐  │
│  ────────     │  │ PROJUDI — TJBA             →  │  │
│  FERRAMENTAS  │  │ e-SAJ — TJBA              →  │  │
│  🛠️ PJeOffice  │  └─────────────────────────────┘  │
│  📦 Drivers   │                                     │
│  🌐 Brave     │                                     │
└───────────────┴─────────────────────────────────────┘
```

**Vantagem**: Elimina scroll infinito. Cada estado ocupa apenas uma tela. PJeOffice, Drivers e Brave config ficam como seções separadas na sidebar.

### 4.7. Dependências

**Já recriado como diálogo completo**. Proposta de evolução:
- Mover de diálogo para página na sidebar (seção Configuração)
- Manter botões de ação individuais (ícone flat) e "Resolver todas"
- Adicionar status badge na sidebar quando há pendências

### 4.8. Navegadores

Promover configuração de navegadores de ação do menu a seção visível:

```
┌─────────────────────────────────────────────┐
│  Navegadores Configurados                   │
│                                             │
│  ┌ ActionRow ────────────────────────────┐  │
│  │ 🦊 Firefox           Configurado ✓   │  │
│  └───────────────────────────────────────┘  │
│  ┌ ActionRow ────────────────────────────┐  │
│  │ 🌐 Chrome            Não config. ⚠️  │  │
│  │                       [ Configurar ]  │  │
│  └───────────────────────────────────────┘  │
│  ┌ ActionRow ────────────────────────────┐  │
│  │ 🦁 Brave             Configurado ✓   │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  [ Configurar todos os navegadores ]        │
└─────────────────────────────────────────────┘
```

---

## 5. Padrões de Interação

### 5.1. Navegação Cruzada (Cross-Navigation)

Permitir ir de uma seção para outra mantendo contexto:

- **Certificado A3 → "Assinar PDF"** → abre Assinador com cert. pré-selecionado
- **Dashboard card → "Ver certificados"** → abre tela de Tokens com token expandido
- **Sistema judicial → "Configurar navegador"** → abre tela de Navegadores
- **Dependência faltando → "Instalar"** → ação no local, sem trocar de tela

### 5.2. Status Persistente

Barra inferior (já existe) com informações dinâmicas:

```
🔑 SafeSign 5110 · 2 certificados · Válido     |  ☁️ VidaaS: Conectado
```

### 5.3. Toasts para Feedback Não-Crítico

- "2 PDFs assinados com sucesso"
- "Navegador Firefox configurado"
- "Pacote opensc instalado"

### 5.4. Diálogos para Feedback Crítico

- PIN do token
- Senha do A1
- Confirmação de remoção
- Falhas de assinatura

### 5.5. Drag and Drop

- Arrastar PDFs para a tela do Assinador
- Arrastar PFX para a tela de A1

---

## 6. Componentes Reutilizáveis

### CertificateCard

Widget reutilizável para exibir qualquer certificado (A1, A3, VidaaS):

```python
class CertificateCard(Adw.ActionRow):
    """Displays certificate with holder, validity, and quick actions."""
    # Used in: Dashboard, Token view, A1 view, VidaaS view, Signer (cert selection)
```

### DependencyRow

Widget reutilizável para status de dependência com ação:

```python
class DependencyRow(Adw.ActionRow):
    """Shows dependency status with install/toggle action."""
    # Used in: Dependencies page, VidaaS deps tab
```

### StepIndicator

Indicador de progresso para wizards:

```python
class StepIndicator(Gtk.Box):
    """Horizontal step indicator: ① → ② → ③ → ④"""
    # Used in: Signer wizard, VidaaS setup
```

---

## 7. Responsive / Adaptive

### Breakpoints

| Largura | Comportamento |
|---------|--------------|
| < 400px | Sidebar colapsa totalmente, toggle button no header |
| 400–600px | Sidebar em overlay (AdwOverlaySplitView) |
| 600–900px | Sidebar fixa estreita (sidebar_width_fraction: 0.33) |
| > 900px | Sidebar fixa + conteúdo amplo |

### libadwaita Widgets por Breakpoint

```python
# Main navigation
AdwNavigationSplitView  # sidebar + content, auto-collapses
  sidebar_width_fraction = 0.28  # ~220px at 800px width

# Judicial systems (nested split)
AdwOverlaySplitView  # overlay sidebar for states, show-sidebar toggleable

# Content
AdwClamp  # max 600px, centers content
AdwBreakpoint  # for widget visibility toggles
```

---

## 8. Acessibilidade

### Requisitos GNOME A11y

1. **Todas as ações via teclado** — Tab entre rows, Enter para ativar, Esc para voltar
2. **Labels de acessibilidade** em todos os botões ícone (tooltip = a11y label)
3. **Contraste** — seguir Adw tokens de cor, nunca cor hardcoded sem fallback
4. **Screen reader** — `set_accessible_role()` e `update_property()` em widgets dinâmicos
5. **Focus indicator** — visível em todos os itens interativos
6. **Atalhos de teclado**:
   - `Ctrl+F` — Busca
   - `Ctrl+1..9` — Navegar para seção N da sidebar
   - `Ctrl+S` — Assinar (quando no step correto)
   - `F5` — Buscar dispositivos

---

## 9. Priorização e Fases

### Fase 1: Navegação Principal (Impacto Alto, Risco Médio)

**Objetivo**: Substituir ViewSwitcher por sidebar com categorias.

Tarefas:
1. Substituir `Adw.ViewStack` + `Adw.ViewSwitcher` por `Adw.NavigationSplitView`
2. Criar sidebar com `Gtk.ListBox` categorizado (Certificados / Ferramentas / Configuração)
3. Migrar todas as views existentes para o novo container
4. Implementar navegação mobile (sidebar colapsável)
5. Adicionar atalhos de teclado para navegação

**Widgets**: `AdwNavigationSplitView`, `AdwNavigationPage`, `GtkListBox` com `GtkListBoxRow`

### Fase 2: Dashboard / Tela Inicial (Impacto Alto, Risco Baixo)

**Objetivo**: Dar visão geral instantânea ao usuário.

Tarefas:
1. Criar `DashboardView` com cards de status dos certificados
2. Implementar onboarding para primeiro acesso (StatusPage com ações)
3. Adicionar ações rápidas (Assinar, Acessar PJe)
4. Badge de alerta na sidebar quando cert. expira em < 30 dias

### Fase 3: Unificar Tokens + Certificados (Impacto Alto, Risco Médio)

**Objetivo**: Eliminar 2 abas, mostrar tudo em uma tela.

Tarefas:
1. Unificar `TokenDetectView` + `CertificateView` em `TokenView`
2. Token detectado → PIN → certificados inline (ExpanderRow com certs)
3. Eliminar StatusPage vazia no CertificateView
4. Manter detecção automática + manual

### Fase 4: Wizard do Assinador (Impacto Médio, Risco Alto)

**Objetivo**: Transformar 1100 linhas de scroll em wizard guiado de 4 passos.

Tarefas:
1. Separar em 4 sub-views: PDFs → Certificado → Opções → Resultado
2. Indicador de progresso no topo
3. Drag-and-drop de PDFs (GtkDropTarget)
4. Pre-seleção de certificado via navegação cruzada
5. Progress bar durante assinatura

### Fase 5: Sistemas Judiciais com Split View (Impacto Médio, Risco Baixo)

**Objetivo**: Eliminar scroll infinito.

Tarefas:
1. Criar `AdwOverlaySplitView` com sidebar de estados
2. Conteúdo exibe links do estado selecionado
3. PJeOffice, Drivers e Brave como seções separadas
4. Busca dentro dos sistemas (filtro instantâneo)

### Fase 6: Configuração como Páginas (Impacto Baixo, Risco Baixo)

**Objetivo**: Promover Dependências e Navegadores de diálogos a páginas.

Tarefas:
1. Mover conteúdo do diálogo de dependências para `DependenciesView`
2. Criar `BrowserConfigView` com status por navegador
3. Adicionar ambos à seção Configuração da sidebar
4. Manter atalho no menu ☰ para acesso rápido

---

## Resumo Visual da Proposta

```
ANTES (6 abas flat no header):
[Tokens] [A1] [Certificados] [Sistemas] [Assinador] [VidaaS]
      ↓ trunca em telas menores / sem categorização

DEPOIS (sidebar categorizada):
┌─────────────────┬───────────────────────────┐
│ 🏠 Início        │                           │
│                  │  Conteúdo contextual      │
│ ─ CERTIFICADOS ─ │  com espaço suficiente    │
│ 🔑 Tokens USB    │  e sem scroll infinito    │
│ 📄 Certificado A1│                           │
│ ☁️ VidaaS        │  Padrão GNOME HIG:        │
│                  │  - AdwClamp (600px)       │
│ ─ FERRAMENTAS ── │  - PreferencesGroup       │
│ ✍️ Assinador      │  - ActionRow              │
│ ⚖️ Sistemas       │  - NavigationSplitView    │
│                  │                           │
│ ─ CONFIG ─────── │                           │
│ 🔧 Dependências  │                           │
│ 🌐 Navegadores   │                           │
└─────────────────┴───────────────────────────┘
```

---

*Documento criado em 31/03/2026 — BigCertificados v1.0.0*
