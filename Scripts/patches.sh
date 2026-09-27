#!/usr/bin/env bash
#
# Single source of truth for the Tempo patch set.
#
# The three build_rclcpp_*.sh scripts used to each carry their own copy-pasted
# block of "cd <submodule> && git reset --hard && git apply <patch>" lines. They
# drifted (yaml_cpp_vendor was applied on Windows only, ros2cli.patch was applied
# nowhere at all), so the list lives here now and the build scripts call this.
#
# Usage:
#   patches.sh list  [--tier TIERS]            print the patch set
#   patches.sh apply [--tier TIERS] [pkg ...]  reset submodule(s), then apply
#   patches.sh reset [--tier TIERS] [pkg ...]  reset submodule(s) to pristine upstream
#   patches.sh regen [pkg ...]                 write working-tree diff back to Patches/
#
# TIERS is a string of tier letters, e.g. --tier BE. Default is all tiers.
#
#   B  base       non-ROS third party (boost, theora, vorbis, opencv)
#   E  env        needed for ROS 2 to configure/build against Unreal at all
#   R  rtti       -fno-rtti and single-process-image workarounds
#   P  pmr        the std::pmr allocator conversion and its fallout
#
# The tiers exist so the Humble->Jazzy upgrade can be bisected: build with -t BE
# first to prove the dependency bump, then add R, then add P.

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$(realpath "$SCRIPT_DIR/..")
SRC_DIR="$ROOT_DIR/Source/rclcpp"
PATCH_DIR="$ROOT_DIR/Patches"

# name | submodule path relative to Source/rclcpp | git clean flags | tier | platforms
#
# Order matters for `apply`: it is the order the build scripts have always used.
# An empty clean-flags field means "git reset --hard only".
# Platforms is a comma list of windows,linux,mac; empty means all.
PATCHES=$(cat <<'EOF'
rclcpp|rclcpp||P|
rmw|rmw||R|
rosidl|rosidl|-fd|P|
rcutils|rcutils||E|
rcutils-monolith|rcutils||R|
image_common|image_common|-f|P|
image_transport_plugins-deps|image_transport_plugins|-f|E|
image_transport_plugins|image_transport_plugins|-f|P|
Fast-DDS|Fast-DDS|-f|E|
Fast-CDR|Fast-CDR|-f|P|
rosidl_typesupport|rosidl_typesupport|-f|R|
rosidl_typesupport_fastrtps|rosidl_typesupport_fastrtps|-f|P|
pluginlib|pluginlib|-f|R|
cyclonedds|cyclonedds|-f|E|
class_loader|class_loader|-f|R|
boost-python|boost/libs/python|-f|B|
boost-exception|boost/libs/exception|-f|B|
geometry2|geometry2|-f|P|
theora|theora|-df|B|
orocos_kdl_vendor|orocos_kdl_vendor|-df|E|
libstatistics_collector|libstatistics_collector|-df|P|
common_interfaces|common_interfaces|-f|P|
rmw_cyclonedds|rmw_cyclonedds|-f|P|
rmw_dds_common|rmw_dds_common|-f|P|
rmw_fastrtps|rmw_fastrtps|-f|P|
vision_opencv|vision_opencv|-f|P|
vorbis|vorbis|-f|B|
yaml_cpp_vendor|yaml_cpp_vendor|-f|E|
opencv|opencv|-f|B|mac
EOF
)

# image_transport_plugins-deps is the environment half of image_transport_plugins, split out so a
# stock (tier BE) build can complete. theora_image_transport declares <depend>libogg</depend> and
# <depend>libtheora</depend>, but we build ogg and theora ourselves in the prelude and pass
# --packages-skip libogg, so colcon fails looking for install/share/libogg/package.ps1. Dropping
# those tags has nothing to do with the pmr conversion that the rest of that patch carries.
#
# opencv.patch is Mac-only on purpose. OpenCV 4.5.4's bundled zlib 1.2.11 and libpng 1.6.37 both
# take their Classic Mac OS branches whenever TARGET_OS_MAC is defined. The macOS 26 SDK defines it
# (via TargetConditionals.h) before those headers are reached, so zlib #defines fdopen to NULL --
# mangling stdio.h's fdopen declaration -- and libpng tries to include <fp.h>, which has not existed
# since Mac OS 9. Both fixes are what upstream did: zlib skips that branch on __APPLE__ (where the
# __APPLE__ branch right below already sets OS_CODE 19), and libpng 1.6.44 dropped the fp.h block
# for a plain <math.h> include.

