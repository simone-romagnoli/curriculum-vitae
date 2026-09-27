#!/usr/bin/env bash
#
# Compila il curriculum dentro Docker e scrive il PDF in out/ (ignorato da git).
#
#   ./build.sh                      # compila doc/curriculum-vitae-eng.tex
#   ./build.sh curriculum-vitae-ita # compila un altro documento in doc/
#
# La prima esecuzione costruisce l'immagine e scarica ~1,5 GB di TeX Live;
# quelle successive riusano la cache di Docker e durano pochi secondi.
set -euo pipefail

IMAGE="${IMAGE:-curriculum-vitae-builder}"
DOC="${1:-curriculum-vitae-eng}"

# Radice del repo: la cartella che contiene questo script, così lo script
# funziona anche se lanciato da un'altra directory.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker > /dev/null 2>&1; then
    echo "Errore: docker non e' installato o non e' nel PATH." >&2
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "Errore: il daemon Docker non risponde. Docker Desktop e' avviato?" >&2
    exit 1
fi

if [ ! -f "$REPO_DIR/doc/$DOC.tex" ]; then
    echo "Errore: doc/$DOC.tex non esiste." >&2
    echo "Documenti disponibili in doc/:" >&2
    (cd "$REPO_DIR/doc" && ls -1 *.tex) >&2
    exit 1
fi

# Il Dockerfile non copia nulla dal repo, quindi lo passiamo su stdin: il build
# context resta vuoto e Docker non deve leggere .git, assets/ e compagnia.
echo "==> Build dell'immagine $IMAGE"
docker build -t "$IMAGE" - < "$REPO_DIR/Dockerfile"

run_args=(--rm -e "DOC=$DOC" -v "$REPO_DIR:/repo")

case "$(uname -s)" in
    Linux | Darwin)
        # Senza questo i file in out/ risulterebbero di proprieta' di root.
        run_args+=(--user "$(id -u):$(id -g)")
        ;;
    *)
        # Git Bash / MSYS su Windows: evita che il path /repo venga riscritto.
        export MSYS_NO_PATHCONV=1
        ;;
esac

echo "==> Compilazione di doc/$DOC.tex"
docker run "${run_args[@]}" "$IMAGE"

echo "==> PDF pronto: out/$DOC.pdf"
