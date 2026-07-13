# Monica Key

Native Android tidslinje, live-posisjon, ETA, chat og lyd mellom Pippi og Monica. Ingen Google Maps, Firebase, Google-konto eller Play Services.

## Det som virker i MVP-en

- Native Kotlin/Android-app med lokal SQLite-tidslinje.
- Foreground location service med synlig Android-varsel.
- Live-posisjon kryptert med AES-256-GCM før den forlater telefonen.
- Monicas telefon genererer og lagrer den eneste ECDSA-revokasjonsnøkkelen.
- Pippis app har ingen revokasjonsfunksjon. Den kan bare stoppe loggingen.
- Dynamisk ETA til Monicas leilighet for gange, sykkel, bil og kollektiv.
- Samme ETA vises på begge telefonene.
- Ende-til-ende-kryptert tekstchat.
- Kryptert toveis lydprototype.
- GPX- og GeoJSON-eksport.
- Romantisk mørkt grensesnitt med prestekrager, hjerte og nøkkel.
- Egen blind Go/WebSocket-relay som ikke har datanøkkelen.

## Kryptografisk modell

Invitasjonen inneholder kanal-ID, AES-datanøkkel og en engangs claim-hemmelighet. Når Monica åpner den:

1. Monicas telefon genererer et ECDSA P-256-nøkkelpar.
2. Bare offentlig nøkkel sendes til relayen.
3. Relayen destruerer claim-hemmeligheten og låser kanalen.
4. Privat revokasjonsnøkkel blir kryptert lokalt med Android Keystore.
5. En permanent revokasjon aksepteres bare med gyldig signatur fra Monicas telefon.

Relayen ser kanal-ID, tilkoblingsmetadata og størrelsen/tidspunktet på pakker. Den ser ikke koordinater, hjem, meldinger, lyd eller ETA-innhold.

## Bygg APK fra Termux via GitHub

```bash
pkg install -y git gh

gh auth login

curl -fsSL \
  https://raw.githubusercontent.com/bspippi1337/blckswan/agent/monica-key-live/monica-key/github-build-termux.sh \
  | bash
```

Skriptet starter GitHub Actions, følger bygget, henter APK-artifact og installerer lokalt med `su -c pm install -r` når root finnes.

## Start relay på egen server

```bash
git clone -b agent/monica-key-live https://github.com/bspippi1337/blckswan.git
cd blckswan/monica-key
export MONICA_KEY_DOMAIN=din.domain.no
docker compose up -d --build
```

Caddy henter TLS-sertifikat automatisk når domenet peker til serveren og port 80/443 er åpne. Sett appens serveradresse til `https://din.domain.no`.

For ren LAN-test kan relayen kjøres direkte:

```bash
cd server
go mod tidy
go run .
```

Standardadressen i appen er foreløpig `http://192.168.43.191:4242`.

## Viktige MVP-begrensninger

- ETA er kontinuerlig beregnet lokalt fra avstand og observert fart. Neste routing-lag kobler til egen Valhalla/GraphHopper-instans for faktisk vei- og kollektivruting.
- Lyd bruker kryptert PCM over relay i første versjon. Neste lydlag blir Opus/WebRTC med egen TURN.
- Kartbakgrunn er ikke lagt inn ennå. Live- og tidslinjedata er klare for MapLibre med egen OSM/PMTiles-kilde.
- Android-systemets appstopp, tillatelsesstyring og avinstallasjon kan naturligvis ikke fjernes av en app.

## Mappeoversikt

- `app/` native Android-klient.
- `server/` blind Go/WebSocket-relay.
- `docker-compose.yml` relay + Caddy/TLS.
- `github-build-termux.sh` GitHub-bygg og installasjon fra Termux.
- `build-termux.sh` eksperimentelt lokalt Termux-bygg.
