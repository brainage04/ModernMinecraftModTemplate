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
repository_url="https://github.com/brainage04/${mod_name_raw}"
repository_url_replacement="$(sed_escape_path_replacement "$repository_url")"
package_name_placeholder="__INIT_PACKAGE_NAME__"
package_dir_placeholder="__INIT_PACKAGE_DIR__"
repository_url_placeholder="__INIT_REPOSITORY_URL__"

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

  module_sources=(
    "$base/common/src"
    "$base/fabric/src"
    "$base/neoforge/src"
  )

  common_java="$base/common/src/main/java/$package_dir"
  common_resources="$base/common/src/main/resources"
  fabric_java="$base/fabric/src/main/java/$package_dir"
  fabric_gametest_java="$base/fabric/src/gametest/java/$package_dir"
  fabric_test_java="$base/fabric/src/test/java/$package_dir"
  neoforge_java="$base/neoforge/src/main/java/$package_dir"
  neoforge_mods_toml="$base/neoforge/src/main/resources/META-INF/neoforge.mods.toml"
  fabric_mod_json="$base/fabric/src/main/resources/fabric.mod.json"
  fabric_gametest_mod_json="$base/fabric/src/gametest/resources/fabric.mod.json"

  # Use placeholders so later replacements cannot rewrite text inserted by
  # earlier replacements. This matters when the new mod id contains the
  # template mod id as a prefix, or the repository name contains the template name.
  find "${module_sources[@]}" -type f ! -name 'fabric.mod.json' ! -name '*.png' -exec sed -i \
    -e "s#https://github\.com/brainage04/ModernMinecraftModTemplate#$repository_url_placeholder#g" \
    -e "s/io\.github\.brainage04\.modernminecraftmodtemplate/$package_name_placeholder/g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g" \
    -e "s/$package_name_placeholder/$package_name_replacement/g" \
    -e "s#$repository_url_placeholder#$repository_url_replacement#g" {} +

  # Rename every file and directory named after the template (packages, classes,
  # mixin configs, the access widener, asset and data namespaces). -depth renames
  # children before their parents, so every path stays valid while it is renamed.
  find "${module_sources[@]}" -depth \( -name '*modernminecraftmodtemplate*' -o -name '*ModernMinecraftModTemplate*' \) -print0 |
    while IFS= read -r -d '' path; do
      name=$(basename "$path")
      renamed=$(
        printf '%s\n' "$name" |
          sed \
            -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
            -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g"
      )
      mv "$path" "$(dirname "$path")/$renamed"
    done

  # Workflow files live outside the modules, so they need the same placeholder rewrite as
  # the sources: release.yml carried the template's CurseForge/Modrinth slug and NeoForge
  # artifact pattern into every generated repository until this ran here as well.
  # The capitalised template name is deliberately left alone: build.yml uses it in
  # repository checks that must stay false in a generated repository.
  find "$base/.github/workflows" -type f -name '*.yml' -exec sed -i \
    -e "s/io\.github\.brainage04\.modernminecraftmodtemplate/$package_name_placeholder/g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/$package_name_placeholder/$package_name_replacement/g" {} +

  # jq variables in this filter are populated by --arg, not expanded by the shell.
  # shellcheck disable=SC2016
  rewrite_json "$fabric_mod_json" '
		{schemaVersion: .schemaVersion} + del(.schemaVersion)
		| .contact.homepage = $repository_url
		| .contact.sources = $repository_url
		| .icon = ("assets/" + $mod_id + "/icon.png")
		| .environment = "*"
		| .entrypoints = {
			client: [($package_name + ".fabric." + $main_class + "FabricClient")],
			main: [($package_name + ".fabric." + $main_class + "Fabric")]
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
    --arg repository_url "$repository_url" \
    --arg mod_id "$mod_id" \
    --arg package_name "$package_name" \
    --arg main_class "$mod_name"

  # jq variables in this filter are populated by --arg, not expanded by the shell.
  # shellcheck disable=SC2016
  rewrite_json "$fabric_gametest_mod_json" '
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

  # The root project name is the repository name: the release conventions derive the
  # GitHub repository from it.
  sed -i -e "s#^rootProject\.name = .*#rootProject.name = '$(sed_escape_path_replacement "$mod_name_raw")'#" "$base/settings.gradle"

  sed -i \
    -e "s#io/github/brainage04/modernminecraftmodtemplate#$package_dir_placeholder#g" \
    -e "s/modernminecraftmodtemplate/$mod_id_replacement/g" \
    -e "s/ModernMinecraftModTemplate/$mod_name_replacement/g" \
    -e "s#$package_dir_placeholder#$package_dir_replacement#g" "$base/README.md"

  case "$side" in
    both) ;;
    server)
      rewrite_json "$fabric_mod_json" '
			del(.entrypoints.client)
			| .mixins |= map(select(type != "object" or .environment != "client"))
		'
      rewrite_json "$fabric_gametest_mod_json" '
			del(.entrypoints["fabric-client-gametest"])
		'

      rm -f \
        "$common_java/${mod_name}Client.java" \
        "$common_java/platform/${mod_name}ClientPlatform.java" \
        "$common_java/command/ExampleClientCommand.java" \
        "$common_java/command/core/ClientModCommands.java" \
        "$common_resources/${mod_id}.client.mixins.json" \
        "$neoforge_java/neoforge/${mod_name}NeoForgeClient.java" \
        "$fabric_gametest_java/${mod_name}ClientGameTest.java"
      rm -rf "$common_java/mixin/client" "$common_resources/assets/$mod_id/lang" "$base/fabric/src/client"
      perl -0pi -e 's/\n\[\[mixins\]\]\nconfig="[^"]*\.client\.mixins\.json"\n//' "$neoforge_mods_toml"

      # Mod Menu and the client GameTest recorder only serve a client entrypoint.
      perl -0pi -e 's/\n\t\/\/ ModMenu\n\timplementation "maven\.modrinth:modmenu:[^\n]*\n//; s/\n\tproductionRuntimeMods "maven\.modrinth:modmenu:[^\n]*//; s/\nclientGameTestRecorder \{\n.*?\n\}\n//s' "$base/fabric/build.gradle"
      sed -i '/^modmenu_version=/d' "$base/gradle.properties"
      cat >>"$base/build.gradle" <<'EOF'

