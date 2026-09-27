# Compila il curriculum in locale senza installare TeX Live sulla macchina.
#
# Replica quello che fa .github/workflows/cd.yml (pdflatex sui sorgenti in doc/),
# ma installa solo il sottoinsieme di TeX Live richiesto dal template invece di
# texlive-full. I sorgenti non vengono copiati nell'immagine: il repo viene
# montato su /repo a runtime, così modificare un .tex non richiede una rebuild.
#
# Non usare direttamente: vedi ./build.sh
FROM ubuntu:22.04

# Pacchetti richiesti dai \RequirePackage di doc/template-eng.cls:
#   texlive-latex-base        -> LaTeX core, hyperref
#   texlive-latex-recommended -> xcolor, etoolbox, parskip, ragged2e
#   texlive-latex-extra       -> enumitem, textpos, ifmtarg
#   texlive-pictures          -> tikz, pgf, pgffor
#   texlive-fonts-recommended -> marvosym
#   texlive-fonts-extra       -> fontawesome5 (da solo ~1,3 GB: e' il grosso dell'immagine)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-pictures \
        texlive-fonts-recommended \
        texlive-fonts-extra \
    && rm -rf /var/lib/apt/lists/*

# Se in futuro un pacchetto cambia nome o contenuto, la build fallisce qui con un
# messaggio chiaro invece di far esplodere pdflatex con un "File not found".
RUN for sty in fontawesome5 marvosym textpos ifmtarg enumitem ragged2e \
               parskip etoolbox xcolor hyperref tikz pgffor; do \
        kpsewhich "$sty.sty" > /dev/null \
            || { echo "Pacchetto TeX mancante: $sty.sty" >&2; exit 1; }; \
    done

# HOME e cache scrivibili: servono a pdflatex quando il container gira come
# utente non-root (build.sh passa --user su Linux e macOS).
ENV HOME=/tmp \
    TEXMFVAR=/tmp/texmf-var \
    DOC=curriculum-vitae-eng \
    SOURCE_DIR=doc \
    OUTPUT_DIR=out

WORKDIR /repo

# Due passate di pdflatex: la prima genera i riferimenti, la seconda li risolve
# (senza la seconda LaTeX avvisa "Label(s) may have changed").
# In caso di errore il log resta in out/ per l'ispezione.
CMD set -eu; \
    out="/repo/$OUTPUT_DIR"; \
    log="$out/$DOC.build.log"; \
    mkdir -p "$out"; \
    : > "$log"; \
    cd "/repo/$SOURCE_DIR"; \
    for pass in 1 2; do \
        echo "==> pdflatex $DOC.tex (passata $pass/2)"; \
        pdflatex -interaction=nonstopmode -halt-on-error \
                 -output-directory="$out" "$DOC.tex" >> "$log" 2>&1 \
            || { echo "Compilazione fallita:" >&2; \
                 { grep -A4 '^!' "$log" || tail -n 25 "$log"; } >&2; \
                 echo "Log completo: $OUTPUT_DIR/$DOC.build.log" >&2; \
                 exit 1; }; \
    done; \
    rm -f "$out/$DOC.aux" "$out/$DOC.log" "$out/$DOC.out" "$log"; \
    echo "==> OK: $OUTPUT_DIR/$DOC.pdf"
