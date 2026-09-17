#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [--side=both|server|client] <mod_name>"
}

sanitize_mod_id() {
  local value

  value=$(
    printf '%s\n' "$1" |
      tr '[:upper:]' '[:lower:]' |
      sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g'
  )

  if [ -z "$value" ]; then
    value="mod"
  elif [[ ! "$value" =~ ^[a-z] ]]; then
    value="mod_${value}"
  fi

  printf '%s\n' "$value"
}

sanitize_class_name() {
  local value

  value=$(
    printf '%s\n' "$1" |
      awk '
      {
        gsub(/[^[:alnum:]]+/, " ")
        for (i = 1; i <= NF; i++) {
          word = $i
          out = out toupper(substr(word, 1, 1)) substr(word, 2)
        }
      }
      END {
        if (out == "") {
          out = "Mod"
        } else if (out ~ /^[0-9]/) {
          out = "Mod" out
        }
        print out
      }
    '
  )

  printf '%s\n' "$value"
}

sed_escape_replacement() {
  printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'
}

sed_escape_path_replacement() {
  printf '%s\n' "$1" | sed -e 's/[#&]/\\&/g'
}

side="both"
positionals=()
preserve_workflows="${INIT_PRESERVE_WORKFLOWS:-false}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --side=*)
      side="${1#*=}"
      shift
      ;;
    --side)
      if [ "$#" -lt 2 ]; then
        usage
        exit 1
      fi
      side="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if [ "${#positionals[@]}" -ne 1 ]; then
  usage
  exit 1
fi

case "$side" in
  both | server | client) ;;
  *)
    echo "Invalid side: $side"
    usage
    exit 1
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing required command: jq" >&2
  exit 1
fi

base=$(dirname "$(readlink -f "$0")")
echo "Updating $base"

mod_name_raw="${positionals[0]}"
mod_name_spaces=$(
  printf '%s\n' "$mod_name_raw" |
    sed -E 's/([A-Z])/ \1/g' |
    sed -E 's/[^[:alnum:]]+/ /g' |
    sed -E 's/^ //'
)
mod_name="$(sanitize_class_name "$mod_name_raw")"
mod_id="$(sanitize_mod_id "$mod_name_raw")"
package_name="io.github.brainage04.${mod_id}"
package_dir=$(echo "$package_name" | tr . /)

mod_name_replacement="$(sed_escape_replacement "$mod_name")"
mod_id_replacement="$(sed_escape_replacement "$mod_id")"
package_name_replacement="$(sed_escape_replacement "$package_name")"
package_dir_replacement="$(sed_escape_path_replacement "$package_dir")"
package_name_placeholder="__INIT_PACKAGE_NAME__"
package_dir_placeholder="__INIT_PACKAGE_DIR__"

echo "Setting mod name to $mod_name_raw ($mod_name_spaces)"
echo "Setting main class name to $mod_name"
echo "Setting mod id to $mod_id"
echo "Setting side to $side"
echo "Setting package name to $package_name"
echo "Setting package dir to $package_dir"
if [ "$preserve_workflows" = "true" ]; then
  echo "Preserving GitHub Actions workflow files"
fi

