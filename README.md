# book to audio

Nástroj na převod knihy do audio formátu. Využívá knihovnu [piper-tts](https://github.com/OHF-Voice/piper1-gpl) pro převod textu na řeč.

## Spuštění

Knihy ve formátu .epub vložte do složky `books/`. 

```bash
make
```

Automaticky se nainstalují závislosti a spustí se nástoroj převod knihy do audio formátu.

Přehrání výsledného souboru:

```bash
aplay $(GENERATE_AUDIO_DIR)/<book_name>.wav
```

## Cíl aplikace

TODO:

Nástroj využívající tts obdobně jako u generování podcástů z novinových článků, který udělá stejnou věc ale pro celou knihu. Volba různých hlasů pro různé postavy.

Rozchození na divadelních hrách:
- [ ] přidání více hlasů (pro různé postavy),
- [ ] Vkládání xml značky to textu pro odlišení jednotlivých postav a jejich emocí,
  - [ ] Udržuje si záznam o tom kdo mluví. 
  - [ ] Využívá také nastavení emocí pro jednotlivé dialogy.  
- [ ] AI si samo nastaví parametry jednotlivých hlasů, aby odpovídali pohlaví a věku. 

1. Analýza textu a konfigurace postav,
2. Rozdělení do kapitol a jednotlivých dialogů,
3. Generování audio souborů pro jednotlivé dialogy a kapitoly.

## Další jazyky

- [hugingface: Honza](https://huggingface.co/Thomcles/Piper-TTS-Czech)