# Dropped in the Humble -> Jazzy upgrade, recorded here so the reasoning is not lost.
# If one of these turns out to still be needed, the build will say so; re-add it
# rather than assuming the note below was wrong.
#
#   rcpputils               100% test files, and every build passes -DBUILD_TESTING=OFF.
#   ros2cli                 only touched ros2lifecycle_test_fixtures, and no script applied it.
#   rcl_interfaces          forced C++14 -> C++17. Jazzy guards these with
#   unique_identifier_msgs  if(NOT CMAKE_CXX_STANDARD) and defaults to 17 anyway, so the
#   rosidl_python           -DCMAKE_CXX_STANDARD the build passes already wins. rosidl_python's
#                           target_compile_features(cxx_std_17) is redundant for the same reason.
#   python_cmake_module     worked around a FATAL_ERROR when python3-config was missing. Jazzy
#                           rewrote FindPythonExtra.cmake to just wrap find_package(Python3) and it
#                           no longer shells out to python3-config at all.
#   mimick_vendor           bumped the pinned Mimick sha past the Humble one. Jazzy pins a newer
#                           commit still, and mimick is test-only infrastructure.
#   pybind11_vendor         carried a Python 3.11 compatibility patch and an ExternalProject fix.
#                           Jazzy vendors pybind11 v2.11.1, which supports 3.11 natively, via
#                           ament_vendor()'s own patches/ directory.

detect_platform() {
  case "$OSTYPE" in
    msys*|cygwin*|win32*) echo windows ;;
    linux*)               echo linux ;;
    darwin*)              echo mac ;;
    *)                    echo unknown ;;
  esac
}

PLATFORM=$(detect_platform)