multiLoaderModConventions {
	// Server-only mod: there is no client entrypoint for a client GameTest to exercise.
	fabricClientGameTests = false
}
EOF

      perl -0pi -e 's/ \(`src\/main`, plus `src\/client` for client-only code\)/ (`src\/main`)/' "$base/README.md"
      perl -0pi -e "s/: \`${mod_name}Platform\` for both sides and \`${mod_name}ClientPlatform\` for the client\\./: \`${mod_name}Platform\`./" "$base/README.md"
      sed -i '/Fzzy Config registers the example config screen/d' "$base/README.md"
      perl -0pi -e 's/a server command example \(`ExampleCommand`\) and a client command example \(`ExampleClientCommand`\) in `common`/a server command example (`ExampleCommand`) in `common`/' "$base/README.md"
      perl -0pi -e 's/runs the Fabric production client and server GameTests/runs the Fabric production server GameTests/' "$base/README.md"
      perl -0pi -e 's/For client-side GameTests, run:\n.*?(?=# Publishing\n)//s' "$base/README.md"
      ;;
    client)
      rewrite_json "$fabric_mod_json" '
			.environment = "client"
			| .entrypoints = {client: [.entrypoints.main[0]]}
			| .mixins |= [
				.[]
				| select(type == "object" and .environment == "client")
				| .config
			]
		'
      rewrite_json "$fabric_gametest_mod_json" '
			.environment = "client"
			| .entrypoints["fabric-client-gametest"] |= map(sub("ClientGameTest$"; "GameTest"))
			| del(.entrypoints["fabric-gametest"])
		'

      # Server-side pieces: the server command, the server mixin and the server GameTests.
      rm -f \
        "$common_java/command/ExampleCommand.java" \
        "$common_java/command/core/ModCommands.java" \
        "$common_java/mixin/ExampleMixin.java" \
        "$common_resources/${mod_id}.mixins.json" \
        "$fabric_gametest_java/${mod_name}GameTest.java" \
        "$neoforge_java/neoforge/${mod_name}NeoForge.java" \
        "$neoforge_java/neoforge/${mod_name}NeoForgeClient.java" \
        "$fabric_java/fabric/${mod_name}Fabric.java" \
        "$common_java/${mod_name}Client.java" \
        "$common_java/platform/${mod_name}ClientPlatform.java"
      rm -rf "$base/common/src/gametest" "$base/neoforge/src/gametest" "$fabric_test_java/command"

      # The client pieces take over the plain names.
      mv "$common_java/command/ExampleClientCommand.java" "$common_java/command/ExampleCommand.java"
      sed -i \
        -e 's/ExampleClientCommand/ExampleCommand/g' \
        -e 's/"exampleclient"/"example"/g' \
        -e 's/example client command/example command/g' \
        "$common_java/command/ExampleCommand.java"
      mv "$common_java/command/core/ClientModCommands.java" "$common_java/command/core/ModCommands.java"
      sed -i \
        -e 's/ClientModCommands/ModCommands/g' \
        -e 's/ExampleClientCommand/ExampleCommand/g' \
        "$common_java/command/core/ModCommands.java"
      mv "$common_java/mixin/client/ExampleClientMixin.java" "$common_java/mixin/ExampleMixin.java"
      rmdir "$common_java/mixin/client"
      sed -i \
        -e "s/package ${package_name_replacement}\\.mixin\\.client;/package ${package_name_replacement}.mixin;/" \
        -e 's/ExampleClientMixin/ExampleMixin/g' \
        "$common_java/mixin/ExampleMixin.java"
      sed -i \
        -e "s/${package_name_replacement}\\.mixin\\.client/${package_name_replacement}.mixin/g" \
        -e 's/ExampleClientMixin/ExampleMixin/g' \
        "$common_resources/${mod_id}.client.mixins.json"
      mv "$fabric_gametest_java/${mod_name}ClientGameTest.java" "$fabric_gametest_java/${mod_name}GameTest.java"
      sed -i \
        -e "s/${mod_name_replacement}ClientGameTest/${mod_name_replacement}GameTest/g" \
        -e "s/${mod_name_replacement}Client\\.isInitialized()/${mod_name_replacement}.isInitialized()/g" \
        "$fabric_gametest_java/${mod_name}GameTest.java"
      sed -i \
        -e 's/assertEquals(EnvType.SERVER/assertEquals(EnvType.CLIENT/' \
        -e 's/fabricLoaderBootsInServerModeForTests/fabricLoaderBootsInClientModeForTests/' \
        "$fabric_test_java/${mod_name}MetadataTest.java"

      cat >"$common_java/platform/${mod_name}Platform.java" <<EOF
