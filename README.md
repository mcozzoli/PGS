# PGS Salgen — app ufficiale (iOS + Android)

App mobile **Flutter** della squadra **PGS Salgen Roma**. È il client nativo del
portale [basketsalgen.pages.dev](https://basketsalgen.pages.dev): riusa la stessa
API (Cloudflare Pages + D1) e replica le funzioni del sito.

## Funzioni (parità col portale)

- **Login multi-ruolo**: giocatore (cognome + numero + password), coach, admin, tifoso (senza password).
- **Home** personalizzata per ruolo con stato convocazione, record e banner diretta.
- **Calendario** (Andata / Ritorno / Coppa-Torneo / Amichevoli) con conto alla rovescia.
- **Risultati**: record, tabellini e **Classifica** (modificabile dall'admin).
- **Statistiche** personali e per giocatore (medie, tiri, partita per partita).
- **Squadra** e roster.
- **Bacheca** con lettura/scrittura (coach, capitano, admin) e contatore "letto da".
- **Diretta**: punteggio, cronometro, azione per azione e tabellino live (aggiornamento ogni 4 s).
- **Coach**: convocati, quintetto e capitano.
- **Scout live** (admin): refertazione in tempo reale, sincronizzata col server.
- **Profilo**: cambio password.

> **Notifiche push**: il portale usa Web Push (VAPID). Su mobile servono FCM
> (Android) e APNs (iOS); la relativa integrazione richiede un endpoint lato
> backend ed è pianificata come step successivo (vedi `docs/PUSH.md`).

## Sviluppo

```bash
flutter pub get
flutter run                     # usa l'API di produzione per default
# backend alternativo:
flutter run --dart-define=PGS_API_BASE=http://10.0.2.2:3000
```

- Base API configurabile con `--dart-define=PGS_API_BASE=<url>` (default: produzione).
- `flutter analyze` e `flutter test` devono restare verdi.

## Build & distribuzione

Le build avvengono in **GitHub Actions** (vedi `.github/workflows/`):

- **Android** (`android.yml`): APK + App Bundle su runner Ubuntu.
- **iOS** (`ios.yml`): archivio e upload su TestFlight da runner macOS, usando la
  **App Store Connect API key**. I segreti richiesti sono documentati in
  `docs/IOS_RELEASE.md`.

## Struttura

```
lib/
  config.dart        base URL API, colori sociali
  models.dart        modelli dati (Game, Player, Lineup, Standings, LiveState, …)
  api.dart           client HTTP
  app_state.dart     stato globale (ChangeNotifier) + bootstrap
  logic.dart         calcoli puri (totali, valutazione, deriveLive, clock)
  theme.dart         tema Material
  widgets.dart       widget condivisi (Jersey, MatchCard, StatTile, …)
  screens/           una schermata per sezione del portale
```
