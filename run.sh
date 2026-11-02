#!/usr/bin/env bash
# Запуск donbass_bang_bang. Работает из любой оболочки (это bash-скрипт).
#   ./run.sh          — игра в окне
#   ./run.sh test     — headless-тест симуляции (exit 0 = всё ок)
#   ./run.sh import    — переимпортировать ресурсы (кэш .godot/)
# Godot ищется так: $GODOT → godot/godot4 в PATH → ~/.local/bin/godot →
# скачанный бинарник в scratchpad. Свой путь можно задать: GODOT=/путь ./run.sh
set -euo pipefail

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_godot() {
	if [[ -n "${GODOT:-}" && -x "${GODOT}" ]]; then echo "${GODOT}"; return 0; fi
	local c p
	for c in godot godot4; do
		if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
	done
	for p in "$HOME/.local/bin/godot" \
		/tmp/claude-*/*/*/scratchpad/godot_dl/Godot_v*-stable_linux.x86_64; do
		if [[ -x "$p" ]]; then echo "$p"; return 0; fi
	done
	return 1
}

if ! GODOT_BIN="$(find_godot)"; then
	echo "Godot не найден. Укажи путь так: GODOT=/путь/к/godot $0" >&2
	exit 1
fi

cmd="${1:-run}"
case "$cmd" in
	test)
		exec "$GODOT_BIN" --headless --path "$PROJ" --script tests/headless_match.gd
		;;
	import)
		exec "$GODOT_BIN" --headless --path "$PROJ" --import
		;;
	run)
		# Первый запуск: собрать кэш классов, иначе типы не находятся.
		if [[ ! -d "$PROJ/.godot" ]]; then
			"$GODOT_BIN" --headless --path "$PROJ" --import
		fi
		exec "$GODOT_BIN" --path "$PROJ"
		;;
	*)
		echo "Использование: $0 [run|test|import]" >&2
		exit 2
		;;
esac
