# basketsalgen — contesto del progetto

Portale web della squadra di basket **PGS SALGEN Roma** (stagione 2026/27): calendario, risultati, classifica, statistiche personali, convocazioni/quintetto, bacheca con notifiche push, scout live con diretta per tutti.

- **Online:** https://basketsalgen.pages.dev (Cloudflare Pages + D1, account Cloudflare personale `tanzarellalorenzo24@gmail.com`)
- **Codice:** https://github.com/tanza01/basketsalgen (privato)
- **Lingua:** tutta l'interfaccia e i messaggi sono in **italiano**. Colori sociali: blu `#0b2f7a`/`#1240a8`, bianco, arancione `#f7941d`. Font: Anton (titoli) + Nunito.

## Regole di lavoro

- **Dopo ogni modifica: commit + push + deploy**, senza chiedere.
  - commit firmati `lbaioni00 <leonardo.baioni.ext@fluttersea.com>` (già nel `git config` locale), **messaggio di una sola riga breve**, **nessun Co-Authored-By**;
  - il push usa sempre l'account GitHub **tanza01** tramite il credential helper locale del repo (`gh auth token --user tanza01`); l'account `gh` attivo globale resta **lbaioni00**: non cambiarlo;
  - deploy: `npx wrangler pages deploy public --project-name basketsalgen --branch main --commit-dirty=true`. A volte Cloudflare impiega fino a ~10–15 min a servire la nuova versione: verificare con `curl https://basketsalgen.pages.dev/js/app.js?x=$RANDOM | grep <qualcosa di nuovo>`.
- Testare prima in locale (vedi sotto); per la UI su telefono usare iframe 390×844 / 844×390 (il resize della finestra Chrome non funziona su questa macchina).
- Su questa macchina gli heredoc lunghi in Bash a volte si rompono: per patch grandi scrivere uno script Python con il tool Write ed eseguirlo.
- Mai mettere in chiaro nel codice password o chiavi; segreti solo come secret Cloudflare.

## Architettura

Nessuna dipendenza npm a runtime. Una sola logica API condivisa fra server locale e Cloudflare.

```
lib/api.js                 tutta la logica API (Request/Response web standard + Web Crypto)
lib/push.js                Web Push: cifratura RFC 8291 aes128gcm + VAPID (verificati con librerie indipendenti)
functions/api/[[path]].js  Cloudflare Pages Function: store su D1 (tabelle kv + files a pezzi da 900 KB base64)
server.js                  server Node locale (store su file in data/)
seed.js                    rosa (18: 17 giocatori + coach Gaeta #1) e calendario iniziale (10 partite)
public/                    SPA statica: index.html, js/app.js (tutto il frontend), css/{style,live,scout}.css,
                           sw.js (service worker push), manifest.webmanifest, qr.html (poster QR), img/
wrangler.toml              progetto Pages + binding D1 `DB` → database `basketsalgen-db`
```

- Frontend: vanilla JS, routing a hash (`#/home`, `#/bacheca`, …), stato globale `S`, `render()` ridisegna tutto; `S.cleanups` per timer/listener.
- Store (interfaccia usata da `lib/api.js`): `load()/save(db)` per il JSON principale (chiave `db`), `getJSON/putJSON(k)` per chiavi separate (es. `live`, così lo scout non sovrascrive il resto), `putFile/getFile/deleteFile`, `secret()`.
- Dati principali in `db`: `players, games, stats{gid:{num:{...}}}, lineups{gid:{convocati,starters,captain}}, captain, messages, reads, subs, docs, auth, standings`.

## Ruoli e accesso

| Ruolo | Login | Può |
|---|---|---|
| Giocatore | cognome + numero maglia + password | tutto in lettura, profilo |
| Coach (Gaeta #1) | come giocatore | + convocati (max **15**), quintetto, capitano, bacheca, carica referti |
| Capitano (di stagione) | è un giocatore | + scrive in bacheca |
| Admin | "Accesso admin" + password (secret `ADMIN_PASSWORD`, copia locale in `ADMIN-PASSWORD.txt` non versionato) | calendario, statistiche, scout live, classifica, password giocatori |
| Tifoso | pulsante "Sono un tifoso", senza password | solo partite future, diretta, classifica, notifiche "Si gioca"/"Finale" (bloccato lato server) |

- Password di squadra: la conosce l'utente (non scriverla in file versionati); nel codice c'è solo il suo hash SHA-256, sovrascrivibile con env `PLAYER_PASSWORD`.
- Password personali: PBKDF2-SHA256 20k iterazioni + sale (`db.auth[num]`). Il token contiene `pv`: cambiando password gli altri dispositivi vengono disconnessi. L'admin può ripristinare singolo o tutti.
- Token: HMAC firmato, 60 giorni. In locale, senza env `ADMIN_PASSWORD`, vale la password di sviluppo definita in `server.js` (mai usata online).

## Funzionalità

- **Calendario**: sezioni Andata / Ritorno / Coppa-Torneo / Amichevoli; admin crea/modifica/elimina partite con opzione "Avvisa la squadra" (messaggio in bacheca + push). Le **amichevoli non contano** in record, statistiche e classifiche.
- **Risultati**: tab Partite (record, tabellino, referto) e **Classifica**. Il **girone = PGS Salgen + tutte le avversarie delle partite non amichevoli del calendario** (derivato dal server, segue il calendario); admin modifica solo i numeri (PT, G, V, P, CF, CS) o "Registra un risultato" (2 punti alla vincente di default).
- **Referto ufficiale**: foto (compresse lato client) o PDF ≤ 8 MB; caricano admin e coach, scaricano tutti i membri.
- **Scout live** (admin): pensato per telefono **in orizzontale**, schermo intero, tre colonne (5 in campo · azioni · avversari/annulla). Tocchi giocatore→azione o azione→giocatore; cronometro, quarti/OT, cambi (minuti calcolati), falli personali e di squadra, annulla, "Ricomincia da capo". "Termina" salva le statistiche nelle schede. Stato salvato in localStorage + server (chiave `live`).
- **Diretta**: tutti (anche tifosi) vedono punteggio, cronometro, azione per azione, tabellino; aggiornamento ogni 4 s.
- **Coach**: minigame convocati su nastro trasportatore, quintetto sul campo (drag o tap), capitano (stagione + partita), export formazione PNG/PDF/condivisione.
- **Bacheca**: scrivono coach, capitano, admin; contatore "letto da"; inoltro WhatsApp = **solo il testo del messaggio**.
- **Notifiche push**: VAPID (secret `VAPID_PUBLIC`/`VAPID_PRIVATE`); un dispositivo = una iscrizione intestata a chi è collegato (niente doppioni); su iPhone solo da app aggiunta alla Home.
- **Profilo** (giocatori/coach): cambio password.

## Sviluppo locale

```bash
node server.js                      # http://localhost:3000, dati in data/
PORT=3131 DATA_DIR=/percorso/temp node server.js   # istanza di prova isolata
npx wrangler pages dev --port 8790 --binding ADMIN_PASSWORD=testlocale   # runtime Cloudflare + D1 locale
```

Dopo i test: fermare i server (anche `workerd`), cancellare `.wrangler/` e le cartelle dati temporanee.

## Comandi utili (produzione)

```bash
npx wrangler pages secret put ADMIN_PASSWORD --project-name basketsalgen
npx wrangler d1 execute basketsalgen-db --remote --command "SELECT k, length(v) FROM kv"
```
