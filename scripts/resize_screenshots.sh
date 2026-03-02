#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Resize screenshots in bulk (macOS `sips` based).

Usage:
  scripts/resize_screenshots.sh --input <dir> --output <dir> [--preset <name> | --width <px> --height <px>] [--mode fill|stretch] [--format png|jpg] [--suffix <text>]
  scripts/resize_screenshots.sh --list-presets

Options:
  --input <dir>       Source folder with images (png/jpg/jpeg/heic).
  --output <dir>      Destination folder.
  --preset <name>     Predefined App Store size preset.
  --width <px>        Target width in pixels (required if preset is not used).
  --height <px>       Target height in pixels (required if preset is not used).
  --mode <mode>       Resize mode:
                      fill    = keep aspect ratio, then center-crop to exact size (default)
                      stretch = force exact size (can distort)
  --format <fmt>      Output format: png or jpg. Default: keep original format.
  --suffix <text>     Suffix appended to output filename (ex: _iphone67).
  --list-presets      Print available presets and exit.
  --help              Show this help.

Examples:
  scripts/resize_screenshots.sh --input ./raw --output ./out --preset asc_iphone69_1320 --suffix _iphone69 --format png
  scripts/resize_screenshots.sh --input ./raw --output ./out --preset asc_iphone65_1242 --suffix _iphone65 --format png
  scripts/resize_screenshots.sh --input ./raw --output ./out --width 1290 --height 2796 --mode fill --format png
EOF
}

list_presets() {
  cat <<'EOF'
Available presets:
  # App Store Connect iPhone 6.9" slot (choose one):
  asc_iphone69_1320   1320x2868
  asc_iphone69_1290   1290x2796
  asc_iphone69_1260   1260x2736

  # App Store Connect iPhone 6.5" slot (choose one):
  asc_iphone65_1284   1284x2778
  asc_iphone65_1242   1242x2688

  # iPad (commonly accepted):
  asc_ipad13_2064     2064x2752
  asc_ipad13_2048     2048x2732

  # Legacy short aliases:
  iphone69            1320x2868
  iphone67            1290x2796
  iphone65            1242x2688
  iphone61   1179x2556
  iphone55   1242x2208
  ipad13     2064x2752
  ipad129    2048x2732
EOF
}

input_dir=""
output_dir=""
preset=""
width=""
height=""
mode="fill"
format=""
suffix=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_dir="${2:-}"
      shift 2
      ;;
    --output)
      output_dir="${2:-}"
      shift 2
      ;;
    --preset)
      preset="${2:-}"
      shift 2
      ;;
    --width)
      width="${2:-}"
      shift 2
      ;;
    --height)
      height="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --format)
      format="${2:-}"
      shift 2
      ;;
    --suffix)
      suffix="${2:-}"
      shift 2
      ;;
    --list-presets)
      list_presets
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

if [[ -n "$preset" ]]; then
  case "$preset" in
    asc_iphone69_1320) width=1320; height=2868 ;;
    asc_iphone69_1290) width=1290; height=2796 ;;
    asc_iphone69_1260) width=1260; height=2736 ;;
    asc_iphone65_1284) width=1284; height=2778 ;;
    asc_iphone65_1242) width=1242; height=2688 ;;
    asc_ipad13_2064) width=2064; height=2752 ;;
    asc_ipad13_2048) width=2048; height=2732 ;;
    iphone69) width=1320; height=2868 ;;
    iphone67) width=1290; height=2796 ;;
    iphone65) width=1242; height=2688 ;;
    iphone61) width=1179; height=2556 ;;
    iphone55) width=1242; height=2208 ;;
    ipad13) width=2064; height=2752 ;;
    ipad129) width=2048; height=2732 ;;
    *)
      echo "Unknown preset: $preset" >&2
      list_presets
      exit 1
      ;;
  esac
fi

if [[ -z "$input_dir" || -z "$output_dir" || -z "$width" || -z "$height" ]]; then
  usage
  exit 1
fi

if [[ ! -d "$input_dir" ]]; then
  echo "Input directory not found: $input_dir" >&2
  exit 1
fi

if [[ "$mode" != "fill" && "$mode" != "stretch" ]]; then
  echo "Invalid mode: $mode (expected fill or stretch)" >&2
  exit 1
fi

if [[ -n "$format" ]]; then
  format_lower="$(echo "$format" | tr '[:upper:]' '[:lower:]')"
  case "$format_lower" in
    png) format="png" ;;
    jpg|jpeg) format="jpeg" ;;
    *)
      echo "Invalid format: $format (expected png or jpg)" >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$output_dir"

processed=0

while IFS= read -r -d '' src; do
  base_name="$(basename "$src")"
  name_no_ext="${base_name%.*}"
  src_ext="${base_name##*.}"
  src_ext_lower="$(echo "$src_ext" | tr '[:upper:]' '[:lower:]')"

  out_format="$format"
  if [[ -z "$out_format" ]]; then
    case "$src_ext_lower" in
      jpg|jpeg) out_format="jpeg" ;;
      png) out_format="png" ;;
      heic) out_format="jpeg" ;;
      *) out_format="png" ;;
    esac
  fi

  out_ext="png"
  if [[ "$out_format" == "jpeg" ]]; then
    out_ext="jpg"
  fi

  tmp="$(mktemp "/tmp/ofchours-resize-XXXXXX.${src_ext_lower}")"
  cp "$src" "$tmp"

  if [[ "$mode" == "stretch" ]]; then
    sips --resampleHeightWidth "$height" "$width" "$tmp" >/dev/null
  else
    src_w="$(sips -g pixelWidth "$tmp" | awk '/pixelWidth/ {print $2}')"
    src_h="$(sips -g pixelHeight "$tmp" | awk '/pixelHeight/ {print $2}')"

    if (( src_w * height > width * src_h )); then
      # Source is relatively wider than target: fit height, crop width.
      sips --resampleHeight "$height" "$tmp" >/dev/null
    else
      # Source is relatively taller than target: fit width, crop height.
      sips --resampleWidth "$width" "$tmp" >/dev/null
    fi

    sips --cropToHeightWidth "$height" "$width" "$tmp" >/dev/null
  fi

  out_file="${output_dir}/${name_no_ext}${suffix}.${out_ext}"
  if [[ "$out_format" == "jpeg" ]]; then
    sips -s format jpeg -s formatOptions high "$tmp" --out "$out_file" >/dev/null
  else
    sips -s format png "$tmp" --out "$out_file" >/dev/null
  fi

  out_w="$(sips -g pixelWidth "$out_file" | awk '/pixelWidth/ {print $2}')"
  out_h="$(sips -g pixelHeight "$out_file" | awk '/pixelHeight/ {print $2}')"
  if [[ "$out_w" != "$width" || "$out_h" != "$height" ]]; then
    echo "ERROR: size check failed for $out_file (got ${out_w}x${out_h}, expected ${width}x${height})" >&2
    exit 1
  fi

  rm -f "$tmp"
  processed=$((processed + 1))
  echo "OK: $out_file"
done < <(find "$input_dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.heic" \) -print0)

if [[ "$processed" -eq 0 ]]; then
  echo "No images found in: $input_dir"
  exit 1
fi

echo "Done. Resized ${processed} image(s) to ${width}x${height}."