(
  if [ "${INIT_TRACE:-false}" = "true" ]; then
    set -x
  fi

  move_package_tree() {
    local source_root="$1"
    local target_root="$2"
    local staging_root
    local module_root
    local current

    if [ "$source_root" = "$target_root" ]; then
      return
    fi

    staging_root=$(mktemp -d "$base"/.init-package-tree.XXXXXX)
    shopt -s dotglob nullglob
    mv "$source_root"/* "$staging_root"/
    shopt -u dotglob nullglob

    mkdir -p "$(dirname "$target_root")"
    mv "$staging_root" "$target_root"

    module_root=$(dirname "$(dirname "$(dirname "$source_root")")")
    current="$source_root"
    while [ "$current" != "$module_root" ]; do
      rmdir --ignore-fail-on-non-empty "$current"
      current=$(dirname "$current")
    done
  }

  merge_tree() {
    local source_root="$1"
    local target_root="$2"

    if [ ! -d "$source_root" ]; then
      return
    fi

    mkdir -p "$target_root"
    cp -a "$source_root"/. "$target_root"/
  }

  rewrite_json() {
    local file="$1"
    local filter="$2"
    local temporary

    shift 2
    temporary=$(mktemp "${file}.tmp.XXXXXX")
    if ! jq --exit-status --tab "$@" "$filter" "$file" >"$temporary"; then
      rm -f "$temporary"
      return 1
    fi
    if ! chmod --reference="$file" "$temporary" || ! mv -f "$temporary" "$file"; then
      rm -f "$temporary"
      return 1
    fi
  }

  find_paths=(
    "$base/src/main"
    "$base/src/test"
    "$base/src/gametest"
    "$base/src/client"
  )

  # Use placeholders so later replacements cannot rewrite text inserted by
  # earlier replacements. This matters when the new mod id contains the
  # template mod id as a prefix.
  find "${find_paths[@]}" -type f ! -name 'fabric.mod.json' -exec sed -i \
    -e "s/io\.github\.brainage04\.modernminecraftmodtemplate/$package_name_placeholder/g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g" \
    -e "s/$package_name_placeholder/$package_name_replacement/g" {} +

  # Workflow files live outside src, so they need the same placeholder rewrite as
  # the sources: release.yml carried the template's CurseForge/Modrinth slug into
  # every generated repository until this ran here as well.
  # The capitalised template name is deliberately left alone: build.yml uses it in
  # repository checks that must stay false in a generated repository.
  find "$base/.github/workflows" -type f -name '*.yml' -exec sed -i \
    -e "s/io\.github\.brainage04\.modernminecraftmodtemplate/$package_name_placeholder/g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/$package_name_placeholder/$package_name_replacement/g" {} +

  # jq variables in this filter are populated by --arg, not expanded by the shell.
  # shellcheck disable=SC2016
  rewrite_json "$base/src/main/resources/fabric.mod.json" '
		{schemaVersion: .schemaVersion} + del(.schemaVersion)
		| .contact.homepage = $repository_url
		| .contact.sources = $repository_url
		| .icon = ("assets/" + $mod_id + "/icon.png")
		| .environment = "*"
		| .entrypoints = {
			client: [($package_name + "." + $main_class + "Client")],
			main: [($package_name + "." + $main_class)]
		}
		| .mixins = [
			($mod_id + ".mixins.json"),
			{
				config: ($mod_id + ".client.mixins.json"),
				environment: "client"
			}
		]
		| .accessWidener = ($mod_id + ".accesswidener")
	' \
    --arg repository_url "https://github.com/brainage04/${mod_name_raw}" \
    --arg mod_id "$mod_id" \
    --arg package_name "$package_name" \
    --arg main_class "$mod_name"

  # jq variables in this filter are populated by --arg, not expanded by the shell.
  # shellcheck disable=SC2016
  rewrite_json "$base/src/gametest/resources/fabric.mod.json" '
		{schemaVersion: .schemaVersion} + del(.schemaVersion)
		| .icon = ("assets/" + $mod_id + "/icon.png")
		| .environment = "*"
		| .entrypoints = {
			"fabric-client-gametest": [($package_name + "." + $main_class + "ClientGameTest")],
			"fabric-gametest": [($package_name + "." + $main_class + "GameTest")]
		}
	' \
    --arg mod_id "$mod_id" \
    --arg package_name "$package_name" \
    --arg main_class "$mod_name"

  sed -i \
    -e "s/^mod_side=.*/mod_side=$side/" \
    -e "s/io\.github\.brainage04\.modernminecraftmodtemplate/$package_name_placeholder/g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g" \
    -e "s/$package_name_placeholder/$package_name_replacement/g" "$base/gradle.properties"

  if [ -f "$base/.project" ]; then
    sed -i \
      -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g" "$base/.project"
  fi

  sed -i \
    -e "s#io/github/brainage04/modernminecraftmodtemplate#$package_dir_placeholder#g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g" \
    -e "s#$package_dir_placeholder#$package_dir_replacement#g" "$base/README.md"

  # refactor accesswidener and mixin file names
  mv "$base"/src/main/resources/modernminecraftmodtemplate.accesswidener "$base"/src/main/resources/"$mod_id".accesswidener
  mv "$base"/src/main/resources/modernminecraftmodtemplate.mixins.json "$base"/src/main/resources/"$mod_id".mixins.json
  mv "$base"/src/client/resources/modernminecraftmodtemplate.client.mixins.json "$base"/src/client/resources/"$mod_id".client.mixins.json

  # refactor assets directory
  mv "$base"/src/main/resources/assets/modernminecraftmodtemplate "$base"/src/main/resources/assets/"$mod_id"
  mv "$base"/src/client/resources/assets/modernminecraftmodtemplate "$base"/src/client/resources/assets/"$mod_id"
  mv "$base"/src/gametest/resources/assets/modernminecraftmodtemplate "$base"/src/gametest/resources/assets/"$mod_id"

  # rename main class
  mv "$base"/src/main/java/io/github/brainage04/modernminecraftmodtemplate/ModernMinecraftModTemplate.java "$base"/src/main/java/io/github/brainage04/modernminecraftmodtemplate/"$mod_name".java
  mv "$base"/src/test/java/io/github/brainage04/modernminecraftmodtemplate/ModernMinecraftModTemplateMetadataTest.java "$base"/src/test/java/io/github/brainage04/modernminecraftmodtemplate/"$mod_name"MetadataTest.java
  mv "$base"/src/gametest/java/io/github/brainage04/modernminecraftmodtemplate/ModernMinecraftModTemplateGameTest.java "$base"/src/gametest/java/io/github/brainage04/modernminecraftmodtemplate/"$mod_name"GameTest.java
  mv "$base"/src/gametest/java/io/github/brainage04/modernminecraftmodtemplate/ModernMinecraftModTemplateClientGameTest.java "$base"/src/gametest/java/io/github/brainage04/modernminecraftmodtemplate/"$mod_name"ClientGameTest.java
  if [ "$side" != "server" ]; then
    mv "$base"/src/client/java/io/github/brainage04/modernminecraftmodtemplate/ModernMinecraftModTemplateClient.java "$base"/src/client/java/io/github/brainage04/modernminecraftmodtemplate/"$mod_name"Client.java
  fi

  # lastly, refactor package directory
  move_package_tree "$base"/src/main/java/io/github/brainage04/modernminecraftmodtemplate "$base"/src/main/java/"$package_dir"
  move_package_tree "$base"/src/test/java/io/github/brainage04/modernminecraftmodtemplate "$base"/src/test/java/"$package_dir"
  move_package_tree "$base"/src/gametest/java/io/github/brainage04/modernminecraftmodtemplate "$base"/src/gametest/java/"$package_dir"

  if [ "$side" != "server" ]; then
    move_package_tree "$base"/src/client/java/io/github/brainage04/modernminecraftmodtemplate "$base"/src/client/java/"$package_dir"
  fi

  case "$side" in
    both) ;;
    server)
      rewrite_json "$base"/src/main/resources/fabric.mod.json '
			del(.entrypoints.client)
			| .mixins |= map(select(type != "object" or .environment != "client"))
		'
      rewrite_json "$base"/src/gametest/resources/fabric.mod.json '
			del(.entrypoints["fabric-client-gametest"])
		'
      sed -i "/^[[:space:]]*id 'io\.github\.brainage04\.client-gametest-recorder' version/d" "$base"/build.gradle
      rm -f "$base"/scripts/run-client-gametest-recorded.sh
      rmdir --ignore-fail-on-non-empty "$base"/scripts 2>/dev/null || true
      perl -0pi -e 's/common code in `src\/main`, client-only code in `src\/client`, and GameTests in `src\/gametest`/common code in `src\/main` and GameTests in `src\/gametest`/' "$base"/README.md
      sed -i '/launches the client side/d' "$base"/README.md
      perl -0pi -e 's/For client-side GameTests, run:\n\n```shell\n\.\/gradlew runClientGameTest\n```\n\n.*?scripts\/run-client-gametest-recorded\.sh\n```\n\n//s' "$base"/README.md
      rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"ClientGameTest.java
      rm -rf "$base"/src/client
      rm -f "$base"/run/options.txt
      ;;
    client)
      rewrite_json "$base"/src/main/resources/fabric.mod.json '
			.environment = "client"
			| .entrypoints.client |= map(sub("Client$"; ""))
			| del(.entrypoints.main)
			| .mixins |= [
				.[]
				| select(type == "object" and .environment == "client")
				| .config
			]
		'
      rewrite_json "$base"/src/gametest/resources/fabric.mod.json '
			.environment = "client"
			| .entrypoints["fabric-client-gametest"] |= map(sub("ClientGameTest$"; "GameTest"))
			| del(.entrypoints["fabric-gametest"])
		'
      sed -i \
        -e 's/assertEquals(EnvType.SERVER/assertEquals(EnvType.CLIENT/' \
        -e 's/fabricLoaderBootsInServerModeForTests/fabricLoaderBootsInClientModeForTests/' \
        "$base"/src/test/java/"$package_dir"/"$mod_name"MetadataTest.java
      perl -0pi -e 's/common code in `src\/main`, client-only code in `src\/client`, and GameTests in `src\/gametest`/client-only code in `src\/main` and client-side GameTests in `src\/gametest`/' "$base"/README.md
      sed -i '/launches the common\/server side/d' "$base"/README.md
      sed -i '/server command example/d' "$base"/README.md
      sed -i '/Plain unit tests for your own code, such as command registration/d' "$base"/README.md
      perl -0pi -e 's/For integration-style server tests, run:\n\n```shell\n\.\/gradlew runGameTest\n```\n\nThe template includes a separate `src\/gametest` source set with a minimal server GameTest that checks the example command was registered on the server\.\nServer GameTests also run automatically as part of `\.\/gradlew build`, which is what the included GitHub Actions workflow executes\.\n\n//' "$base"/README.md
      sed -i \
        -e '/import .*command\.core\.ModCommands;/d' \
        -e '/ModCommands\.initialize();/d' "$base"/src/main/java/"$package_dir"/"$mod_name".java
      cat >"$base"/src/client/java/"$package_dir"/"$mod_name".java <<EOF