# Emits the filtered patch table on stdout.
select_patches() {
  local tiers="$1"; shift
  local names=("$@")
  local line name path flags tier plats

  while IFS='|' read -r name path flags tier plats; do
    [ -z "$name" ] && continue

    # Tier filter
    case "$tiers" in
      *"$tier"*) ;;
      *) continue ;;
    esac

    # Platform filter
    if [ -n "$plats" ] && [[ ",$plats," != *",$PLATFORM,"* ]]; then
      continue
    fi

    # Explicit name filter
    if [ ${#names[@]} -gt 0 ]; then
      local match=0
      for n in "${names[@]}"; do
        [ "$n" = "$name" ] && match=1
      done
      [ $match -eq 0 ] && continue
    fi

    echo "$name|$path|$flags|$tier|$plats"
  done <<< "$PATCHES"
}

do_reset() {
  local path="$1" flags="$2"
  local dir="$SRC_DIR/$path"
  [ -d "$dir" ] || { echo "  !! missing submodule: $dir"; return 1; }
  git -C "$dir" reset --hard --quiet
  if [ -n "$flags" ]; then
    git -C "$dir" clean "$flags" --quiet
  fi
}

cmd_list() {
  printf '%-32s %-34s %-5s %s\n' PATCH SUBMODULE TIER PLATFORMS
  while IFS='|' read -r name path flags tier plats; do
    [ -z "$name" ] && continue
    printf '%-32s %-34s %-5s %s\n' "$name" "$path" "$tier" "${plats:-all}"
  done <<< "$1"
}

cmd_reset() {
  while IFS='|' read -r name path flags tier plats; do
    [ -z "$name" ] && continue
    echo "  reset $path"
    do_reset "$path" "$flags"
  done <<< "$1"
}

cmd_apply() {
  local failed=0
  # More than one patch can target the same submodule (rcutils has one env-tier and one
  # rtti-tier patch), so only reset the first time we touch a given path -- otherwise the
  # reset for the second patch would throw away the first.
  local reset_paths=" "

  # Reset every submodule in the manifest, not just the ones this tier selection is about to
  # patch. Otherwise a narrower run leaves behind whatever a previous, broader run applied, and
  # the tier bisect quietly stops meaning anything: building with --tier BE while a stale pmr
  # patch is still sitting in libstatistics_collector is neither a stock build nor a patched one.
  while IFS='|' read -r name path flags tier plats; do
    [ -z "$name" ] && continue
    if [[ "$reset_paths" != *" $path "* ]]; then
      do_reset "$path" "$flags" || true
      reset_paths="$reset_paths$path "
    fi
  done <<< "$(select_patches BERP)"

  while IFS='|' read -r name path flags tier plats; do
    [ -z "$name" ] && continue
    local patch="$PATCH_DIR/$name.patch"
    if [ ! -f "$patch" ]; then
      echo "  -- $name (no patch file, skipping)"
      continue
    fi
    echo "  [$tier] $name -> $path"
    if ! git -C "$SRC_DIR/$path" apply "$patch"; then
      echo "  !! FAILED to apply $name.patch"
      failed=$((failed + 1))
    fi
  done <<< "$1"
  if [ $failed -gt 0 ]; then
    echo "$failed patch(es) failed to apply"
    return 1
  fi
}

# Regenerate Patches/<name>.patch from the submodule's current working tree.
#
# CAUTION: regen diffs the WHOLE submodule. Where two patches target the same submodule
# (rcutils, image_transport_plugins) that is wrong -- the regenerated patch will also contain
# the other patch's changes, and applying both then fails with "patch does not apply". For
# those, generate the diff scoped to the files that patch owns:
#     git -C Source/rclcpp/<sub> diff --ignore-submodules=all -- <paths> > Patches/<name>.patch
#
# -N (intent-to-add) is what makes newly added files show up in git diff; several
# patches add files rather than only editing them.
#
# --ignore-submodules=all matters more than it looks. Several of these packages
# (Fast-DDS above all) have git submodules of their own that we never initialise,
# so a plain diff reports bogus "Subproject commit ..." hunks for them. The old
# Fast-DDS.patch carried exactly such a hunk -- pointing at a "-dirty" sha that
# could never apply -- which is how it got there.
cmd_regen() {
  while IFS='|' read -r name path flags tier plats; do
    [ -z "$name" ] && continue
    local dir="$SRC_DIR/$path"
    [ -d "$dir" ] || { echo "  !! missing submodule: $dir"; continue; }
    git -C "$dir" add -A -N . >/dev/null 2>&1 || true
    local out="$PATCH_DIR/$name.patch"
    if git -C "$dir" diff --ignore-submodules=all > "$out.tmp"; then
      if [ -s "$out.tmp" ]; then
        mv "$out.tmp" "$out"
        echo "  wrote $name.patch ($(wc -l < "$out") lines)"
      else
        rm -f "$out.tmp"
        echo "  -- $name: working tree is clean, left $name.patch untouched"
      fi
    else
      rm -f "$out.tmp"
      echo "  !! failed to diff $path"
    fi
  done <<< "$1"
}

usage() {
  sed -n '3,28p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit 1
}

TIERS=BERP
ACTION="${1:-}"
[ -z "$ACTION" ] && usage
shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tier) TIERS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) break ;;
  esac
done

SELECTED=$(select_patches "$TIERS" "$@")
if [ -z "$SELECTED" ]; then
  echo "No patches matched (tier=$TIERS platform=$PLATFORM ${*:+names=$*})"
  exit 1
fi

case "$ACTION" in
  list)  cmd_list  "$SELECTED" ;;
  apply) echo "Applying Tempo patches (tier=$TIERS platform=$PLATFORM)..."
         cmd_apply "$SELECTED" ;;
  reset) echo "Resetting submodules (tier=$TIERS platform=$PLATFORM)..."
         cmd_reset "$SELECTED" ;;
  regen) echo "Regenerating patches..."
         cmd_regen "$SELECTED" ;;
  *)     usage ;;
esac