package $package_name.platform;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.commands.SharedSuggestionProvider;

/**
 * The loader services common code needs, implemented once by each loader module's entrypoint.
 *
 * <p>Keep this contract small: add a method only when common code needs something that only the
 * loader can provide (an event, a registry hook, a path), and implement it in both loader modules.
 */
public interface ${mod_name}Platform {
    /** The loader's display name, for logs. */
    String loaderName();

    /** Registers client-side commands, which run without a server round trip. */
    void registerClientCommands(ClientCommandRegistration registration);

    /**
     * Registers client commands on a loader's dispatcher. Each loader uses its own command source
     * type, so common command trees are generic over it.
     */
    @FunctionalInterface
    interface ClientCommandRegistration {
        <S extends SharedSuggestionProvider> void register(CommandDispatcher<S> dispatcher);
    }
}
EOF
      cat >"$common_java/${mod_name}.java" <<EOF
package $package_name;

import $package_name.command.core.ModCommands;
import $package_name.config.ModConfig;
import $package_name.platform.${mod_name}Platform;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ${mod_name} {
    public static final String MOD_ID = "$mod_id";
    public static final String MOD_NAME = "$mod_name";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_NAME);

    private static volatile boolean initialized;

    private ${mod_name}() {}

    /** Called by each loader's client entrypoint. */
    public static void initialize(${mod_name}Platform platform) {
        LOGGER.info("{} initialising on {}...", MOD_NAME, platform.loaderName());

        ModConfig.init();
        platform.registerClientCommands(ModCommands::register);

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

        LOGGER.info("{} initialised.", MOD_NAME);
    }

    public static boolean isInitialized() {
        return initialized;
    }
}
EOF
      # Without a server side, Fabric has a single (client) source set.
      cat >"$fabric_java/fabric/${mod_name}Fabric.java" <<EOF
