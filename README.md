# Bílasafnið – Hot Wheels safnið mitt

Flutter-app til að halda utan um Hot Wheels bílana í safninu. Bílarnir eru
skráðir með hjálp [Hot Wheels Wiki](https://hotwheels.fandom.com), sem gefur
mynd og allar upplýsingar um bílinn sjálfkrafa. Svo er hægt að fletta í
gegnum safnið og skoða bílana.

## Hvað appið gerir

**Skrá bíl**
1. Leitað að nafninu sem stendur á bílnum (t.d. „Bone Shaker“). Leitin sýnir
   myndir svo auðvelt er að þekkja rétta bílinn.
2. Upplýsingar um bílgerðina birtast (hönnuður, framleiðsluár, fyrsta sería)
   og listi yfir **allar útgáfur** sem komið hafa út, nýjustu fyrst, með mynd,
   lit, seríu, skreytingu og felgum. Hægt er að sía eftir ári eða texta.
3. Valin er útgáfan sem passar við bílinn. Þá fyllist skráningarformið út
   sjálfkrafa og eftir er að velja ástand (laus / í pakkningu), fjölda eintaka,
   uppáhalds og athugasemdir.
4. Ef bíllinn er nú þegar í safninu býður appið að bæta frekar við eintaki.
5. Ef bíllinn finnst ekki á wiki er hægt að skrá hann handvirkt.

**Safnið**
- Tölur efst: fjöldi bíla, fjöldi gerða, uppáhalds og elsti bíllinn.
- Leit í safninu (nafn, ár, litur, sería …), síur (uppáhalds, í pakkningu,
  lausir) og röðun (nýjast skráð, nafn, árgerð).
- Smellt á bíl opnar hann í **sýningarham**: myndin flýgur úr bílskúrnum á
  upplýst svið sem fær lit sinn úr lakki bílsins, með spegilmynd á glergólfi.
  - Strjúka til hliðar til að fletta (líka með mús eða örvatökkum). Kortið
    hallar í þrívídd og liturinn á sviðinu breytist með fingrinum.
  - Ýta á myndina til að fela allt nema bílinn, ýta aftur til að fá allt til baka.
  - Tvísmella til að opna myndina eina: klípa til að súma og draga til að skoða.
  - ▶ spilar myndasýningu í gegnum safnið með hægum aðdrætti á hverja mynd.
  - Strjúka upp eða ýta á „Nánar“ til að sjá allar upplýsingar.
  - Myndir eru sóttar í hárri upplausn í sýningarham.
- Breyta, eyða (með „Afturkalla“), fjölga/fækka eintökum, setja í uppáhalds og
  opna síðu bílsins á Hot Wheels Wiki.

Safnið er vistað á tækinu sjálfu (`shared_preferences`) og myndir eru geymdar
í skyndiminni, svo það er hægt að skoða safnið án nettengingar.

## Prófa á netinu

Vefútgáfan er á **https://skaftisveins.github.io/my-hot-wheels/** og virkar
bæði í tölvu og síma. Í símanum er hægt að velja „Bæta á heimaskjá“ (Add to
Home Screen) og þá opnast hún eins og app.

Safnið er vistað í vafranum sem er notaður hverju sinni. Bílar sem skráðir eru
í símanum sjást því ekki í tölvunni og öfugt.

Vefurinn uppfærist sjálfkrafa í hvert sinn sem ýtt er á `main`
(`.github/workflows/deploy-pages.yml`). Á undan eru keyrðar prófanir og
greining, svo vefurinn uppfærist ekki ef eitthvað er bilað.

## Keyrsla

```bash
cd hot_wheels_safn
flutter pub get
flutter run            # á tengdum síma eða hermi
flutter test           # keyrir prófanir
```

Gert fyrir Android, iOS og vefinn. Prófað með Flutter 3.50 (Dart 3.14).

## Uppbygging

```
lib/
  main.dart, app.dart              ræsing, þema, AppScope (safnið + API)
  models/car.dart                  bíll í safninu
  models/casting.dart              bílgerð og útgáfur af wiki
  services/hot_wheels_wiki_api.dart   tenging við MediaWiki API (leit, síða, myndir)
  services/wikitext_parser.dart    les upplýsingaboxið og útgáfutöflurnar úr wikitexta
  data/collection_store.dart       safnið: vistun, leit, síun, röðun, tölfræði
  screens/                         safn, nánar (fletting), leit, útgáfur, skráning
  widgets/                         bílaspjald og mynd með skyndiminni
test/                              prófanir á parser, API (með gervineti), vistun og skjám
```

### Um API-tenginguna

Hot Wheels Wiki keyrir á MediaWiki og þarf engan API-lykil:

| Hvað | Fyrirspurn |
| --- | --- |
| Leit með smámyndum | `action=query&generator=prefixsearch` og `generator=search` með `prop=pageimages` |
| Upplýsingar um bíl | `action=parse&prop=wikitext`. Upplýsingaboxið `{{casting}}` og töflurnar með útgáfunum eru lesnar úr textanum |
| Myndir | `action=query&prop=imageinfo&iiurlwidth=500`, 50 myndir í hverri fyrirspurn |

Myndaþjónn wiki-sins hafnar myndum ef vafri sendir `Referer` frá annarri síðu.
Þess vegna er `<meta name="referrer" content="no-referrer">` í `web/index.html`.
Í símanum skiptir það ekki máli.

Gögnin á Hot Wheels Wiki eru skrifuð af söfnurum og gefin út undir
[CC BY-SA](https://www.fandom.com/licensing). Wiki-síðurnar í `test/fixtures`
eru þaðan.

## Hugmyndir fyrir seinna

- **Eigin myndir**: taka mynd af bílnum með myndavélinni (`image_picker`).
- **Skanna strikamerki** á pakkningunni til að finna bílinn beint.
- **Afrit og flutningur**: flytja safnið út/inn sem skrá, eða samstilla í skýið
  (t.d. Firebase) svo það tapist ekki ef síminn týnist.
- **Óskalisti**: bílar sem mann langar í, með áminningu í búðinni.
- **Seríur**: sýna hvaða bíla vantar til að klára seríu (t.d. 3 af 5 í „HW
  Dream Garage“).
- **Treasure Hunts / Super Treasure Hunts**: merkja sjaldgæfa bíla sérstaklega.
- **Leikir og tölfræði**: „bíll dagsins“, merki/verðlaun fyrir 10, 50 og 100
  bíla, gröf yfir liti og ár.
- **Kappakstursbraut**: skrá úrslit í kappakstri milli bíla í safninu.
- **Fleiri prófílar**, ef systkini eiga líka safn.
