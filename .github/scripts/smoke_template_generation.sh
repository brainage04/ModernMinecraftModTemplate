#!/usr/bin/env bash

set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

copy_template() {
  local target="$1"

  mkdir -p "$target"
  tar \
    --exclude=.git \
    --exclude=.gradle \
    --exclude=.project \
    --exclude=.classpath \
    --exclude=.settings \
    --exclude=.idea \
    --exclude=bin \
    --exclude=build \
    --exclude=run \
    --exclude='.init-package-tree.*' \
    -C "$template_root" \
    -cf - . |
    tar -C "$target" -xf -

  if [ -f "$template_root/run/options.txt" ]; then
    mkdir -p "$target/run"
    cp "$template_root/run/options.txt" "$target/run/options.txt"
  fi
}

prepare_recorder_dependency() {
  local target_parent="$1"
  local source="$template_root/../FabricModdingConventions"
  local target="$target_parent/FabricModdingConventions"

  if [ ! -d "$source" ]; then
    echo "Missing sibling FabricModdingConventions checkout at $source" >&2
    exit 1
  fi

  mkdir -p "$target/build"
  cp -R "$source/build/local-repo" "$target/build/local-repo"
}

assert_path_exists() {
  local path="$1"

  if [ ! -e "$path" ]; then
    echo "Expected path to exist: $path" >&2
    exit 1
  fi
}

assert_path_missing() {
  local path="$1"

  if [ -e "$path" ]; then
    echo "Expected path to be absent: $path" >&2
    exit 1
  fi
}

assert_no_match() {
  local pattern="$1"
  shift

  if rg -n "$pattern" "$@" >/tmp/template-smoke-rg.out; then
    cat /tmp/template-smoke-rg.out >&2
    exit 1
  fi
}

assert_match() {
  local pattern="$1"
  shift

  if ! rg -n "$pattern" "$@" >/tmp/template-smoke-rg.out; then
    echo "Expected pattern to match: $pattern" >&2
    cat /tmp/template-smoke-rg.out >&2
    exit 1
  fi
}

assert_json_string() {
  local file="$1"
  local filter="$2"
  local expected="$3"
  local actual

  actual=$(jq -r "$filter" "$file")
  if [ "$actual" != "$expected" ]; then
    echo "Expected $file $filter to be '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_json_compact() {
  local file="$1"
  local filter="$2"
  local expected="$3"
  local actual

  actual=$(jq -c "$filter" "$file")
  if [ "$actual" != "$expected" ]; then
    echo "Expected $file $filter to be '$expected', got '$actual'" >&2
    exit 1
  fi
}

compact_json_in_place() {
  local file="$1"
  local temporary

  temporary=$(mktemp "${file}.smoke.XXXXXX")
  jq --sort-keys --compact-output . "$file" >"$temporary"
  chmod --reference="$file" "$temporary"
  mv -f "$temporary" "$file"
}

