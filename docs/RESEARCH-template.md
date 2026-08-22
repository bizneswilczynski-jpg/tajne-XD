# Prześwietlenie template'u `Keyboard Escape.rbxl`

Analiza wykonana na żywym miejscu otwartym w Roblox Studio (odczyt drzewa gry i źródeł
241 skryptów). Nie było potrzeby eksportu do `.rbxlx`.

> **Uwaga na wstępie.** To nie jest czysty template ze sklepu. Nazwy zmiennych w większości
> modułów wyglądają tak: `local u1 = {}`, `function u12(p9)`, `local v34 = ...`. To jest
> **kod po dekompilacji** — czyli zrzut cudzej opublikowanej gry, z którego odzyskano
> logikę, ale utracono oryginalne nazwy. Ma to trzy konsekwencje, które opisuję w sekcji 7:
> ryzyko prawne, nieczytelność i zaszyte w środku cudze ID monetyzacji.

---

## 1. Czym jest ta gra

**Obby (tor przeszkód) połączone z grą typu "+1".** Gracz biegnie przez 15 etapów,
a każdy krok daje mu XP. XP podnosi poziom, poziom podnosi `WalkSpeed`. Im szybszy gracz,
tym szybciej pokonuje kolejne etapy i tym szybciej zdobywa kolejne XP.

Pętla domyka się dwoma walutami:

| Waluta | Skąd | Na co |
|---|---|---|
| **Speed / XP** | za każdy krok i za stanie na bieżni | poziom → `WalkSpeed` |
| **Wins** | dotknięcie `WinBlock` na końcu etapu (150 000 za sztukę) | checkpointy, ślady (trails) |
| **Rebirths** | reset postępu po osiągnięciu progu poziomu | trwały mnożnik do całego XP |

To jest dokładnie ta sama kość, co w naszym `+1 FART & FLY`: waluta pasywna → próg →
reset za mnożnik. Różnica jest taka, że tam pasywność jest ukryta pod bieganiem,
a u nas pod jedzeniem.

---

## 2. Architektura plików

```
ServerScriptService/
  Game/Core/
    MainServer            26 linii   ustawia WalkSpeed po respawnie
    LeaderstatsHandler    43 linie   leaderstats + autosave co 60 s
    RemoteHandler        315 linii   CAŁA logika serwera (XP, rebirth, sklep, trails)
    WinHandler            66 linii   WinBlock -> Wins -> teleport na spawn
    ProductHandler        65 linii   ProcessReceipt (Robux)
  DataService/
    DataHandler           86 linii   jeden DataStore, jeden klucz na gracza

ReplicatedStorage/
  Config               659 linii   cała ekonomia w jednym module
  EventsConfig                     osobna ekonomia eventu sezonowego
  ClientState                      lokalna kopia danych gracza
  NotificationSystem               popupy "+1"
  Remotes/                         ~75 RemoteEventów

StarterPlayer/StarterPlayerScripts/
  v3/                    14 LocalScriptów — cała rozgrywka po stronie klienta
  Pièges/                 7 LocalScriptów — pułapki i NPC (nazwy po francusku)
  Key/                    3 wersje "KeySystem" obok siebie
```

**Wniosek numer jeden:** cała ekonomia siedzi w jednym module `Config`, a cała logika
serwera w jednym `RemoteHandler`. My mamy dokładnie ten sam podział (`Config.luau` +
`init.server.luau`) i to się broni — przy tej skali nie ma sensu rozbijać na więcej plików.

---

## 3. Pętla rozgrywki — jak faktycznie działa

### Krok gracza = XP

`StepDetectionSystem` to **LocalScript**. Na każdym `Heartbeat` sprawdza, czy postać się
porusza, i jeśli minął cooldown, wysyła `UpdateSpeed:FireServer("Walking")`.

Sprytne jest to, że **cooldown skaluje się z prędkością**:

```
XP_TIME_BASED = { MIN_SPEED = 10, MAX_SPEED = 100, MIN_COOLDOWN = 0.1, MAX_COOLDOWN = 0.25 }
```

