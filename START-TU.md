# Rychle nastavenie

## Monitor na pozadi a automaticky po prihlaseni

1. Rozbal vsetky subory do trvaleho priecinka, napr. `C:\SchoolInstallAlert`.
2. Prihlas sa do Windows uctu, ktory pouzivaju ziaci.
3. Dvojklik na **Enable-Autostart.cmd**. Nastavi ulohu v Task Scheduleri pre
   aktualny ucet a hned spusti monitor bez otvoreneho okna PowerShellu.
4. **Test-Voice.cmd** overi hlas. Zvuk ide do aktualne zvoleneho zariadenia;
   ak maju pripojene sluchadla, moze hrat v nich.
5. **Disable-Autostart.cmd** monitor zastavi a zrusi automaticke spustanie.

Po restarte sa spusti znova az po prihlaseni tohto uctu. Pre iny Windows ucet
treba nastavenie zopakovat. Nezapina sa pred prihlasenim. Prihlasenie do ineho
administratorskeho uctu pri instalacii nastavi ulohu pre tento iny ucet.
Ak vytvorenie ulohy blokuje skolska politika, treba pomoc spravcu.
Pri obmedzenych pravach monitor pouzije sledovanie nazvov procesov raz za
sekundu; velmi kratke procesy moze prehliadnut. Monitor neblokuje instalacie.

Priecinok potom nepresuvaj. Diagnostika a zaznamy su v
`%LOCALAPPDATA%\SchoolInstallAlert`. Uloha je viditelna v **Task Scheduler**
pod nazvom zacinajucim `SchoolInstallAlert-Student-`.

## Rusenie priameho stahovania EXE v Edge aj Chrome

1. V Edge otvor `edge://extensions`; v Chrome `chrome://extensions`.
2. Zapni **Developer mode / Rezim pre vyvojarov**.
3. Zvol **Load unpacked / Nacitat rozbalene rozsirenie**.
4. Vyber podpriecinok **Block-EXE-Downloads**, v ktorom je `manifest.json`.
5. Over, ze rozsirenie **School - block EXE downloads** je zapnute.
6. Zopakuj to v druhom prehliadaci a v kazdom profile, ktory ziaci pouzivaju.
7. Otestuj bezpecny EXE subor a PDF: EXE sa ma zrusit, PDF ma prejst.

Doplnok sa potom spusta spolu s prehliadacom. Nie je zavisly od PowerShellu.
Pre sukromne okna ho treba osobitne povolit. Iny/hostovsky profil bez
doplnku nie je chraneny. Test v skutocnom skolskom prehliadaci je potrebny.

**Dolezite:** ziaci maju admin prava, preto mozu doplnok aj monitor vypnut.
Doplnok kontroluje priponu nazvu, nie obsah suboru. EXE v ZIP archive,
premenovane subory, MSI instalatory, USB, ine programy a uz stiahnute subory
tym nie su blokovane. Cast dat alebo docasny subor moze vzniknut pred zrusenim.
Nejde o zaruku, ze sa do PC nedostane ziadny spustitelny subor.
Na vynutitelne pravidla treba bezne ziacke ucty a spravu cez skolske IT.

## Upozornenia aj na ucitelskom PC

Postup na zriadenie zdielaneho priecinka a dva prikazy pre automaticke
spustanie s prijmom upozorneni su v **README.md**. Bez nastaveneho zdieaneho
priecinka hovori len ziacky pocitac. Doplnok EXE rusenia zatial neposiela
upozornenia ucitelovi; monitor odosiela upozornenia na instalacnu aktivitu.

**Configure-BrowserDownloads.ps1** je dalsia, volitelna politika Edge/Chrome
pre rizikove stahovania; na bezne nastavenie monitora ani doplnku ju nepotrebujes.
Hodnota Risky neblokuje kazde EXE. Rezim All blokuje aj skolske dokumenty.
