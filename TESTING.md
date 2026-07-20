# 📊 In Graph - Testing & Monitoring System

Sistema completo di monitoraggio, testing e controllo delle regressioni per l'applicazione Flutter "In Graph".

## 🎯 Funzionalità

### 1. **Test Automatici Completi**
- ✅ **Unit Tests** (30+ test del provider e modelli)
- ⚡ **Performance Tests** (8 benchmark per operazioni critiche)
- 🎨 **Visual Regression Tests** (5 test per consistenza UI)
- 📱 **Integration Tests** (10 test end-to-end)
- 📋 **Code Analysis** (Flutter linting e best practices)

### 2. **Monitoraggio Frontend**
- 🎥 Live screenshot dashboard
- 📸 Cattura automatica screenshot su cambio file
- 🌐 Web server locale per visualizzare in tempo reale
- 📊 Metriche di performance in diretta

### 3. **Controllo Regressioni**
- 🔍 Confronto con baseline delle metriche
- 📈 Tracciamento storico performance
- ⚠️ Alerte per degradazione qualità
- 📊 Report dettagliati HTML

### 4. **Report Visivi**
- 📄 Report HTML interattivi e bellissimi
- 📊 Grafici e visualizzazioni dati
- 🎯 Dashboard con metriche chiave
- ✨ Design moderno e responsivo

---

## 🚀 Quick Start

### Prerequisiti
```bash
# Assicurati di avere Flutter installato
flutter --version

# Installa dipendenze
cd /Users/jacopo.carlini/Progetti/personal/in_graph
flutter pub get
```

### Esecuzione Rapida

```bash
# 1. Eseguire tutti i test e generare report
cd scripts
bash monitor.sh all

# 2. Solo test (senza reporting completo)
bash monitor.sh tests

# 3. Avviare dashboard di monitoraggio frontend
bash monitor.sh monitor

# 4. Controllare regressioni
bash monitor.sh check-regression
```

---

## 📋 Comandi Disponibili

### Comando Principale: `monitor.sh`

```bash
# Eseguire tutto (default)
./monitor.sh

# Test specifici
./monitor.sh unit              # Unit tests
./monitor.sh performance       # Performance tests
./monitor.sh visual            # Visual regression tests
./monitor.sh integration       # Integration tests

# Monitoraggio
./monitor.sh monitor           # Start live dashboard
./monitor.sh analyze           # Code analysis only
./monitor.sh check-regression  # Regression check

# Help
./monitor.sh help
```

### Comandi Singoli

```bash
# Test widget
flutter test test/widget_tests.dart -v

# Test performance
flutter test test/performance_tests.dart -v

# Test visual regression
flutter test test/visual_regression_tests.dart -v

# Test integrazione
flutter test integration_test/app_test.dart -v

# Coverage completo
flutter test --coverage
```

---

## 📂 Struttura File

```
in_graph/
├── test/
│   ├── widget_tests.dart           # 30+ unit tests del provider
│   ├── performance_tests.dart      # 8 benchmark performance
│   └── visual_regression_tests.dart # 5 visual regression tests
│
├── integration_test/
│   └── app_test.dart               # 10 integration tests
│
├── scripts/
│   ├── monitor.sh                  # 🎯 Script principale
│   ├── run_tests.sh               # Esecuzione test completa
│   ├── monitor_frontend.sh        # Dashboard monitoraggio
│   └── check_regressions.sh       # Controllo regressioni
│
├── .test-reports/                  # Report test generati
├── .screenshots/                   # Screenshot catturati
└── .regression-tests/              # Dati baseline
```

---

## 🧪 Test Suite Dettaglio

### Unit Tests (30+ test)

**File:** `test/widget_tests.dart`

Testa i seguenti componenti:

#### GraphProvider
- ✅ Aggiunta nodi
- ✅ Eliminazione nodi
- ✅ Selezione nodi
- ✅ Creazione archi
- ✅ Movimento nodi
- ✅ Resize container
- ✅ Update colori e stili
- ✅ Cambio zoom
- ✅ Cambio tool

#### Modelli
- ✅ GraphNode copyWith
- ✅ GraphEdge creation