Wolny gracz dostaje +1 co 0,25 s, szybki co 0,1 s. Czyli prędkość daje podwójną korzyść:
szybciej biegniesz **i** częściej kapie. To dobra sztuczka — nagroda za progres jest
odczuwalna dwa razy.

### Bieżnie (treadmille) = AFK

`TreadmillSystem` robi **raycast 7 studów w dół** i sprawdza tagi na trafionej części:

```lua
workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
-- tag "AdminTreadmill" / "CandyTreadmill" / "DiamondTreadmill" / "GoldTreadmill" / "Treadmill"
```

To jest **dokładnie ten sam mechanizm, którego użyliśmy w naszych stołówkach** (raycast w dół
+ `CollectionService`). Niezależne potwierdzenie, że to właściwe podejście — pewniejsze niż
`Touched`, nie gubi się przy staniu w miejscu godzinami.

Bieżnie mają mnożniki: zwykła ×1, złota ×3, diamentowa ×9, cukierkowa ×25, admin ×50 000 000.
Dostęp do lepszych to gamepassy za Robuxy.

### Wygrana etapu

`WinHandler` łapie `Touched` na każdej części, której nazwa zawiera `WinBlock`,
daje 150 000 Wins z debounce 3 s i teleportuje gracza na spawn.

---

## 4. Ekonomia w liczbach

**Poziom i prędkość:**
```
WalkSpeed = 10 + poziom * 2, maksymalnie 300
XP na poziom = 100 * 1.15^(poziom-1)   -- wykładniczo
```

**Rebirthy** — 20 progów, mnożnik rośnie brutalnie na końcu:

| Poziom | Mnożnik |
|---|---|
| 15 | ×1,5 |
| 100 | ×4 |
| 200 | ×10 |
| 225 | ×100 |
| 300 | ×10 000 |
| 600 | ×100 000 000 000 |

**Ślady (trails)** — kupowane za Wins, dają mnożnik do XP:

| Ślad | Cena (Wins) | Mnożnik |
|---|---|---|
| Zielony | 500 | ×1,5 |
| Tęczowy | 100 000 | ×5 |
| Kosmiczny | 5 mln | ×100 |
| Void | 50 mln | ×1 000 |
| Godlike | 5 mld | ×100 000 |
| Infinity | tylko gamepass | ×5 000 000 |

**Odznaki kroków (Step Awards)** — 8 pomników w świecie, każdy podnosi bazę z 1 do 500 XP
za krok, odblokowywane liczbą Wins (0 / 3 / 15 / 100 / 500 / 2500 / 15 000 / 50 000).
Fizyczny obiekt w świecie zmienia kolor: szary = zablokowany, zielony = dostępny,
żółty = założony. **To jest bardzo dobry pomysł do skopiowania** — progres widać w świecie,
nie w menu.

**Monetyzacja:** 12 poziomów gamepassów mnożnika prędkości (×2 do ×4096, od 3 do 1375 Robux),
6 dev productów na XP (150 K → 1 mld), 3 na natychmiastowy rebirth, 13 checkpointów
kupowanych za Wins **albo** za Robux, plus osobno „pomiń etap".

---

## 5. Strefy, sklep, pety — odpowiedzi wprost

### Strefy — TAK
`Workspace.Structure` zawiera `Stage0_HUB` oraz `Stage1`..`Stage15`. To zwykłe foldery
z geometrią, nie ma żadnego systemu stref w kodzie — etapy istnieją tylko jako nazwy.
Powiązanie z logiką idzie przez:
- `Config.CHECKPOINTS` — lista nazw etapów z cenami,
- tagi `ButtonTpCheckpoint1..13` na przyciskach UI,
- `RequestCheckpointTp` — serwer pobiera cenę i teleportuje.

Dodatkowo jest `SpaceZoneEnter` / `SpaceZoneLeave` (strefa o innej grawitacji) i
`EventRSVPzone`. Strefy eventowe są tagowane, nie zaszyte w kodzie.