smoke_side() {
  local side="$1"
  local target="$tmp_root/$side/ModernMinecraftModTemplate-${side}_42"
  local package_dir="io/github/brainage04/modernminecraftmodtemplate_${side}_42"
  local package_name="io.github.brainage04.modernminecraftmodtemplate_${side}_42"
  local main_class="ModernMinecraftModTemplate${side^}42"
  local mod_id="modernminecraftmodtemplate_${side}_42"
  local -a build_args

  echo "Testing init.sh --side=${side}"
  copy_template "$target"
  prepare_recorder_dependency "$(dirname "$target")"

  (
    cd "$target"

    if [ "$side" = "server" ]; then
      compact_json_in_place src/main/resources/fabric.mod.json
      compact_json_in_place src/gametest/resources/fabric.mod.json
    fi

    ./init.sh --side="$side" "ModernMinecraftModTemplate-${side}_42"

    assert_path_missing "init.sh"
    assert_path_missing ".github/workflows/init.yml"
    assert_path_missing ".github/scripts/smoke_template_generation.sh"
    assert_path_missing ".github/scripts/test_modrinth_scripts.sh"
    assert_path_exists "src/main/java/${package_dir}/config/ModConfig.java"
    assert_path_exists "src/test/java/${package_dir}/${main_class}MetadataTest.java"
    assert_path_exists "src/main/resources/${mod_id}.accesswidener"
    assert_path_exists "src/main/resources/assets/${mod_id}/icon.png"
    assert_path_exists "src/gametest/resources/assets/${mod_id}/icon.png"
    assert_no_match 'smoke_template_generation|test_modrinth_scripts' .github/workflows/build.yml
    assert_no_match 'scripts=\(\.github/scripts/\*\.sh\)|shellcheck "\$\{scripts\[@\]\}"|init\.sh' .github/workflows/build.yml

    assert_json_string src/main/resources/fabric.mod.json '.environment' "$(if [ "$side" = "client" ]; then printf client; else printf '*'; fi)"
    assert_json_string src/main/resources/fabric.mod.json '.icon' "assets/${mod_id}/icon.png"
    assert_json_string src/main/resources/fabric.mod.json '.accessWidener' "${mod_id}.accesswidener"
    assert_json_string src/gametest/resources/fabric.mod.json '.environment' "$(if [ "$side" = "client" ]; then printf client; else printf '*'; fi)"
    assert_json_string src/gametest/resources/fabric.mod.json '.icon' "assets/${mod_id}/icon.png"
    assert_json_string src/main/resources/fabric.mod.json 'type' object
    assert_json_string src/main/resources/fabric.mod.json 'keys_unsorted[0]' schemaVersion
    assert_json_string src/gametest/resources/fabric.mod.json 'keys_unsorted[0]' schemaVersion
    assert_json_string src/main/resources/fabric.mod.json '.contact.homepage' "https://github.com/brainage04/ModernMinecraftModTemplate-${side}_42"
    assert_json_string src/main/resources/fabric.mod.json '.contact.sources' "https://github.com/brainage04/ModernMinecraftModTemplate-${side}_42"
    assert_json_string src/gametest/resources/fabric.mod.json 'type' object

    if [ "$side" = "server" ]; then
      assert_path_exists "src/main/java/${package_dir}/${main_class}.java"
      assert_path_missing "run/options.txt"
      assert_path_missing "src/client"
      assert_path_missing "scripts/run-client-gametest-recorded.sh"
      assert_path_missing "src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_exists "src/main/resources/${mod_id}.mixins.json"
      assert_match 'reusable-client-gametests\.yml@' .github/workflows/build.yml
      assert_no_match 'runClientGameTest' .github/workflows/build.yml
      # The leaf plugins require an already-applied Loom: they stop applying the base
      # fabric-mod-conventions plugin themselves, so the generated build must name it.
      assert_match 'io\.github\.brainage04\.fabric-mod-conventions' build.gradle
      assert_match 'io.github.brainage04.production-gametests' build.gradle
      assert_no_match "^[[:space:]]*id 'io\.github\.brainage04\.client-gametest-recorder'" build.gradle
      assert_match 'pluginManager\.withPlugin\("io\.github\.brainage04\.client-gametest-recorder"\)' build.gradle
      assert_no_match 'prepareClientGameTestRun|CLIENT GAMETEST RUN SETUP|clientGameTestRunDir|splitEnvironmentSourceSets|sourceSets\.client|enableClientGameTests' build.gradle
      assert_json_compact src/main/resources/fabric.mod.json '.entrypoints' "{\"main\":[\"${package_name}.${main_class}\"]}"
      assert_json_compact src/main/resources/fabric.mod.json '.mixins' "[\"${mod_id}.mixins.json\"]"
      assert_json_compact src/gametest/resources/fabric.mod.json '.entrypoints' "{\"fabric-gametest\":[\"${package_name}.${main_class}GameTest\"]}"
    elif [ "$side" = "both" ]; then
      assert_path_exists "src/main/java/${package_dir}/${main_class}.java"
      assert_path_exists "run/options.txt"
      assert_path_exists "src/client/java/${package_dir}/${main_class}Client.java"
      assert_path_exists "src/client/java/${package_dir}/command/ExampleClientCommand.java"
      assert_path_exists "src/client/java/${package_dir}/command/core/ClientModCommands.java"
      assert_path_exists "src/client/java/${package_dir}/mixin/client/ExampleClientMixin.java"
      assert_path_exists "src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_missing "scripts/run-client-gametest-recorded.sh"
      assert_path_exists "src/main/resources/${mod_id}.mixins.json"
      assert_path_exists "src/client/resources/${mod_id}.client.mixins.json"
      assert_path_exists "src/client/resources/assets/${mod_id}/lang/en_us.json"
      assert_match 'reusable-client-gametests\.yml@' .github/workflows/build.yml
      assert_no_match 'runClientGameTest' .github/workflows/build.yml
      # The leaf plugins require an already-applied Loom: they stop applying the base
      # fabric-mod-conventions plugin themselves, so the generated build must name it.
      assert_match 'io\.github\.brainage04\.fabric-mod-conventions' build.gradle
      assert_match 'io.github.brainage04.client-gametest-recorder' build.gradle
      assert_match 'io.github.brainage04.production-gametests' build.gradle
      assert_match 'io.github.brainage04.workspace-dependencies' build.gradle
      assert_match 'siblingMaven\("FabricModdingConventions"\)' build.gradle
      assert_json_compact src/main/resources/fabric.mod.json '.entrypoints | to_entries | sort_by(.key) | from_entries' "{\"client\":[\"${package_name}.${main_class}Client\"],\"main\":[\"${package_name}.${main_class}\"]}"
      assert_json_compact src/main/resources/fabric.mod.json '.mixins' "[\"${mod_id}.mixins.json\",{\"config\":\"${mod_id}.client.mixins.json\",\"environment\":\"client\"}]"
    else
      assert_path_exists "run/options.txt"
      assert_path_missing "src/client"
      assert_path_exists "src/main/java/${package_dir}/${main_class}.java"
      assert_path_missing "src/main/java/${package_dir}/${main_class}Client.java"
      assert_path_missing "src/main/resources/${mod_id}.mixins.json"
      assert_path_exists "src/main/resources/${mod_id}.client.mixins.json"
      assert_path_exists "src/main/java/${package_dir}/command/ExampleCommand.java"
      assert_path_exists "src/main/java/${package_dir}/command/core/ModCommands.java"
      assert_path_exists "src/main/java/${package_dir}/mixin/ExampleMixin.java"
      assert_path_missing "src/main/java/${package_dir}/command/ExampleClientCommand.java"
      assert_path_missing "src/main/java/${package_dir}/command/core/ClientModCommands.java"
      assert_path_missing "src/main/java/${package_dir}/mixin/client/ExampleClientMixin.java"
      assert_path_exists "src/gametest/java/${package_dir}/${main_class}GameTest.java"
      assert_path_missing "src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_missing "scripts/run-client-gametest-recorded.sh"
      assert_path_exists "src/main/resources/assets/${mod_id}/lang/en_us.json"
      assert_match 'reusable-client-gametests\.yml@' .github/workflows/build.yml
      assert_no_match 'runClientGameTest' .github/workflows/build.yml
      # The leaf plugins require an already-applied Loom: they stop applying the base
      # fabric-mod-conventions plugin themselves, so the generated build must name it.
      assert_match 'io\.github\.brainage04\.fabric-mod-conventions' build.gradle
      assert_match 'io.github.brainage04.client-gametest-recorder' build.gradle
      assert_match 'io.github.brainage04.production-gametests' build.gradle
      assert_match 'io.github.brainage04.workspace-dependencies' build.gradle
      assert_match 'siblingMaven\("FabricModdingConventions"\)' build.gradle
      assert_no_match 'splitEnvironmentSourceSets|sourceSets\.client' build.gradle
      assert_json_compact src/main/resources/fabric.mod.json '.entrypoints' "{\"client\":[\"${package_name}.${main_class}\"]}"
      assert_json_compact src/main/resources/fabric.mod.json '.mixins' "[\"${mod_id}.client.mixins.json\"]"
      assert_json_compact src/gametest/resources/fabric.mod.json '.entrypoints' "{\"fabric-client-gametest\":[\"${package_name}.${main_class}GameTest\"]}"
    fi

    if [ "$side" = "client" ]; then
      assert_no_match "ExampleConfig|entrypoints\\.main|\\.entrypoints \\| keys_unsorted.*main|ExampleClientCommand|ClientModCommands|ExampleClientMixin|${main_class}Client" src build.gradle README.md
      assert_path_missing "src/test/java/${package_dir}/command/ExampleCommandTest.java"
      build_args=(build)
    elif [ "$side" = "server" ]; then
      assert_path_exists "src/main/java/${package_dir}/command/ExampleCommand.java"
      build_args=(build)
    else
      assert_path_exists "src/main/java/${package_dir}/command/ExampleCommand.java"
      assert_path_exists "src/gametest/java/${package_dir}/${main_class}GameTest.java"
      assert_json_compact src/gametest/resources/fabric.mod.json '.entrypoints | to_entries | sort_by(.key) | from_entries' "{\"fabric-client-gametest\":[\"${package_name}.${main_class}ClientGameTest\"],\"fabric-gametest\":[\"${package_name}.${main_class}GameTest\"]}"
      build_args=(build)
    fi

    grep -qx "maven_group=${package_name}" gradle.properties
    grep -qx "mod_side=${side}" gradle.properties
    assert_no_match 'splitEnvironmentSourceSets|sourceSets\.client|configureTests|processGametestResources|maven-publish|publishing[[:space:]]*\{' build.gradle
    assert_no_match 'ExampleConfig' README.md build.gradle gradle.properties LICENSE src
    assert_no_match 'com\.example|io\.github\.brainage04\.modernminecraftmodtemplate([^_a-z0-9]|$)|io/github/brainage04/modernminecraftmodtemplate([^_a-z0-9]|$)|modernminecraftmodtemplate\.(accesswidener|mixins\.json)|assets/modernminecraftmodtemplate/icon\.png' README.md build.gradle gradle.properties LICENSE src
    assert_no_match 'package [^;]*-' src

    if [ "${TEMPLATE_SMOKE_SKIP_BUILD:-false}" = "true" ]; then
      echo "Skipping generated ${side} Gradle build."
    else
      ./gradlew --no-daemon "${build_args[@]}"
    fi
  )
}