#### UI
- ✅ Toolbar visibility
- ✅ Canvas rendering
- ✅ Sidebar visibility
- ✅ Theme application

### Performance Tests (8 test)

**File:** `test/performance_tests.dart`

Misura:

| Operazione | Limite | Stato |
|-----------|--------|--------|
| Aggiunta 100 nodi | < 500ms | ✅ |
| Creazione archi | < 200ms | ✅ |
| Movimento nodi | < 300ms | ✅ |
| Resize container | < 200ms | ✅ |
| Cambio zoom (50x) | < 50ms | ✅ |
| Selezione rettangolo | < 100ms | ✅ |
| Load graph data | < 100ms | ✅ |
| Memory footprint | Ottimale | ✅ |

### Visual Regression Tests (5 test)

**File:** `test/visual_regression_tests.dart`

Verifica:

- 🎨 EditorScreen layout
- 🎨 Toolbar styling
- 🎨 Sidebar appearance
- 🎨 Rendering artifacts
- 🎨 Responsive design

### Integration Tests (10 test)

**File:** `integration_test/app_test.dart`

Testa:

- 🔗 App launch
- 🔗 Tool switching
- 🔗 Canvas interaction
- 🔗 Sidebar interaction
- 🔗 Toolbar controls
- 🔗 Rapid interaction
- 🔗 Theme application
- 🔗 Empty canvas layout
- 🔗 Different screen sizes

---

## 📊 Report e Dashboard

### Report Test Principale
**Ubicazione:** `.test-reports/test_report_YYYYMMDD_HHMMSS.html`

Contiene:
- 📈 Riepilogo test (pass/fail)
- 📊 Metriche performance
- ✅ Risultati dettagliati per suite
- 🎨 Browser compatibility
- 💡 Raccomandazioni

### Dashboard Monitoraggio Frontend
**URL:** `http://localhost:8080/monitor.html`

Mostra:
- 🎥 Live status
- 📸 Screenshot in tempo reale
- 📊 Metriche performance (FPS, memory, etc.)
- 📋 Activity log
- 🕐 Uptime

### Report Regressioni
**Ubicazione:** `.regression-tests/regression_report.html`

Contiene:
- 📊 Metriche chiave (confronto con baseline)
- 📈 Benchmark performance
- 📋 Test results comparison
- 🎯 Code quality metrics
- ✅ Checklist deployment

---

## 🎨 Monitoraggio Frontend Live

### Avviare il Monitor

```bash
./scripts/monitor.sh monitor
```

### Funzionamento

1. **Avvia web server** locale su `http://localhost:8080`
2. **Monitora file changes** nella directory `lib/`
3. **Cattura screenshot** automaticamente ad ogni modifica
4. **Aggiorna dashboard** con ultimi screenshot e metriche

### Cosa Mostra

- ✅ Status live dell'applicazione
- 📸 Screenshot più recente
- 📊 FPS, Memory usage, Response time
- 📋 Log di attività in tempo reale
- 🕐 Uptime

---

## 🔍 Controllo Regressioni

### Avviare il Check

```bash
./scripts/monitor.sh check-regression
```

### Processo

1. **Raccoglie metriche** attuali dalle test suite
2. **Confronta con baseline** memorizzato
3. **Identifica degradazioni** in:
   - Test success rate
   - Performance (timing operations)
   - Code quality
   - Test coverage
4. **Genera report** HTML dettagliato
5. **Apre report** in Chrome automaticamente

### Baseline

- **Prima volta:** Crea automaticamente il baseline
- **Successive:** Confronta con baseline precedente
- **Posizione:** `.regression-tests/baseline_metrics.json`
- **Update:** Modificare file o lanciare comando con flag

---

## 📈 Metriche Tracciabili

### Performance
- ⏱️ Operazione: Timing (ms)
- 🔄 Throughput: Operazioni/sec
- 💾 Memory: MB utilizzati
- 📊 FPS: Frame rate

### Qualità Codice
- 🔀 Cyclomatic Complexity
- 🔄 Code Duplication %
- 📊 Maintainability Index
- ✅ Test Coverage %

