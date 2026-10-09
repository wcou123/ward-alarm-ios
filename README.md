# BeutAlarm voor iPhone

Een eenvoudige native alarmapp voor iOS 26 of hoger, met Apples AlarmKit.

- Standaard: alarm binnen drie uur.
- Snelknoppen, een eigen duur of het volgende gekozen kloktijdstip.
- Meerdere onafhankelijke alarmen; een nieuw alarm komt erbij.
- Een overzicht met datum en tijdstip, zonder afteller.
- Verwijderen vraagt eerst bevestiging.
- Windows-alarmgeluid dat in 60 seconden van heel stil naar volle sterkte groeit, een geluidstest en een echt testalarm over tien seconden.
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
De geluidstest gebruikt hetzelfde gebundelde bestand als het echte alarm via
AlarmKit. Het Windows-geluid wordt herhaald met een in het audiobestand verwerkte
opbouw: van 1% sample-amplitude naar volle sterkte in exact 60 seconden. De curve
groeit gelijkmatig in decibels. Daarna gebruikt het alarm uitsluitend de volle
Windows-opname, zonder opnieuw een opbouw te starten. De geluidstest wisselt na
de opbouw naar een eindeloos herhaalde luide opname. Voor het systeemalarm worden
een opbouwfase en een luide vervolgfase op +60 seconden met AlarmKit gepland.
Samen vormen ze één alarm in het overzicht. Stoppen, ook op het vergrendelde
scherm, en bevestigd verwijderen annuleren beide fases; stoppen vóór minuut één
annuleert dus ook het nog geplande luide vervolg.
Daarvoor hoeft geen app-timer op de achtergrond te blijven draaien. De bestaande
bundle-ID blijft behouden, zodat dit als update over de vorige versie kan.

Controleer de audiobron en ieder gegenereerd sample met
`python3 scripts/render-gradual-sound.py --verify`. Apple documenteert de keuze
van een eigen geluid via `AlertConfiguration.AlertSound.named`; de volledige
60-secondenopbouw bij een vergrendeld scherm moet ook op de fysieke iPhone worden
gecontroleerd. Lokaal klopt het audiobestand; dit is geen bewijs voor de feitelijke
afspeelduur of eventuele herhaling door iOS.

Een gestopt eenmalig alarm verdwijnt uit het systeemoverzicht. Mislukte annulering verwijdert geen lokaal alarmrecord.

De interface volgt de lichte of donkere weergave van iOS met adaptieve kleuren.
Wanneer iOS het scherm dimt, kiest de app ook donkere inhoud; bij meer helderheid
volgt hij weer de systeemweergave. De grens gebruikt hysterese tegen flikkeren.
De app leest de iOS-helderheid, maar schrijft geen schermhelderheid voor.
Automatische helderheid op basis van
omgevingslicht blijft een systeeminstelling: Instellingen → Toegankelijkheid →
Weergave en tekstgrootte → Pas automatisch aan.

De tijden gebruiken de actuele toestelzone. Een alarm voor een bepaalde duur is
een vast ogenblik en verschuift niet bij een tijdzonewijziging. Bij een dubbel
kloktijdstip door wintertijd kiest de app de eerstvolgende toekomstige
voorkomst; bij een ontbrekend tijdstip door zomertijd behoudt hij de minuten.

## Bronnen

- [Apple: AlarmKit en systeemalarmen](https://developer.apple.com/videos/play/wwdc2025/230/).
- [Apple: AlarmManager](https://developer.apple.com/documentation/alarmkit/alarmmanager).
- [Apple: automatische helderheid en omgevingslicht](https://support.apple.com/nl-nl/109351).
- [Apple: een eigen geluidsbestand kiezen](https://developer.apple.com/documentation/activitykit/alertconfiguration/alertsound/named(_:)).
- [GitHub: gratis standaard-runners voor openbare repositories](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- [SideStore: geen jailbreak nodig](https://sidestore.io/).
- [SideStore: installatievereisten](https://docs.sidestore.io/docs/installation/prerequisites).

`scripts/windows-alarm-source.wav` is de oorspronkelijke Windows-opname `Alarm01.wav`; SHA-256:
`46c758f03534be1a2247413e7e5d92bcfdae1986f8f7f9fcaeabd3a72d131a2b`.
`WardAlarm/windows-alarm.wav` blijft de ongewijzigde luide opname.
`WardAlarm/crescendo-alarm.wav` is de afgeleide 60-secondenopbouw; de generator
bewaart de bron ongewijzigd. Die bestaande opname is geen nieuw gecomponeerd of
vrijgegeven audiowerk.
