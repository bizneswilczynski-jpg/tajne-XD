# Research: gry typu "+1" — fundament pod projekt **+1 FART & FLY**

## 1. O co chodzi w grach "+1"

Pod hasłem "gry +1" kryje się dziś konkretny, rozpoznawalny gatunek, który wypłynął na Robloxie
(a potem został skopiowany na mobile i web). Tytuły mówią wszystko:

| Gra | Twórca / status |
|---|---|
| `+1 Strong Every Second 💪` | ~115 mln zagrań |
| `+1 Jump Every Second 🚀` | ~97 mln zagrań |
| `Every second you get 1 Speed` | wariant "speed" |
| `+1 Block Every Second` | wariant z petami i rebirthami |
| `+1 Food / +1 Hot Every Second` | kolejne klony |

**Rdzeń gatunku:** gracz dostaje **+1 jednostkę statystyki co sekundę, tylko za to, że jest w grze**.
Nie ma umiejętności wejścia. Nie ma przegranej. Licznik po prostu rośnie, a wraz z nim rośnie to,
co gracz *może zrobić* w świecie gry.

## 2. Anatomia pętli rozgrywki

```
       ┌─────────────────────────────────────────┐
       │  1. TICK: +1 do statystyki co sekundę   │
       └────────────────────┬────────────────────┘
                            ▼
       ┌─────────────────────────────────────────┐
       │  2. FEEDBACK: liczba na HUD skacze,     │
       │     postać wizualnie rośnie / przyspiesza│
       └────────────────────┬────────────────────┘
                            ▼
       ┌─────────────────────────────────────────┐
       │  3. GATE: próg odblokowuje nowy obszar  │
       │     ("potrzebujesz 5 000, żeby wejść")  │
       └────────────────────┬────────────────────┘
                            ▼
       ┌─────────────────────────────────────────┐
       │  4. MULTIPLIER: nowy obszar daje +5/s,  │
       │     +25/s, +100/s... (skala wykładnicza)│
       └────────────────────┬────────────────────┘
                            ▼
       ┌─────────────────────────────────────────┐
       │  5. REBIRTH: reset licznika za trwały   │
       │     mnożnik → pętla od nowa, szybciej   │
       └─────────────────────────────────────────┘
```

Kluczowe: **gracz nigdy nie czeka bez nagrody**. Coś rośnie zawsze — nawet gdy odejdzie od
klawiatury. To idle/incremental w przebraniu gry akcji.

## 3. Dlaczego to działa (psychologia i dystrybucja)

1. **Zerowy próg wejścia** — tytuł gry *jest* tutorialem. "+1 Fart Every Second" tłumaczy
   całą mechanikę zanim gracz kliknie play.
2. **Natychmiastowa nagroda** — pierwszy "+1" pojawia się w ciągu sekundy od startu, nie po
   3 minutach intro.
3. **Widoczna progresja ciała** — postać rośnie / leci wyżej / zostawia większą chmurę.
   Gracz *widzi* swój postęp, nie tylko czyta liczbę.
4. **Skala wykładnicza** — przejście z 1/s na 1000/s daje dopaminowy skok, mimo że nic
   nowego się nie nauczyłeś.
5. **Porównywalność społeczna** — leaderboard i to, że inni gracze widzą twój rozmiar,
   napędza sesje.
6. **Format pod klipy** — 15-sekundowy klip "od 0 do kosmosu" to gotowy content na TikToka.
   Gatunek rozprzestrzenia się przez short-form video, nie przez marketing.
7. **Humor / brainrot** — absurdalna statystyka (fart, hot, food) jest tańszym haczykiem niż
   dobra grafika. Śmieszne > ładne.

## 4. Druga rodzina "+1": runnery z bramkami

Poboczny, ale spokrewniony nurt (Count Masters / Join Clash): gracz biegnie korytarzem i
przelatuje przez **bramki `+1`, `x2`, `-5`**, zbierając tłum / moc. Ta sama zasada — liczba
rośnie na ekranie, decyzja jest binarna (lewo/prawo) — ale jest tu przegrana i poziomy.

**Dla +1 FART & FLY warto wziąć z obu:** ciągły tick "+1" jako baza + bramki w locie jako
aktywny element skill/decyzji.

## 5. Standardowa monetyzacja gatunku

- 2x / 3x mnożnik (jednorazowy zakup, najlepiej sprzedający się item)
- Auto-collect / offline earnings
- Auto-rebirth
- Pety / skiny dające % boost
- Reklama z nagrodą: "obejrzyj = +60 sekund x5"
- Kody promocyjne (napędzają wyszukiwania i wideo poradniki = darmowy ruch)

## 6. Przełożenie na **+1 FART & FLY**

| Element gatunku | Nasza wersja |
|---|---|
| Statystyka rosnąca co sekundę | **+1 GAZ / s** — ciśnienie w brzuchu |
| Wydanie statystyki | **PUK** — wystrzał, który wybija gracza w górę |
| Widoczna progresja | wysokość lotu, wielkość chmury, głośność dźwięku |
| Bramki / progi | pułapy wysokości: Podłoga → Dach → Chmury → Stratosfera → Kosmos |
| Mnożniki | strefy dające +5/s, +25/s, +100/s |
| Rebirth | **"Dieta"** — reset gazu za trwały mnożnik (fasola, kapusta, kebab...) |
| Element skill | w locie łapiesz bramki `+1` / `x2`, unikasz `-5` (wiatraki, ptaki) |
| Social | leaderboard najwyższego lotu + przycisk share z GIF-em lotu |
| Humor | rdzeń tożsamości gry — dźwięk i absurd są główną atrakcją |

**Docelowa pierwsza sesja:** 0–5 s licznik rusza, 10 s pierwszy PUK, 60 s pierwszy nowy pułap,
3 min pierwszy rebirth. Jeśli gracz nie dostanie tych czterech momentów, pętla nie zaskoczy.

## 7. Rekomendacje techniczne

- **HTML5 / Canvas, mobile-first** — gatunek żyje z natychmiastowej dostępności, bez pobierania.
- **Save w `localStorage`** + liczenie offline earnings z timestampu.
- **Liczby jako `Number` z formatowaniem skrótowym** (1.2K, 3.4M, 1.1B) — gatunek szybko
  wchodzi w duże wartości; przy prawdziwym wykładniku rozważyć notację naukową.
- **Bez logowania na starcie** — pierwsza sesja musi ruszyć w 1 sekundę.
- Dźwięk: krótkie, warstwowane próbki + losowy pitch, żeby 500. puk nie brzmiał identycznie.

## Źródła

- [+1 Strong Every Second — Rolimon's](https://www.rolimons.com/game/11298617267)
- [+1 Jump Every Second — Rolimon's](https://www.rolimons.com/game/11988615696)
- [+1 Block Every Second — Roblox](https://www.roblox.com/games/12003400278/1-Block-Every-Second)
- [Every Second You Get +1 — Roblox](https://www.roblox.com/games/11912525919/Every-Second-You-Get-1)
- [+1 Food Every Second codes — Game Rant](https://gamerant.com/roblox-1-food-every-second/)
- [Hypercasual game — Grokipedia](https://grokipedia.com/page/Hypercasual_game)
- [Hybrid Casual Games 2026 — Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026/)
- [What Makes a Game Viral in 2026 — Melior Games](https://meliorgames.com/best-practices/what-makes-a-game-viral-in-2026/)
- [Best incremental games for prestige & automation](https://pinkcrow.net/game-idea/the-best-incremental-games-for-prestige-automation-fans/)
