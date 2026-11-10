# Notifiche push su mobile — piano

Il portale web invia notifiche con **Web Push** (VAPID, RFC 8291 + aes128gcm),
gestite dal service worker del browser. Un'app nativa **non** può ricevere Web
Push: serve il canale nativo di ciascuna piattaforma.

## Cosa serve

- **Android** → Firebase Cloud Messaging (FCM).
- **iOS** → APNs (tramite FCM o diretto).

La via più semplice e uniforme è **Firebase Cloud Messaging** per entrambe,
con `firebase_messaging` lato app.

## Lavoro lato app (Flutter)

1. Aggiungere `firebase_core` + `firebase_messaging`, file `google-services.json`
   (Android) e `GoogleService-Info.plist` (iOS), capability Push su iOS.
2. Al login, richiedere il permesso e ottenere il **token FCM** del dispositivo.
3. Inviarlo al backend con un nuovo endpoint, es.
   `POST /api/push/subscribe-native { token, platform }`.

## Lavoro lato backend (basketsalgen)

Il backend oggi cifra i payload Web Push. Per il mobile va aggiunto l'invio FCM:

1. Nuova tabella/chiave per i token nativi (riusando lo schema iscrizioni).
2. Endpoint `POST /api/push/subscribe-native` e `.../unsubscribe-native`.
3. Dove oggi si invia la Web Push ("Si gioca", "Finale", nuovi messaggi bacheca),
   inviare **in parallelo** a FCM via HTTP v1 API (service account Google) agli
   stessi destinatari.
4. Secret Cloudflare per le credenziali del service account FCM.

> Finché questo step non è completato, l'app funziona in tutto il resto; le
> notifiche push restano quelle del portale web (PWA). Nell'app il punto di
> integrazione è previsto in `AppState` (metodo di registrazione token) + un
> avviso in Home/Profilo.
