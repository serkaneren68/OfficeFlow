#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Validate screenshot dimensions for App Store Connect slots.

Usage:
  scripts/check_screenshot_sizes.sh --input <dir> --slot <iphone69|iphone65|ipad13|preview-iphone>
  scripts/check_screenshot_sizes.sh --list-slots
EOF
}

list_slots() {
  cat <<'EOF'
Available slots:
  iphone69       1260x2736, 1290x2796, 1320x2868 (and landscape)
  iphone65       1242x2688, 1284x2778 (and landscape)
  ipad13         2048x2732, 2064x2752 (and landscape)
  preview-iphone 886x1920 (and landscape)
EOF
}

is_allowed() {
  local slot="$1"
  local w="$2"
  local h="$3"

  case "$slot" in
    iphone69)
      [[ ("$w" == "1260" && "$h" == "2736") || ("$w" == "2736" && "$h" == "1260") || \
         ("$w" == "1290" && "$h" == "2796") || ("$w" == "2796" && "$h" == "1290") || \
         ("$w" == "1320" && "$h" == "2868") || ("$w" == "2868" && "$h" == "1320") ]]
      ;;
    iphone65)
      [[ ("$w" == "1242" && "$h" == "2688") || ("$w" == "2688" && "$h" == "1242") || \
         ("$w" == "1284" && "$h" == "2778") || ("$w" == "2778" && "$h" == "1284") ]]
      ;;
    ipad13)
      [[ ("$w" == "2048" && "$h" == "2732") || ("$w" == "2732" && "$h" == "2048") || \
         ("$w" == "2064" && "$h" == "2752") || ("$w" == "2752" && "$h" == "2064") ]]
      ;;
    preview-iphone)
      [[ ("$w" == "886" && "$h" == "1920") || ("$w" == "1920" && "$h" == "886") ]]
      ;;
    *)
      return 1
      ;;
  esac
}

input_dir=""
slot=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_dir="${2:-}"
      shift 2
      ;;
    --slot)
      slot="${2:-}"
      shift 2
      ;;
    --list-slots)
      list_slots
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$input_dir" || -z "$slot" ]]; then
  usage
  exit 1
fi

if [[ ! -d "$input_dir" ]]; then
  echo "Input directory not found: $input_dir" >&2
  exit 1
fi

total=0
failed=0

while IFS= read -r -d '' file; do
  w="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
  h="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"
  total=$((total + 1))

  if is_allowed "$slot" "$w" "$h"; then
    echo "PASS ${w}x${h}  $(basename "$file")"
  else
    echo "FAIL ${w}x${h}  $(basename "$file")"
    failed=$((failed + 1))
  fi
done < <(find "$input_dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

if [[ "$total" -eq 0 ]]; then
  echo "No image files found in: $input_dir"
  exit 1
fi

echo "Checked: $total, Failed: $failed"
if [[ "$failed" -gt 0 ]]; then
  exit 2
fi
