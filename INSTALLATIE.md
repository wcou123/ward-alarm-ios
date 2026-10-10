# Eerste installatie en proef

Voor een gewone iPhone met iOS 26.6.1. Er is geen jailbreak nodig. Een gratis
Apple-account volstaat voor de voorgestelde route. Vul je Apple-wachtwoord en
verificatiecode alleen in de installatieapp in; zet ze nooit in de broncode.

## 1. SideStore voorbereiden

1. Installeer [LocalDevVPN uit de Belgische App Store](https://apps.apple.com/be/app/localdevvpn/id6755608044) op de iPhone. De app is gratis.
2. Verbind de iPhone met wifi. Deze wifi hoeft niet die van de computer te zijn voor latere vernieuwing.
3. Installeer [iloader voor Windows](https://iloader.app/) op de computer. Windows heeft ook de Apple-toesteldriver nodig; de SideStore-handleiding noemt iTunes of Apple Devices. Verwijder geen bestaande Apple-installatie zonder eerst te controleren welke nodig is.
4. Sluit de iPhone met USB aan, ontgrendel hem en kies **Vertrouw** als de iPhone dat vraagt.
5. Open iloader en meld je aan met het gratis Apple-account. Bevestig de Apple-verificatiecode op je eigen toestel.
6. Gebruik voor iOS 26.6.1 de actuele officiële SideStore-versie die iOS 26.4+ ondersteunt. De [foutengids](https://docs.sidestore.io/docs/troubleshooting/error-codes) verwijst voor 26.4+ bij VPN-fouten naar **Nightly**. Oude versies tot en met 0.6.4 hebben bovendien bekende aanmeldproblemen. Gebruik de officiële versie via iloader of de [officiële Nightly-release](https://github.com/SideStore/SideStore/releases/tag/nightly), geen willekeurige downloadsite.
7. Controleer in iloader **Manage Pairing File** dat het koppelbestand bij SideStore geplaatst is. Bij 26.4+ kan een nieuwe koppeling nodig zijn; volg de aanwijzingen van de actuele installer.

De Nightly-versie is een testversie. We bevestigen de compatibiliteit pas na een
werkende installatie en vernieuwing op het toestel.

## 2. Vertrouwen en ontwikkelaarsmodus

1. Op de iPhone: **Instellingen → Algemeen → VPN en apparaatbeheer**.
2. Open de ontwikkelaarsapp onder je Apple-account en kies **Vertrouw** of **Sta toe en herstart**.
3. Ga naar **Instellingen → Privacy en beveiliging → Ontwikkelaarsmodus**, schakel die in en bevestig de herstart.
4. Open LocalDevVPN en kies **Connect**. Sta het VPN-profiel toe wanneer daarom wordt gevraagd.
5. Open SideStore en meld je aan met hetzelfde Apple-account.
6. Vernieuw eerst SideStore zelf in **My Apps**. Controleer dat de geldigheid weer **7 DAYS** aangeeft en de app opnieuw opent.

Deze stappen volgen de [officiële installatiehandleiding](https://docs.sidestore.io/docs/installation/install).

## 3. Onze alarmapp installeren

Na een geslaagde GitHub-build staat `BeutAlarm.ipa` bij de releases van het
app-project. Een broncodebestand of een ongesigneerde IPA kan op zichzelf niet
als gewone App Store-app geopend worden.

1. Download `BeutAlarm.ipa` op de iPhone en open het bestand met SideStore, of gebruik de plusknop bij **My Apps**.
2. Laat SideStore het bestand ondertekenen en installeren terwijl wifi en LocalDevVPN actief zijn.
3. Behoud de app-extensie als SideStore vraagt om extensies te verwijderen; **BeutAlarmWidgets** verzorgt de weergave van het volgende alarm.
4. Open **BeutAlarm** en geef toestemming voor alarmen.
5. Druk op **Test Windows-alarmgeluid**. Laat de geluidstest minstens 90 seconden spelen. Controleer dat het Windows-geluid heel stil begint en geleidelijk luider wordt en na minuut één luid blijft; stop met **Stop testgeluid**.

## 4. Alarmproef op een vergrendelde iPhone

1. Druk op **Test alarm over 10 seconden**.
2. Vergrendel onmiddellijk de iPhone met de zijknop.
3. Controleer dat er een systeemalarm verschijnt én het Windows-geluid klinkt. Laat het minstens 90 seconden spelen en controleer dat de opbouw één keer gebeurt en na minuut één luid blijft, ook met vergrendeld scherm. Controleer apart dat stoppen vóór 60 seconden ook het toekomstige luide vervolg annuleert. Meld afkappen, terugvallen op een ander geluid of ongewenste herhaling afzonderlijk.
4. Stop het alarm en open de app. Het testalarm moet uit het overzicht verdwijnen.
5. Maak twee normale alarmen. Controleer dat beide zichtbaar blijven, alleen hun tijdstippen getoond worden en **Verwijder → Annuleer** niets verwijdert.
6. Verwijder één alarm en bevestig. Het andere alarm moet blijven staan.
7. Test daarna een langer alarm terwijl de app op de achtergrond staat. Controleer ook de gewenste bel-/Focus-instellingen.

Deze proeven zijn nog niet uitgevoerd. Een geslaagde geluidstest alleen bewijst
niet dat een later systeemalarm afgaat.

## 5. Overzicht en eerstvolgende alarm controleren

1. Open BeutAlarm. **Actieve alarmen** moet meteen onder de titel staan, boven de instelknoppen.
2. Maak een alarm binnen drie uur. Laat **Toon eerstvolgende alarm op toegangsscherm** aan.
3. Vergrendel de iPhone en controleer het tijdstip op het toegangsscherm en in de Dynamic Island. Bij uitgeschakelde live activiteiten: Instellingen → Apps → BeutAlarm → Live activiteiten.
4. Voeg een vroeger alarm toe; de weergave moet dat tijdstip tonen. Verwijder het met bevestiging; de weergave moet terugkeren naar het andere alarm.
5. Voer de tiensecondenproef uit terwijl het drie-uursalarm blijft staan. Na Stop op het systeemalarm moet de volgende weergave het drie-uursalarm tonen.
6. Verwijder het laatste alarm; de aparte weergave moet verdwijnen. Schakel de weergave apart uit en controleer dat de ingestelde alarmen blijven staan.

Apple beperkt de actieve Live Activity tot maximaal acht uur; daarna kan zij nog
maximaal vier uur op het toegangsscherm blijven. Open BeutAlarm om de weergave
opnieuw te starten. Het eigenlijke AlarmKit-alarm blijft onafhankelijk ingesteld.
De weergave markeert een verstreken alarmtijd als **Alarmtijd bereikt** wanneer
de app niet heeft kunnen bijwerken. Het gedrag op de fysieke iPhone is nog niet
bevestigd door een build of simulatortest.

## 6. Vernieuwen zonder computer

1. Ontkoppel USB en zet de installatiecomputer uit of verbreek zijn netwerkverbinding.
2. Verbind de iPhone met een ander wifinetwerk en schakel LocalDevVPN in.
3. Vernieuw SideStore én BeutAlarm vanuit **My Apps**.
4. Controleer opnieuw **7 DAYS**, dat beide apps openen en dat ingestelde alarmen nog in het overzicht staan.
5. Herhaal het testalarm met vergrendeld scherm na de vernieuwing.

SideStore beschrijft achtergrondvernieuwing en biedt een actie **Refresh All
Apps** in Opdrachten. Na een geslaagde handmatige proef kan een persoonlijke
automatisering die actie regelmatig uitvoeren, bijvoorbeeld dagelijks bij het
opladen. Laat die eerst een keer werkelijk uitvoeren en controleer de nieuwe
vervaldatum. De huidige actie kan bij een te lange uitvoering vragen om de app
op de voorgrond te openen; volledige automatisering is daarom geen bewezen
garantie. Houd ook SideStore zelf binnen zijn zevendaagse geldigheid.

Als Tailscale of een andere VPN op de iPhone gebruikt wordt, controleer het
wisselen naar LocalDevVPN en terug. Een koppelbestand kan na een iOS-update of
herstel opnieuw nodig zijn; volg dan de [officiële koppelhandleiding](https://docs.sidestore.io/docs/advanced/pairing-file).

## Geraadpleegde bronnen

- [SideStore: gewone iPhone zonder jailbreak](https://sidestore.io/).
- [SideStore: vereisten en Windows-driver](https://docs.sidestore.io/docs/installation/prerequisites).
- [SideStore: installatie](https://docs.sidestore.io/docs/installation/install).
- [SideStore: iOS 26.4+ en foutcodes](https://docs.sidestore.io/docs/troubleshooting/error-codes).
- [SideStore: aanmeldherstel in 0.7.0-alpha](https://github.com/SideStore/SideStore/releases/tag/0.7.0-alpha).
- [iloader: officiële gratis installer](https://iloader.app/).
- [SideStore: werking en zevendaagse vernieuwing](https://docs.sidestore.io/docs/faq).
- [SideStore: vernieuwingsactie](https://github.com/SideStore/SideStore/blob/6032424a0e56c1c319762e786099bdd9186a238b/AltStore/Intents/App%20Intents/RefreshAllAppsIntent.swift).
- [Tailscale: beperkingen met andere VPN's](https://tailscale.com/docs/reference/faq/other-vpns).
