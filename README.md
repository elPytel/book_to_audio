# book to audio

Nástroj na převod knihy do audio formátu. Využívá knihovnu [piper-tts](https://github.com/OHF-Voice/piper1-gpl) pro převod textu na řeč.

## Spuštění

Knihy ve formátu .epub vložte do složky `books/`. 

```bash
make
```

Automaticky se nainstalují závislosti a spustí se nástoroj převod knihy do audio formátu.

### Paralelní zpracování

Pro rychlejší zpracování je možné využít paralelní zpracování, pokud máte více jádrový procesor. Stačí spustit příkaz s parametrem `-j` a počet paralelních procesů. Například:
```bash
make read BOOK=Hamlet -j 12
```

### Přehrání audia
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
  - [x] Udržuje si záznam o tom kdo mluví. 
  - [ ] Využívá také nastavení emocí pro jednotlivé dialogy.  
- [ ] AI si samo nastaví parametry jednotlivých hlasů, aby odpovídali pohlaví a věku. 

## Návrh Pipeline

1. Analýza textu a konfigurace postav,
2. Rozdělení do kapitol a jednotlivých dialogů,
3. Generování audio souborů pro jednotlivé dialogy a kapitoly.

`EPUB` -> `TXT` -> `XML` -> `TXT fragmenty` -> `WAV fragmenty` -> `Spojená Audiokniha`

Make file se stará o plnění cílů.

Nejprve se extrahuje text z `EPUB` do `TXT`, následně se převede do `XML`, kde se analyzuje text a rozdělí na jednotlivé dialogy. Dialogy se pak převedou do adresářové struktury, ze které je již možné generovat audio fragmenty v podobě `WAV` souborů a nakonec se spojí do finální audioknihy.

### XML
Ukázka z `hamlet.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<book>
  <act name="JEDNÁNÍ PRVNÍ">
    <scene name="Scéna 1.">
      <utterance speaker="BERNARDO">Kdo zde?</utterance>
      <utterance speaker="FRANCISKO">Ne, mně odpověz! Stůj a dej se znát!</utterance>
      <utterance speaker="BERNARDO">Ať žije král!</utterance>
      <utterance speaker="FRANCISKO">Bernardo?</utterance>
      <utterance speaker="BERNARDO">On!</utterance>
...
```

### Hlasy
Vytvoření `<book>_voices.conf` souboru, který obsahuje mapování postav na konkrétní hlas a jeho parametry.

```conf
BERNARDO=cs_CZ-honza-medium|-100
DÁNOVÉ=cs_CZ-jirka-medium|0
DIVADELNÍ=cs_CZ-honza-medium|-150
DRUHÝ=cs_CZ-jirka-medium|-150
DUCH=cs_CZ-honza-medium|-500
```

Značky za `|` určují modulaci hlasu, kde 0 je výchozí hodnota, záporné hodnoty znamenají nižší hlas a kladné hodnoty vyšší hlas, jako parametr se předávají `sox`.

### Adresářová struktura

```
generated/
├── hamlet/
│   ├── audio/
│   │   ├── act_1.wav
│   │   └── act_2.wav
│   └── fragments/
│       ├── act_1/
|       |   ├── scene_1/
|       |   |   ├── 0001_fragment.txt
|       |   |   └── 0001_fragment.wav
|       |   ├── scene_2/
|       |   └── scene_3/
│       └── act_2/
└── hamlet.xml
```


## Další jazyky

- [hugingface: Honza](https://huggingface.co/Thomcles/Piper-TTS-Czech)