smoke_camel_case_name() {
  local target="$tmp_root/camel/MinecraftDesignStudio"
  local package_dir="io/github/brainage04/minecraftdesignstudio"
  local package_name="io.github.brainage04.minecraftdesignstudio"
  local main_class="MinecraftDesignStudio"

  echo "Testing init.sh preserves camel-case class names"
  copy_template "$target"

  (
    cd "$target"

    ./init.sh --side=client "MinecraftDesignStudio"

    assert_path_exists "src/main/java/${package_dir}/${main_class}.java"
    assert_path_exists "src/test/java/${package_dir}/${main_class}MetadataTest.java"
    assert_path_exists "src/gametest/java/${package_dir}/${main_class}GameTest.java"
    assert_json_string src/main/resources/fabric.mod.json '.entrypoints.client[0]' "${package_name}.${main_class}"
    assert_json_string src/gametest/resources/fabric.mod.json '.entrypoints["fabric-client-gametest"][0]' "${package_name}.${main_class}GameTest"
    assert_no_match 'Minecraftdesignstudio' src build.gradle gradle.properties README.md
  )
}

require_command rg
require_command jq
require_command tar

template_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_root="${TMPDIR:-/tmp}/fabric-template-smoke.$$"
trap 'rm -rf "$tmp_root" /tmp/template-smoke-rg.out' EXIT

smoke_side both
smoke_side server
smoke_side client
smoke_camel_case_name

echo "Template generation smoke tests passed."