package $package_name.fabric;

import $package_name.${mod_name};
import $package_name.platform.${mod_name}Platform;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;

public final class ${mod_name}Fabric implements ClientModInitializer, ${mod_name}Platform {
    @Override
    public void onInitializeClient() {
        ${mod_name}.initialize(this);
    }

    @Override
    public String loaderName() {
        return "Fabric";
    }

    @Override
    public void registerClientCommands(ClientCommandRegistration registration) {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> registration.register(dispatcher));
    }
}
EOF
      rm -rf "$base/fabric/src/client"
      cat >"$neoforge_java/neoforge/${mod_name}NeoForge.java" <<EOF
package $package_name.neoforge;

import $package_name.${mod_name};
import $package_name.platform.${mod_name}Platform;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.client.event.RegisterClientCommandsEvent;
import net.neoforged.neoforge.common.NeoForge;

@Mod(value = ${mod_name}.MOD_ID, dist = Dist.CLIENT)
public final class ${mod_name}NeoForge implements ${mod_name}Platform {
    public ${mod_name}NeoForge() {
        ${mod_name}.initialize(this);
    }

    @Override
    public String loaderName() {
        return "NeoForge";
    }

    @Override
    public void registerClientCommands(ClientCommandRegistration registration) {
        NeoForge.EVENT_BUS.addListener((RegisterClientCommandsEvent event) -> registration.register(event.getDispatcher()));
    }
}
EOF
      perl -0pi -e 's/\n\[\[mixins\]\]\nconfig="[^"]*(?<!\.client)\.mixins\.json"\n//; s/side="BOTH"/side="CLIENT"/g' "$neoforge_mods_toml"
      cat >>"$base/build.gradle" <<'EOF'

multiLoaderModConventions {
	// Client-only mod: NeoForge GameTests run on a dedicated server, where this mod does nothing.
	neoForgeGameTests = false
}
EOF

      perl -0pi -e 's/ \(`src\/main`, plus `src\/client` for client-only code\)/ (`src\/main`)/' "$base/README.md"
      perl -0pi -e 's/ \(mirror every access widener entry there\) and the NeoForge GameTest registration\./ (mirror every access widener entry there)./' "$base/README.md"
      perl -0pi -e "s/: \`${mod_name}Platform\` for both sides and \`${mod_name}ClientPlatform\` for the client\\./: \`${mod_name}Platform\`./" "$base/README.md"
      sed -i '/GameTest bodies shared by both loaders live in/d' "$base/README.md"
      sed -i '/runServer` launch a dedicated server on each loader/d' "$base/README.md"
      perl -0pi -e 's/a server command example \(`ExampleCommand`\) and a client command example \(`ExampleClientCommand`\) in `common`/a client command example (`ExampleCommand`) in `common`/' "$base/README.md"
      sed -i '/Plain unit tests for your own code, such as command registration/d' "$base/README.md"
      perl -0pi -e 's/For integration-style server tests, run:\n.*?(?=For client-side GameTests, run:\n)/`.\/gradlew runAllProductionGameTests` runs the Fabric production client GameTests.\n\n/s' "$base/README.md"
      ;;
  esac

  # Drop directories left empty by the removals above.
  find "${module_sources[@]}" -depth -type d -empty -exec rmdir {} +

  if [ "$preserve_workflows" != "true" ]; then
    perl -0pi -e 's/\n      # BEGIN TEMPLATE SCRIPT CHECKS\n.*?\n      # END TEMPLATE SCRIPT CHECKS\n//s' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n      # BEGIN TEMPLATE SMOKE TESTS\n.*?\n      # END TEMPLATE SMOKE TESTS\n//s' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n    with:\n(?=\n)//g' "$base"/.github/workflows/build.yml
    perl -0pi -e 's/\n{3,}/\n\n/g' "$base"/.github/workflows/build.yml
  fi
  rm -f "$base"/.github/scripts/smoke_template_generation.sh
  rmdir "$base"/.github/scripts 2>/dev/null || true
  if [ "$preserve_workflows" != "true" ]; then
    rm "$base"/.github/workflows/init.yml
  fi
  rm "$(readlink -f "$0")"
)

echo "Refactor completed successfully"
