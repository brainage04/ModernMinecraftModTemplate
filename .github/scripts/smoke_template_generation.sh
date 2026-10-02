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
    --exclude=.fabric \
    -C "$template_root" \
    -cf - . |
    tar -C "$target" -xf -
}

prepare_conventions_dependency() {
  local target_parent="$1"
  local source
  local target="$target_parent/FabricModdingConventions"

  source="$(cd "$template_root/.." && pwd)/FabricModdingConventions"
  if [ ! -d "$source" ]; then
    echo "Missing sibling FabricModdingConventions checkout at $source" >&2
    exit 1
  fi

  # Generated projects resolve the convention plugins from ../FabricModdingConventions,
  # exactly like the template itself.
  if [ ! -e "$target" ]; then
    ln -s "$source" "$target"
  fi
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
  local common_java="common/src/main/java/${package_dir}"
  local common_resources="common/src/main/resources"
  local fabric_mod_json="fabric/src/main/resources/fabric.mod.json"
  local fabric_gametest_mod_json="fabric/src/gametest/resources/fabric.mod.json"
  local neoforge_mods_toml="neoforge/src/main/resources/META-INF/neoforge.mods.toml"

  echo "Testing init.sh --side=${side}"
  copy_template "$target"
  prepare_conventions_dependency "$(dirname "$target")"

  (
    cd "$target"

    if [ "$side" = "server" ]; then
      compact_json_in_place "$fabric_mod_json"
      compact_json_in_place "$fabric_gametest_mod_json"
    fi

    ./init.sh --side="$side" "ModernMinecraftModTemplate-${side}_42"

    assert_path_missing "init.sh"
    assert_path_missing ".github/workflows/init.yml"
    assert_path_missing ".github/scripts/smoke_template_generation.sh"
    assert_path_missing "src"
    assert_path_exists "${common_java}/config/ModConfig.java"
    assert_path_exists "${common_java}/${main_class}.java"
    assert_path_exists "${common_java}/platform/${main_class}Platform.java"
    assert_path_exists "fabric/src/test/java/${package_dir}/${main_class}MetadataTest.java"
    assert_path_exists "${common_resources}/${mod_id}.accesswidener"
    assert_path_exists "${common_resources}/assets/${mod_id}/icon.png"
    assert_path_exists "fabric/src/gametest/resources/assets/${mod_id}/icon.png"
    assert_path_exists "fabric/src/main/java/${package_dir}/fabric/${main_class}Fabric.java"
    assert_path_exists "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForge.java"
    assert_path_exists "neoforge/src/main/resources/META-INF/accesstransformer.cfg"
    assert_no_match 'smoke_template_generation' .github/workflows/build.yml
    assert_no_match 'scripts=\(\.github/scripts/\*\.sh\)|shellcheck "\$\{scripts\[@\]\}"|init\.sh' .github/workflows/build.yml
    assert_match "additional_artifact_pattern: ${mod_id}-neoforge-\\*\\.jar" .github/workflows/release.yml
    assert_match "curseforge_project_slug: ${mod_id}\$" .github/workflows/release.yml
    assert_match "^rootProject\\.name = 'ModernMinecraftModTemplate-${side}_42'\$" settings.gradle
    assert_match 'io\.github\.brainage04\.multiloader-mod-conventions' build.gradle settings.gradle

    assert_json_string "$fabric_mod_json" '.environment' "$(if [ "$side" = "client" ]; then printf client; else printf '*'; fi)"
    assert_json_string "$fabric_mod_json" '.icon' "assets/${mod_id}/icon.png"
    assert_json_string "$fabric_mod_json" '.accessWidener' "${mod_id}.accesswidener"
    assert_json_string "$fabric_gametest_mod_json" '.environment' "$(if [ "$side" = "client" ]; then printf client; else printf '*'; fi)"
    assert_json_string "$fabric_gametest_mod_json" '.icon' "assets/${mod_id}/icon.png"
    assert_json_string "$fabric_mod_json" 'type' object
    assert_json_string "$fabric_mod_json" 'keys_unsorted[0]' schemaVersion
    assert_json_string "$fabric_gametest_mod_json" 'keys_unsorted[0]' schemaVersion
    assert_json_string "$fabric_mod_json" '.contact.homepage' "https://github.com/brainage04/ModernMinecraftModTemplate-${side}_42"
    assert_json_string "$fabric_mod_json" '.contact.sources' "https://github.com/brainage04/ModernMinecraftModTemplate-${side}_42"
    assert_json_string "$fabric_gametest_mod_json" 'type' object
    assert_match "^modId=\"${mod_id}\"\$" "$neoforge_mods_toml"
    assert_match "^displayName=\"${main_class}\"\$" "$neoforge_mods_toml"
    assert_match "^\\[\\[dependencies\\.${mod_id}\\]\\]\$" "$neoforge_mods_toml"
    assert_match "^displayURL=\"https://github\\.com/brainage04/ModernMinecraftModTemplate-${side}_42\"\$" "$neoforge_mods_toml"
    assert_match "${mod_id}\\.accesswidener" neoforge/src/main/resources/META-INF/accesstransformer.cfg

    if [ "$side" = "server" ]; then
      assert_path_missing "fabric/src/client"
      assert_path_missing "${common_java}/${main_class}Client.java"
      assert_path_missing "${common_java}/platform/${main_class}ClientPlatform.java"
      assert_path_missing "${common_java}/command/ExampleClientCommand.java"
      assert_path_missing "${common_java}/command/core/ClientModCommands.java"
      assert_path_missing "${common_java}/mixin/client"
      assert_path_missing "${common_resources}/${mod_id}.client.mixins.json"
      assert_path_missing "${common_resources}/assets/${mod_id}/lang"
      assert_path_missing "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForgeClient.java"
      assert_path_missing "fabric/src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_exists "${common_java}/command/ExampleCommand.java"
      assert_path_exists "${common_java}/mixin/ExampleMixin.java"
      assert_path_exists "${common_resources}/${mod_id}.mixins.json"
      assert_path_exists "common/src/gametest/java/${package_dir}/${main_class}GameTests.java"
      assert_path_exists "fabric/src/gametest/java/${package_dir}/${main_class}GameTest.java"
      assert_path_exists "neoforge/src/gametest/java/${package_dir}/neoforge/${main_class}NeoForgeGameTest.java"
      assert_path_exists "neoforge/src/gametest/resources/data/${mod_id}/test_instance/example_command_is_registered.json"
      assert_path_exists "fabric/src/test/java/${package_dir}/command/ExampleCommandTest.java"
      assert_match 'reusable-client-gametests\.yml@' .github/workflows/build.yml
      assert_match 'fabricClientGameTests = false' build.gradle
      assert_no_match 'neoForgeGameTests' build.gradle
      assert_no_match 'modmenu|terraformersmc|clientGameTestRecorder' fabric/build.gradle gradle.properties
      assert_match 'me\.shedaniel\.cloth:cloth-config-fabric' fabric/build.gradle
      assert_no_match 'client\.mixins\.json' "$neoforge_mods_toml"
      assert_json_compact "$fabric_mod_json" '.entrypoints' "{\"main\":[\"${package_name}.fabric.${main_class}Fabric\"]}"
      assert_json_compact "$fabric_mod_json" '.mixins' "[\"${mod_id}.mixins.json\"]"
      assert_json_compact "$fabric_gametest_mod_json" '.entrypoints' "{\"fabric-gametest\":[\"${package_name}.${main_class}GameTest\"]}"
    elif [ "$side" = "both" ]; then
      assert_path_exists "${common_java}/${main_class}Client.java"
      assert_path_exists "${common_java}/platform/${main_class}ClientPlatform.java"
      assert_path_exists "${common_java}/command/ExampleCommand.java"
      assert_path_exists "${common_java}/command/ExampleClientCommand.java"
      assert_path_exists "${common_java}/command/core/ClientModCommands.java"
      assert_path_exists "${common_java}/mixin/ExampleMixin.java"
      assert_path_exists "${common_java}/mixin/client/ExampleClientMixin.java"
      assert_path_exists "${common_resources}/${mod_id}.mixins.json"
      assert_path_exists "${common_resources}/${mod_id}.client.mixins.json"
      assert_path_exists "${common_resources}/assets/${mod_id}/lang/en_us.json"
      assert_path_exists "fabric/src/client/java/${package_dir}/fabric/${main_class}FabricClient.java"
      assert_path_exists "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForgeClient.java"
      assert_path_exists "common/src/gametest/java/${package_dir}/${main_class}GameTests.java"
      assert_path_exists "fabric/src/gametest/java/${package_dir}/${main_class}GameTest.java"
      assert_path_exists "fabric/src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_exists "neoforge/src/gametest/java/${package_dir}/neoforge/${main_class}NeoForgeGameTest.java"
      assert_path_exists "fabric/src/test/java/${package_dir}/command/ExampleCommandTest.java"
      assert_match 'reusable-client-gametests\.yml@' .github/workflows/build.yml
      assert_no_match 'multiLoaderModConventions' build.gradle
      assert_match 'com\.terraformersmc:modmenu' fabric/build.gradle
      assert_path_exists "fabric/src/client/java/${package_dir}/fabric/ModMenuIntegration.java"
      assert_match 'IConfigScreenFactory' "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForgeClient.java"
      assert_match "config=\"${mod_id}\\.client\\.mixins\\.json\"" "$neoforge_mods_toml"
      assert_json_compact "$fabric_mod_json" '.entrypoints | to_entries | sort_by(.key) | from_entries' "{\"client\":[\"${package_name}.fabric.${main_class}FabricClient\"],\"main\":[\"${package_name}.fabric.${main_class}Fabric\"],\"modmenu\":[\"${package_name}.fabric.ModMenuIntegration\"]}"
      assert_json_compact "$fabric_mod_json" '.mixins' "[\"${mod_id}.mixins.json\",{\"config\":\"${mod_id}.client.mixins.json\",\"environment\":\"client\"}]"
      assert_json_compact "$fabric_gametest_mod_json" '.entrypoints | to_entries | sort_by(.key) | from_entries' "{\"fabric-client-gametest\":[\"${package_name}.${main_class}ClientGameTest\"],\"fabric-gametest\":[\"${package_name}.${main_class}GameTest\"]}"
    else
      assert_path_missing "fabric/src/client"
      assert_path_missing "common/src/gametest"
      assert_path_missing "neoforge/src/gametest"
      assert_path_missing "${common_java}/${main_class}Client.java"
      assert_path_missing "${common_java}/platform/${main_class}ClientPlatform.java"
      assert_path_missing "${common_resources}/${mod_id}.mixins.json"
      assert_path_exists "${common_resources}/${mod_id}.client.mixins.json"
      assert_path_exists "${common_java}/command/ExampleCommand.java"
      assert_path_exists "${common_java}/command/core/ModCommands.java"
      assert_path_exists "${common_java}/mixin/ExampleMixin.java"
      assert_path_missing "${common_java}/command/ExampleClientCommand.java"
      assert_path_missing "${common_java}/command/core/ClientModCommands.java"
      assert_path_missing "${common_java}/mixin/client"
      assert_path_missing "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForgeClient.java"
      assert_path_exists "fabric/src/gametest/java/${package_dir}/${main_class}GameTest.java"
      assert_path_missing "fabric/src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_missing "fabric/src/test/java/${package_dir}/command/ExampleCommandTest.java"
      assert_path_exists "${common_resources}/assets/${mod_id}/lang/en_us.json"
      assert_match 'reusable-client-gametests\.yml@' .github/workflows/build.yml
      assert_match 'neoForgeGameTests = false' build.gradle
      assert_match 'com\.terraformersmc:modmenu' fabric/build.gradle
      assert_path_exists "fabric/src/main/java/${package_dir}/fabric/ModMenuIntegration.java"
      assert_match 'IConfigScreenFactory' "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForge.java"
      assert_match 'dist = Dist\.CLIENT' "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForge.java"
      assert_no_match 'side="BOTH"' "$neoforge_mods_toml"
      assert_no_match "config=\"${mod_id}\\.mixins\\.json\"" "$neoforge_mods_toml"
      assert_no_match "ExampleClientCommand|ClientModCommands|ExampleClientMixin|${main_class}Client|registerCommands" common fabric neoforge build.gradle README.md
      assert_json_compact "$fabric_mod_json" '.entrypoints' "{\"client\":[\"${package_name}.fabric.${main_class}Fabric\"],\"modmenu\":[\"${package_name}.fabric.ModMenuIntegration\"]}"
      assert_json_compact "$fabric_mod_json" '.mixins' "[\"${mod_id}.client.mixins.json\"]"
      assert_json_compact "$fabric_gametest_mod_json" '.entrypoints' "{\"fabric-client-gametest\":[\"${package_name}.${main_class}GameTest\"]}"
    fi

    grep -qx "maven_group=${package_name}" gradle.properties
    grep -qx "mod_side=${side}" gradle.properties
    assert_no_match 'net\.fabricmc|net\.neoforged|dev\.architectury' common
    assert_no_match '(?i)fzzy|kotlin|devauth' README.md build.gradle gradle.properties common fabric neoforge .modrinth
    assert_match 'cloth_config' "$neoforge_mods_toml"
    assert_no_match 'ExampleConfig' README.md build.gradle gradle.properties LICENSE common fabric neoforge
    assert_no_match 'com\.example|io\.github\.brainage04\.modernminecraftmodtemplate([^_a-z0-9]|$)|io/github/brainage04/modernminecraftmodtemplate([^_a-z0-9]|$)|modernminecraftmodtemplate\.(accesswidener|mixins\.json)|assets/modernminecraftmodtemplate/icon\.png|ModernMinecraftModTemplate([^A-Z0-9-]|$)' README.md build.gradle gradle.properties LICENSE common fabric neoforge
    assert_no_match 'package [^;]*-' common fabric neoforge
    # Single-loader tasks are :fabric:<task> / :neoforge:<task>; the root only aggregates both loaders.
    assert_no_match 'runFabricClient|runNeoForgeClient|runNeoForgeGameTests|runAllProductionGameTests|gameTestServer|(^|[^:])(runClientGameTest|recordClientGameTest)' README.md

    if [ "${TEMPLATE_SMOKE_SKIP_BUILD:-false}" = "true" ]; then
      echo "Skipping generated ${side} Gradle build."
    else
      ./gradlew --no-daemon --console=plain build
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

    assert_path_exists "common/src/main/java/${package_dir}/${main_class}.java"
    assert_path_exists "fabric/src/main/java/${package_dir}/fabric/${main_class}Fabric.java"
    assert_path_exists "neoforge/src/main/java/${package_dir}/neoforge/${main_class}NeoForge.java"
    assert_path_exists "fabric/src/test/java/${package_dir}/${main_class}MetadataTest.java"
    assert_path_exists "fabric/src/gametest/java/${package_dir}/${main_class}GameTest.java"
    assert_json_string fabric/src/main/resources/fabric.mod.json '.entrypoints.client[0]' "${package_name}.fabric.${main_class}Fabric"
    assert_json_string fabric/src/gametest/resources/fabric.mod.json '.entrypoints["fabric-client-gametest"][0]' "${package_name}.${main_class}GameTest"
    assert_no_match 'Minecraftdesignstudio' common fabric neoforge build.gradle gradle.properties README.md
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