### Sklep — TAK, cztery osobne
`ShopModal`, `TrailsModal`, `CheckpointModal`, `EventCurrencyModal` — wszystkie jako gotowe
`ImageLabel` w `StarterGui`, otwierane przez `ClientState:ToggleModal()`. Zakup idzie przez
`RemoteFunction` (`BuyTrail`) który zwraca `true` albo `false, "Not enough Wins"`.
**To jest dobry wzorzec** — klient dostaje powód odmowy i może go pokazać.

### Pety — NIE MA
Przeskanowałem wszystkie 241 skryptów i nazwy wszystkich obiektów. Jedyne trafienie na
„pet" to `PuppetHead` (głowa modelu NPC) — fałszywy alarm. **W tej grze nie ma petów.**
Ich rolę — kolekcjonowalny mnożnik z rosnącą rzadkością — pełnią **trails**. Jeśli chcesz
petów w naszej grze, ten template nie da Ci wzorca; da za to gotowy wzorzec na
kolekcjonowalne mnożniki, co jest tym samym mechanicznie, tylko taniej w produkcji
(ślad to `Trail` + `ColorSequence`, pet to model + animacje + AI podążania).

---

## 6. Co warto skopiować do +1 FART & FLY

1. **Cooldown skalowany prędkością** — u nas odpowiednikiem byłoby, żeby lepsze jedzenie
   nie tylko dawało więcej GAZU na tick, ale też tickowało częściej. Podwójna nagroda.
2. **Step Awards jako fizyczne pomniki** — 8 obiektów w świecie, zmieniają kolor
   (zablokowany / dostępny / założony). U nas: pomniki odblokowywane SŁAWĄ, dające mnożnik
   do GAZU. Progres widoczny bez otwierania menu.
3. **`RemoteFunction` na zakupy zamiast `RemoteEvent`** — zwracanie `false, "powód"`
   pozwala pokazać graczowi konkretny komunikat.
4. **Raycast + tagi do wykrywania stref** — potwierdzenie naszego podejścia; warto tak samo
   otagować przyszłe strefy zamiast trzymać listę w kodzie.
5. **Dwie waluty zamiast jednej** — u nich XP (miękka, do progresu) i Wins (twarda, do
   zakupów). U nas GAZ jest miękki, SŁAWA twarda — to już mamy, ale warto pamiętać,
   że oni dokładają za Wins **konkretne rzeczy do kupienia**, nie tylko rebirth.
6. **Checkpointy płatne dwiema drogami** — za walutę z gry **albo** za Robux. Ten sam
   przedmiot, dwie ścieżki. Nie blokuje gracza bez portfela, a niecierpliwym daje wyjście.

---

## 7. Czego NIE kopiować — realne błędy w tym kodzie

Znalazłem cztery poważne. Wypisuję je, bo łatwo je przenieść razem z dobrymi pomysłami.

### 7.1 DataHandler nadpisuje zapis gracza wartościami testowymi

W `DataService.LoadData`, **po** wczytaniu danych z DataStore:

```lua
finalData.TotalXP = 1000000000
finalData.SpeedBoostMultiplier = 1000000
finalData.AdminTreadmillActive = true
finalData.CandyTreadmillActive = true
finalData.DiamondTreadmillActive = true
finalData.GoldTreadmillActive = true
finalData.WinsMultiplier = 2
```

To leci **przy każdym wejściu każdego gracza**. Ktoś zostawił sobie tryb testowy i nie
usunął. Gdyby to opublikować, każdy gracz dostaje miliard XP i wszystkie płatne bieżnie
za darmo. Do tego zaraz niżej `OwnedTrails` i `Eggs` są ustawiane **trzy razy pod rząd**
z różnymi wartościami — zostaje ostatnia. To ślad po nieposprzątanym debugowaniu.

### 7.2 ProcessReceipt bez deduplikacji i bez zapisu

`ProductHandler` przyznaje towar i od razu zwraca `PurchaseGranted`, ale:
- nie sprawdza `PurchaseHistory`, choć takie pole istnieje w `DEFAULT_DATA`,
- **nie wywołuje `SaveData` po zakupie**.