package $package_name;

import $package_name.command.core.ModCommands;
import $package_name.config.ModConfig;
import net.fabricmc.api.ClientModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ${mod_name} implements ClientModInitializer {
    public static final String MOD_ID = "$mod_id";
    public static final String MOD_NAME = "$mod_name";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_NAME);

    private static volatile boolean initialized;

    @Override
    public void onInitializeClient() {
        LOGGER.info("{} client initialising...", MOD_NAME);

        ModCommands.initialize();
        ModConfig.init();

        if (ModConfig.CONFIG.logConfigOnStartup.get()) {
            LOGGER.info(
                    "Loaded config: message='{}', mode={}, featuredItem={}, retries={}",
                    ModConfig.CONFIG.welcomeMessage.get(),
                    ModConfig.CONFIG.syncMode.get(),
                    ModConfig.CONFIG.featuredItem.get(),
                    ModConfig.CONFIG.startupRetries.get()
            );
        }

        initialized = true;

        LOGGER.info("{} client initialised.", MOD_NAME);
    }

    public static boolean isInitialized() {
        return initialized;
    }
}
EOF
      rm -f "$base"/src/main/java/"$package_dir"/command/ExampleCommand.java
      rm -f "$base"/src/main/java/"$package_dir"/command/core/ModCommands.java
      rm -f "$base"/src/main/java/"$package_dir"/mixin/ExampleMixin.java
      rmdir --ignore-fail-on-non-empty "$base"/src/main/java/"$package_dir"/command/core "$base"/src/main/java/"$package_dir"/command
      rm -rf "$base"/src/test/java/"$package_dir"/command
      rm -f "$base"/src/main/java/"$package_dir"/"$mod_name".java
      rm -f "$base"/src/client/java/"$package_dir"/"$mod_name"Client.java
      rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"GameTest.java
      rm -f "$base"/src/main/resources/"$mod_id".mixins.json
      merge_tree "$base"/src/client/java "$base"/src/main/java
      merge_tree "$base"/src/client/resources "$base"/src/main/resources
      rm -rf "$base"/src/client
      mv "$base"/src/main/java/"$package_dir"/command/ExampleClientCommand.java "$base"/src/main/java/"$package_dir"/command/ExampleCommand.java
      sed -i \
        -e 's/ExampleClientCommand/ExampleCommand/g' \
        -e 's/"exampleclient"/"example"/g' \
        -e 's/example client command/example command/g' \
        "$base"/src/main/java/"$package_dir"/command/ExampleCommand.java
      mv "$base"/src/main/java/"$package_dir"/command/core/ClientModCommands.java "$base"/src/main/java/"$package_dir"/command/core/ModCommands.java
      sed -i \
        -e 's/ClientModCommands/ModCommands/g' \
        -e 's/ExampleClientCommand/ExampleCommand/g' \
        "$base"/src/main/java/"$package_dir"/command/core/ModCommands.java
      mv "$base"/src/main/java/"$package_dir"/mixin/client/ExampleClientMixin.java "$base"/src/main/java/"$package_dir"/mixin/ExampleMixin.java
      rmdir --ignore-fail-on-non-empty "$base"/src/main/java/"$package_dir"/mixin/client
      sed -i \
        -e "s/package ${package_name_replacement}\\.mixin\\.client;/package ${package_name_replacement}.mixin;/" \
        -e 's/ExampleClientMixin/ExampleMixin/g' \
        "$base"/src/main/java/"$package_dir"/mixin/ExampleMixin.java
      sed -i \
        -e "s/${package_name_replacement}\\.mixin\\.client/${package_name_replacement}.mixin/g" \
        -e 's/ExampleClientMixin/ExampleMixin/g' \
        "$base"/src/main/resources/"$mod_id".client.mixins.json
      mv "$base"/src/gametest/java/"$package_dir"/"$mod_name"ClientGameTest.java "$base"/src/gametest/java/"$package_dir"/"$mod_name"GameTest.java
      sed -i \
        -e "s/${mod_name_replacement}ClientGameTest/${mod_name_replacement}GameTest/g" \
        -e "s/${mod_name_replacement}Client\\.isInitialized()/${mod_name_replacement}.isInitialized()/g" \
        "$base"/src/gametest/java/"$package_dir"/"$mod_name"GameTest.java
      ;;
  esac

  if [ "$preserve_workflows" != "true" ]; then
    perl -0pi -e 's/\n      # BEGIN TEMPLATE SCRIPT CHECKS\n.*?\n      # END TEMPLATE SCRIPT CHECKS\n//s' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n      # BEGIN TEMPLATE MODRINTH SCRIPT TESTS\n.*?\n      # END TEMPLATE MODRINTH SCRIPT TESTS\n//s' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n      # BEGIN TEMPLATE SMOKE TESTS\n.*?\n      # END TEMPLATE SMOKE TESTS\n//s' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n    with:\n(?=\n)//g' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n{3,}/\n\n/g' "$base"/.github/workflows/build.yml
  fi
  rm -f "$base"/.github/scripts/smoke_template_generation.sh
  rm -f "$base"/.github/scripts/test_modrinth_scripts.sh
  if [ "$preserve_workflows" != "true" ]; then
    rm "$base"/.github/workflows/init.yml
  fi
  rm "$(readlink -f "$0")"
)

echo "Refactor completed successfully"
