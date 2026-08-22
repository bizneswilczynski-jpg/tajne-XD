# Prompt dla lokalnej sesji Claude Code

Skopiuj wszystko poniżej linii i wklej jako pierwszą wiadomość w Claude Code
uruchomionym lokalnie na Windowsie.

---

Pracujemy nad grą **+1 FART & FLY** na Roblox. Poprzednia sesja Claude'a działała
w chmurze i przygotowała cały projekt, ale nie miała dostępu do mojego komputera —
dlatego przenoszę się na lokal. Ty masz dostęp do mojego dysku i możesz odpalać
polecenia u mnie, więc dokończ to, czego tamta sesja nie mogła.

## Kontekst

- Repo: `https://github.com/bizneswilczynski-jpg/tajne-XD`
- Branch roboczy: **`claude/fart-fly-game-research-fg8ep7`** (pracuj i pushuj tylko tam)
- Mam Roblox Studio po polsku, wtyczka **Rojo 7.6.1** jest już zainstalowana
- Mam plik `C:\Users\bizne\Downloads\Keyboard Escape.rbxl` — to template, którego
  mechanikę chcę zrozumieć i ewentualnie coś z niej wziąć
- **Nie jestem techniczny.** Tłumacz krok po kroku, mów dokładnie co mam kliknąć,
  i nie zakładaj, że wiem czym jest PATH, terminal czy git.

## Co już jest w repo (nie pisz tego od nowa — najpierw przeczytaj)

- `docs/RESEARCH-plus-one-games.md` — research gatunku gier "+1"
- `README.md` — opis pętli rozgrywki i instrukcja uruchomienia
- `default.project.json` — mapowanie plików na drzewo Roblox
- `src/shared/Config.luau` — całe strojenie ekonomii (jedzenie, wystrzał, dieta)
- `src/shared/Format.luau` — skracanie dużych liczb
- `src/server/init.server.luau` — pętla główna: jedzenie AFK, PUK, lot, sława, dieta
- `src/server/World.luau` — mapa budowana z kodu (spawn, stołówki, pierścienie)
- `src/server/Data.luau` — DataStore + zarobek offline
- `src/client/init.client.luau` — HUD budowany z kodu

Projekt buduje się poprawnie (`rojo build` przechodzi), ale **nigdy nie był
uruchomiony w prawdziwym Studio.** Twoje główne zadanie to sprawdzić, czy to
faktycznie działa, i naprawić co nie działa.

## Zadanie 1 — uruchom to u mnie

1. Sprawdź czy mam zainstalowane `git` i `rojo` (`git --version`, `rojo --version`).
   Jeśli nie — przeprowadź mnie przez instalację. Rojo CLI **musi być w wersji 7.6.1**,
   żeby zgadzało się z moją wtyczką: `rojo-7.6.1-win64.zip` z
   https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1
2. Sklonuj repo i przełącz się na branch `claude/fart-fly-game-research-fg8ep7`.
3. Odpal `rojo serve` w katalogu repo (tam gdzie leży `default.project.json`).
4. Powiedz mi dokładnie co kliknąć w Studio: mam otworzyć **pusty Baseplate**
   (nie template!), wejść w **Dodatki plug-in → Rojo → Connect** na `localhost:34872`.
5. Każ mi wcisnąć **Play** i opisz mi, co powinienem zobaczyć. Poproś mnie o wklejenie
   zawartości okna **Output** (Wyświetl → Output), żebyś zobaczył błędy.

## Zadanie 2 — napraw to, co nie działa

Test przechodzi, jeśli:

- [ ] mapa się generuje: platforma spawnu, 6 kolorowych padów z jedzeniem, pierścienie w górze
- [ ] wejście na brązowy pad "Fasola" uruchamia licznik GAZ w lewym górnym rogu
- [ ] licznik rośnie o +1/s i pisze "MNIAM · Fasola"
- [ ] wciśnięcie **F** wystrzeliwuje postać w górę i zeruje gaz
- [ ] w locie widać wysokościomierz na górze ekranu
- [ ] po wylądowaniu dostaję SŁAWĘ proporcjonalną do wysokości
- [ ] pady z drogim jedzeniem są zablokowane, dopóki nie mam dość SŁAWY
- [ ] leaderstats pokazują SŁAWA i DIETA

Podejrzane miejsca, na które zwróć uwagę:
- wykrywanie stołówki raycastem w `foodUnderCharacter` (`src/server/init.server.luau`)
- wykrywanie lądowania — warunek `settled` może odpalać za wcześnie albo wcale
- czy pierścienie faktycznie się zaliczają (`trackFlight`)
- `Workspace.Gravity` jest ustawione na 120 w `default.project.json` — sprawdź czy lot
  nie jest zbyt wolny/szybki

Wszystkie liczby do strojenia są w `src/shared/Config.luau`. Nie rozsiewaj magic numbers
po logice.

## Zadanie 3 — prześwietl template

Otwórz i przeanalizuj `C:\Users\bizne\Downloads\Keyboard Escape.rbxl`.
To plik binarny, więc żeby go przeczytać jako tekst, poproś mnie o zapisanie go
w Studio jako **Plik → Zapisz jako → typ `.rbxlx`** (XML), albo użyj narzędzia
w stylu `lune` / `rbxlx-to-rojo`.

Chcę wiedzieć:
- jak zbudowana jest ta gra (struktura skryptów, co jest po stronie serwera a co klienta)
- jakie mechaniki są warte skopiowania do naszej gry
- czy jest tam system stref/checkpointów, sklep, pety — i jak są zrobione

Zrób z tego krótkie podsumowanie i zapisz w `docs/RESEARCH-template.md`.

## Zasady pracy

- Commituj po każdym działającym kroku, pushuj na `claude/fart-fly-game-research-fg8ep7`
- Nie zakładaj, że coś działa, dopóki tego nie zobaczyłem na ekranie — pytaj mnie
  o potwierdzenie i o Output ze Studio
- Pisz do mnie po polsku
- Kod i komentarze w kodzie bez polskich znaków diakrytycznych (Studio potrafi je zjeść)
