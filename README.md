# +1 FART & FLY

Gra typu **"+1"** na Roblox. Gracz je na AFK, ładuje GAZ, a potem wystrzeliwuje się
w górę jednym PUKIEM. Im dłużej jadł — tym wyżej leci.

Research gatunku: [`docs/RESEARCH-plus-one-games.md`](docs/RESEARCH-plus-one-games.md)

## Pętla rozgrywki

```
  stoisz na stołówce  →  +GAZ/s (AFK, działa też offline do 8h)
            ↓
  [F] PUK  →  wydajesz CAŁY gaz  →  wystrzał w górę
            ↓
  łapiesz pierścienie w locie  →  +10% do wyniku za każdy
            ↓
  apogeum lotu  →  SŁAWA ⭐
            ↓
  SŁAWA odblokowuje mocniejsze jedzenie  ─┐
  SŁAWA płaci za DIETĘ (rebirth) → x2 do wszystkiego
            ↓
  pętla od nowa, szybciej
```

**Jedzenie:** Fasola (+1/s) → Kapusta (+5/s) → Jajko (+25/s) → Kebab (+120/s) →
Mleko po terminie (+600/s) → Żurek z zeszłego roku (+3000/s)

## Uruchomienie

Wersja CLI musi zgadzać się z wtyczką w Studio — projekt jest przypięty do **Rojo 7.6.1**
(`rokit.toml`), tak jak Twój plugin.

### Instalacja CLI (Windows)

Najprościej — pobierz `rojo-7.6.1-win64.zip` z
[releases](https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1), rozpakuj `rojo.exe`
i dodaj jego folder do `PATH`.

Albo przez menedżer wersji (wtedy wersja pilnuje się sama z `rokit.toml`):

```bash
rokit install
```

### Codzienna praca

```bash
git pull
rojo serve
```

W Studio: otwórz **pusty Baseplate** → zakładka **Dodatki plug-in** → **Rojo** →
adres `localhost`, port `34872` → **Connect**. Kod wjeżdża do miejsca i od tej pory
synchronizuje się na żywo przy każdym zapisie pliku.

Nie musisz nic stawiać ręcznie — mapa (spawn, stołówki, pierścienie, tabliczki
wysokości) buduje się z kodu przy starcie serwera. Wciśnij **Play** i działa.

> Jeśli po Connect drzewo jest puste, sprawdź czy `rojo serve` startuje w katalogu repo
> (tam gdzie leży `default.project.json`).

Alternatywnie, bez live-sync:

```bash
rojo build --output FartFly.rbxl
```

i otwórz `FartFly.rbxl` w Studio.

## Struktura

```
default.project.json     mapowanie plików na drzewo Roblox
src/
  shared/
    Config.luau          CAŁE strojenie ekonomii — zacznij tu przy balansowaniu
    Format.luau          skracanie liczb (1.2K, 3.4M, 1.1B)
  server/
    init.server.luau     pętla główna: jedzenie, lot, słava, dieta
    World.luau           budowa mapy z kodu
    Data.luau            zapis/odczyt DataStore + offline earnings
  client/
    init.client.luau     HUD budowany z kodu (bez ręcznych GUI w Studio)
```

## Balansowanie

Wszystkie liczby siedzą w `src/shared/Config.luau`. Nie ma magic numbers w logice —
żeby przestroić grę, nie ruszasz kodu gameplayu.

Najważniejsze pokrętła:

| Co | Gdzie |
|---|---|
| tempo jedzenia i progi odblokowań | `Config.Foods` |
| siła wystrzału | `Config.Launch` (skala logarytmiczna) |
| ile pierścieni i jak wysoko | `Config.Rings` |
| koszt i mnożnik diety | `Config.Rebirth` |
| limit zarobku offline | `Config.OFFLINE_CAP_SECONDS` |

## Uwagi techniczne

- Stan gracza jedzie do klienta **atrybutami** (`Gas`, `Rate`, `Fame`, ...) — replikują
  się same, więc HUD nie potrzebuje własnego kanału sync.
- Wykrywanie stołówki to **raycast w dół**, nie `Touched` — nie gubi się przy staniu
  w miejscu przez godziny, co przy grze AFK jest krytyczne.
- `Data.luau` to świadomie minimalna warstwa zapisu. Przy realnym ruchu podmień na
  ProfileStore (session locking, retry, migracje).
- W Studio DataStore jest wyłączony — profile startują puste przy każdym Play.
