# Alarm voor iPhone

Een eenvoudige native alarmapp voor iOS 26 of hoger, met Apples AlarmKit.

- Standaard: alarm binnen drie uur.
- Snelknoppen, een eigen duur of het volgende gekozen kloktijdstip.
- Meerdere onafhankelijke alarmen; een nieuw alarm komt erbij.
- Een overzicht met datum en tijdstip, zonder afteller.
- Verwijderen vraagt eerst bevestiging.
- Windows-alarmgeluid, een geluidstest en een echt testalarm over tien seconden.
- iOS beheert de alarmen; de app hoeft daarvoor niet op de voorgrond te blijven.

De eerste versie is bedoeld voor een proef op een fysieke iPhone. Een geslaagde
build of simulatortest bewijst nog niet dat installatie, geluid, alarmen met een
vergrendeld scherm en vernieuwing via SideStore op jouw toestel werken.

## Gratis bouwen

De workflow gebruikt uitsluitend een standaard `macos-26`-runner en weigert een
privérepository. Hij draait alleen na een handmatige start. Er worden geen
Actions-artifacts, betaalde runners, pakketten of buildcaches opgeslagen. Het
downloadbestand verschijnt als een GitHub prerelease na geslaagde tests en build.

Dit project heeft geen externe code-afhankelijkheden, Apple-inloggegevens,
ontwikkelcertificaten of betaalde ontwikkelaarsaccount nodig voor de build. De
cloud bouwt een **ongesigneerde** IPA; SideStore ondertekent hem op de iPhone met
je eigen gratis Apple-account. Ondertekenen en installatie zijn afzonderlijke
stappen en moeten nog op het toestel worden gecontroleerd.

Op een Mac met Xcode 26:

```sh
bash scripts/test-simulator.sh
bash scripts/build-unsigned.sh
```

## Installeren en controleren

Volg [INSTALLATIE.md](INSTALLATIE.md). SideStore heeft geen jailbreak nodig, maar
wel een eerste installatie via USB, ontwikkelaarsmodus, een Apple-account en de
lokale VPN. Gratis ondertekening blijft zeven dagen geldig; automatische
vernieuwing is pas bevestigd nadat een echte vernieuwingspoging is gecontroleerd.

## Werking

Elke druk op een alarmknop maakt een nieuwe UUID en een vaste AlarmKit-datum.
De app speelt geen stil achtergrondgeluid af om actief te blijven. Het overzicht
wordt vergeleken met de systeemalarmen en ontvangt wijzigingen vanuit AlarmKit.
De korte geluidstest gebruikt het gebundelde Windows-bestand; het echte alarm
gebruikt datzelfde bestand via AlarmKit. Een gestopt eenmalig alarm verdwijnt uit
het systeemoverzicht. Mislukte annulering verwijdert geen lokaal alarmrecord.

De tijden gebruiken de actuele toestelzone. Een alarm voor een bepaalde duur is
een vast ogenblik en verschuift niet bij een tijdzonewijziging. Bij een dubbel
kloktijdstip door wintertijd kiest de app de eerstvolgende toekomstige
voorkomst; bij een ontbrekend tijdstip door zomertijd behoudt hij de minuten.

## Bronnen

- [Apple: AlarmKit en systeemalarmen](https://developer.apple.com/videos/play/wwdc2025/230/).
- [Apple: AlarmManager](https://developer.apple.com/documentation/alarmkit/alarmmanager).
- [GitHub: gratis standaard-runners voor openbare repositories](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- [SideStore: geen jailbreak nodig](https://sidestore.io/).
- [SideStore: installatievereisten](https://docs.sidestore.io/docs/installation/prerequisites).

`windows-alarm.wav` is de Windows-opname `Alarm01.wav`; SHA-256:
`46c758f03534be1a2247413e7e5d92bcfdae1986f8f7f9fcaeabd3a72d131a2b`.
Die bestaande opname is geen nieuw gecomponeerd of vrijgegeven audiowerk.
