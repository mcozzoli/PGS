# Release iOS via GitHub Actions

La build e il caricamento su TestFlight avvengono interamente in cloud (runner
macOS di GitHub), usando la **App Store Connect API key** — nessun Mac locale,
nessuna password Apple, nessun 2FA.

## Segreti da impostare nel repo

`Settings → Secrets and variables → Actions → New repository secret`:

| Secret | Valore | Dove trovarlo |
|---|---|---|
| `ASC_KEY_ID` | `DMCHU59LGR` | nome del file `AuthKey_DMCHU59LGR.p8` |
| `ASC_ISSUER_ID` | *(UUID)* | App Store Connect → Users and Access → Integrations → App Store Connect API (in alto, "Issuer ID") |
| `ASC_KEY_P8` | contenuto del `.p8` **in base64** | vedi sotto |
| `APPLE_TEAM_ID` | *(10 caratteri)* | Apple Developer → Membership details → Team ID |

### Generare `ASC_KEY_P8` (base64 del file .p8)

Il file `appkey/AuthKey_DMCHU59LGR.p8` **non è versionato** (escluso in `.gitignore`).
Convertilo in base64 e incolla il risultato nel secret `ASC_KEY_P8`:

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("appkey\AuthKey_DMCHU59LGR.p8"))
```

```bash
# macOS / Linux
base64 -i appkey/AuthKey_DMCHU59LGR.p8
```

## Avviare una release

- **Automatica**: crea e pusha un tag, es. `git tag v1.0.0 && git push origin v1.0.0`.
- **Manuale**: tab *Actions → iOS TestFlight → Run workflow*.

Il workflow:
1. compila la parte Flutter,
2. registra l'app `it.pgssalgen.pgs` su App Store Connect se non esiste (`fastlane produce`),
3. firma in automatico con la API key (`-allowProvisioningUpdates`),
4. archivia e carica su **TestFlight**.

## Note

- Il **bundle id** è `it.pgssalgen.pgs` (modificabile in `ios/Runner.xcodeproj` e in `ios/fastlane/Appfile`).
- Al primo run la firma automatica crea certificati/profili sul team indicato:
  assicurati che `APPLE_TEAM_ID` sia corretto e che la API key abbia ruolo
  **Admin** o **App Manager**.
- Per la pubblicazione sullo Store (non solo TestFlight) servono scheda prodotto,
  privacy e screenshot su App Store Connect: si aggiunge poi una lane `release`
  con `upload_to_app_store`.