Jeśli serwer padnie przed autosave (co 60 s), gracz traci to, za co zapłacił Robuxami.
Roblox ponowi `ProcessReceipt`, ale ponieważ nie ma deduplikacji, przy innym przebiegu
może przyznać dwa razy. U nas obowiązuje zasada: jeden `ProcessReceipt` w grze, zapis
natychmiast po przyznaniu, i sprawdzenie `PurchaseId` przed przyznaniem.

### 7.3 Teleport po zakupie checkpointu nie działa

Dwa miejsca (`ProductHandler` i `RemoteHandler`) robią:

```lua
local stagePart = workspace:FindFirstChild("Stages") and workspace.Stages:FindFirstChild(checkpoint.Name)
```

W `Workspace` **nie ma folderu `Stages`** — etapy leżą w `Structure`. Warunek zawsze
zwraca `nil`, teleport jest cicho pomijany. Gracz płaci Robuxami za checkpoint i nigdzie
nie zostaje przeniesiony. Klasyczna pułapka: `and` zamiast twardego błędu zamienia
literówkę w cichą awarię.

### 7.4 Serwer w ogóle nie waliduje XP

`Config` ma przygotowaną sekcję:

```lua
SECURITY = { MAX_SPEED_ALLOWED = 250, DISTANCE_MARGIN = 2, TELEPORT_COOLDOWN = 0.5, STATION_MARGIN = 20 }
```

...i **nigdzie nie jest używana**. `handleUpdateSpeed` przyjmuje od klienta dowolny string
i wypłaca XP:

```lua
if mode == "AdminTreadmill" then amount = 50000000 end
```

Nie ma sprawdzenia, czy gracz naprawdę stoi na bieżni, czy ma do niej dostęp, ani limitu
częstotliwości. Wywołanie `UpdateSpeed:FireServer("AdminTreadmill")` w pętli daje
50 milionów XP na wywołanie. Cała ekonomia gry jest do rozbrojenia jedną linijką.

**To jest dla nas bezpośrednia lekcja.** Nasz PUK też musiał trafić na klienta (bo serwer
nie ma władzy nad postacią gracza) — ale u nas serwer decyduje o wartości impulsu i przycina
zaliczoną wysokość do fizycznego sufitu `v²/2g`. Ta gra oddała klientowi *i* decyzję,
*i* kwotę.

---

## 8. Status prawny — przeczytaj zanim cokolwiek skopiujesz

1. Kod jest zdekompilowany (`u1`, `v2`, `p9`), czyli pochodzi ze zrzutu cudzej opublikowanej
   gry, a nie z licencjonowanego template'u. Kopiowanie go w całości to kopiowanie cudzej
   pracy.
2. W `Config` siedzą **konkretne ID gamepassów i dev productów** (np. `1674499710`,
   `3516546135`) należące do oryginalnego twórcy. Gdybyś zostawił je w swojej grze,
   pieniądze Twoich graczy szłyby **do niego**, nie do Ciebie.
3. `GROUP_ID = 1074557114` i `BADGE_IDS` to również cudze zasoby.
4. Assety (meshe, dźwięki, obrazy) są linkowane po `rbxassetid` — część może być prywatna
   albo zostać zdjęta, a wtedy przestaną się ładować.

**Rekomendacja:** traktuj ten plik jako **materiał do nauki mechanik**, nie jako bazę kodu.
Przepisz pomysły własnymi słowami do naszego `Config.luau`. To i tak wyjdzie szybciej niż
odplątywanie 241 skryptów z nazwami `u1`, `v2`, `p9` — a nasz projekt zostanie czytelny.

---

## 9. Podsumowanie jednym zdaniem

Dobra kopalnia pomysłów na strukturę progresu (dwie waluty, fizyczne pomniki jako progres,
cooldown skalowany prędkością, sklep zwracający powód odmowy) i podręcznikowy zbiór
tego, czego nie robić w warstwie danych i bezpieczeństwa (klient wypłaca sobie XP, zakupy
bez zapisu, tryb testowy zostawiony w produkcji).
