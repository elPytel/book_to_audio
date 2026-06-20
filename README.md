# book to audio

Nástroj na převod knihy do audio formátu. Využívá knihovnu [piper-tts](https://github.com/OHF-Voice/piper1-gpl) pro převod textu na řeč.

## Spuštění

Knihy ve formátu .epub vložte do složky `books/`. 

```bash
make
```

Automaticky se nainstalují závislosti a spustí se nástoroj převod knihy do audio formátu.

## Cíl aplikace

TODO:

Nástroj využívající tts obdobně jako u generování podcástů z novinových článků, který udělá stejnou věc ale pro celou knihu. Volba různých hlasů pro různé postavy.
AI si samo nastaví parametry jednotlivých hlasů, aby odpovídali pohlaví a věku. 
Udržuje si záznam o tom kdo mluví. Využívá také nastavení emocí pro jednotlivé dialogy.  

Rozchození na divadelních hrách.

## Další jazyky

[hugingface: Honza](https://huggingface.co/Thomcles/Piper-TTS-Czech)