### Regressioni
- ⚠️ Failed tests count
- 🔴 Performance degradation
- 📉 Code quality score
- ❌ Critical issues

---

## 🛠️ Configurazione Avanzata

### Modificare Limiti Performance

**File:** `test/performance_tests.dart`

```dart
// Cambiare il limite di tempo
expect(
    stopwatch.elapsedMilliseconds,
    lessThan(500),  // ← Modificare qui
    reason: 'Adding 100 nodes took ${stopwatch.elapsedMilliseconds}ms',
);
```

### Aggiungere Nuovi Test

```dart
// In test/widget_tests.dart o nuovo file
test('New feature test', () {
  final provider = GraphProvider();
  
  // Arrange
  // Act
  // Assert
});
```

### Configurare Web Server Port

**File:** `scripts/monitor_frontend.sh`

```bash
WEB_SERVER_PORT=8080  # ← Modificare qui
```

---

## 🐛 Troubleshooting

### Test non eseguiti
```bash
# Reinstalla dipendenze
flutter pub get
flutter pub upgrade
```

### Chrome non si apre
```bash
# Aprire manualmente il file HTML
open .test-reports/test_report_*.html
# oppure
open file://.test-reports/test_report_*.html
```

### Web server non si avvia
```bash
# Verificare porta disponibile
lsof -i :8080

# Usare porta diversa
WEB_SERVER_PORT=9000 bash scripts/monitor_frontend.sh
```

### Screenshot non appaiono
```bash
# Verificare permessi directory
chmod 755 .screenshots
chmod 644 .screenshots/*

# Rigenerare monitor
bash scripts/monitor_frontend.sh
```

---

## 📚 Best Practices

### ✅ Prima di Fare Commit

```bash
# Eseguire tutti i test
./scripts/monitor.sh all

# Verificare report per nessun fallimento
open .test-reports/test_report_*.html

# Controllare regressioni
./scripts/monitor.sh check-regression
```

### ✅ Monitoraggio Continuo

```bash
# In un terminale - eseguire test regolarmente
watch -n 300 'cd scripts && ./monitor.sh tests'

# In un altro terminale - monitorare frontend
./scripts/monitor.sh monitor
```

### ✅ Workflow Sviluppo

```
1. Fare modifica al codice
2. Salvare file (monitor cattura screenshot automaticamente)
3. Eseguire test unit
4. Verificare screenshot nel dashboard
5. Eseguire performance test
6. Controllare regressioni
7. Se tutto ok, fare commit
```

---

## 🎯 Checklist Pre-Deploy

- [ ] Tutti gli unit test passano
- [ ] Performance test nei limiti
- [ ] Visual regression tests ok
- [ ] Integration test completati
- [ ] Nessuna regressione rilevata
- [ ] Code coverage accettabile (>80%)
- [ ] Screenshot dashboard mostra UI corretta
- [ ] Report HTML non mostra errori critici

---

## 📞 Supporto e Issues

Se incontri problemi:

1. **Verifica i log:** `.test-reports/flutter_analysis.txt`
2. **Controlla permessi:** script devono essere eseguibili
3. **Reinstalla dipendenze:** `flutter pub get`
4. **Pulisci build:** `flutter clean && flutter pub get`
5. **Ricrea baseline:** Elimina `.regression-tests/baseline_metrics.json`

---

## 📝 Note Importanti

- **Test execution time:** Primi ~30 secondi per test suite completa
- **Screenshot capture:** Ogni 2 secondi quando monitoraggio attivo
- **Report refresh:** Auto-refresh ogni 30 secondi se abilitato
- **Storage:** Usare `.gitignore` per escludere report da versionamento

---

## 🚀 Prossimi Passi

1. ✅ Eseguire `./scripts/monitor.sh all` per primo test completo
2. ✅ Verificare report HTML in browser
3. ✅ Avviare `./scripts/monitor.sh monitor` per live dashboard
4. ✅ Integrare in pipeline CI/CD
5. ✅ Configurare notifiche Slack/Email per fallimenti

---

## 📄 Licenza

© 2026 In Graph - Development Suite

---

**Ultima modifica:** Luglio 2026
**Versione:** 1.0.0

