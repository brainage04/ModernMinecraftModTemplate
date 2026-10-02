# ModernMinecraftModTemplate

My template for modern Minecraft mods that ship a Fabric JAR and a NeoForge JAR from one codebase, built with the `io.github.brainage04.multiloader-mod-conventions` Gradle plugin from [FabricModdingConventions](https://github.com/brainage04/FabricModdingConventions).

The project is split into three Gradle modules:
  - `common` holds all mod logic: commands, config, mixins, the access widener, assets and data. It compiles against vanilla Minecraft and never imports `net.fabricmc.*` or `net.neoforged.*`.
  - `fabric` holds the Fabric entrypoints (`src/main`, plus `src/client` for client-only code), `fabric.mod.json`, the Fabric GameTests and the unit tests.
  - `neoforge` holds the NeoForge `@Mod` entrypoints, `META-INF/neoforge.mods.toml`, `META-INF/accesstransformer.cfg` (mirror every access widener entry there) and the NeoForge GameTest registration.

Common code reaches loader services through the small contract in `common/src/main/java/io/github/brainage04/modernminecraftmodtemplate/platform`: `ModernMinecraftModTemplatePlatform` for both sides and `ModernMinecraftModTemplateClientPlatform` for the client.
Each loader's entrypoint implements it by wiring the loader's own events, so the loader modules stay thin adapters.
GameTest bodies shared by both loaders live in `common/src/gametest/java`.

The easiest way to use this is:

1. Click `Use this template` and create your new repository.
2. Open the new repository's `Actions` tab.
3. Run the `Initialize Template Repo` workflow.
4. Choose `both`, `server`, or `client` for the mod side.

However, if you are using a Linux-based operating system, it is possible to clone this repository, and perform a refactor by triggering the `init.sh` script like so:
Local initialization requires `jq`; metadata changes are applied as validated JSON transformations rather than text substitutions.

```shell
./init.sh [--side=both|server|client] <mod_name>
```

Where `<mod_name>` is your GitHub repository name/mod name.
The optional `--side` flag defaults to `both`.
The script records the choice as `mod_side=both|client|server`; the convention plugin derives the Fabric source sets and GameTest tasks from that property.
Use `--side=server` to generate a server-only repo: it removes the client entrypoints, client commands, client mixins, Mod Menu and the client GameTest.
Use `--side=client` to generate a client-only repo: it removes the server entrypoints, server command, server mixin and the server GameTests on both loaders.
When the GitHub Actions workflow initializes a template repository, it uses the repository name as `<mod_name>`.
Generated packages always use `io.github.brainage04.<mod_id>`, where `<mod_id>` is sanitized from `<mod_name>` so it is safe for Fabric/NeoForge mod IDs and Java package names.

The workflow and script are designed to be run once. After successful initialization, they safely delete:
  - Leftover unused folders that are not tracked by Git (such as `common/src/main/java/io/github/brainage04/modernminecraftmodtemplate` and `common/src/main/resources/assets/modernminecraftmodtemplate`).
  - The `init` script after successful execution.

GitHub Actions initialization preserves files under `.github/workflows`.
The workflow uses GitHub's generated `GITHUB_TOKEN`, which can push normal repository content but cannot update workflow files.
This means repositories initialized through Actions keep the one-shot `init` workflow file, but `init.sh` is deleted and the workflow should not be run again.
If you run `init.sh` locally and push with your own Git credentials, the script also removes the one-shot `init` workflow. The shared client-GameTest workflow remains in every generated repository and skips execution when `mod_side=server`.

For local development after initialisation:
  - Use the Java version configured by `java_version` in `gradle.properties` (`25` by default) or newer for Gradle and Minecraft.
  - `./gradlew build` builds and tests both loaders and collects the Fabric JAR (`<archives_base_name>-<version>.jar`) and the NeoForge JAR (`<archives_base_name>-neoforge-<version>.jar`) in `build/libs`. Players install exactly one of them, matching their loader, plus [Cloth Config](https://modrinth.com/mod/cloth-config) (and Fabric API on Fabric).
  - `./gradlew :fabric:runServer` and `./gradlew :neoforge:runServer` launch a dedicated server on each loader.
  - `./gradlew :fabric:runClient` and `./gradlew :neoforge:runClient` launch a development client on each loader. Tasks that run one loader live in that loader's project (`:fabric:` or `:neoforge:`) under the same name; the root only has tasks spanning both loaders, such as `runAllGameTests`.
  - The example config (`ModConfig` in `common`) uses Cloth Config's AutoConfig: it is saved to `config/<mod_id>.json` and the example commands read their message from it. It generates a config screen, opened from Mod Menu on Fabric (Mod Menu is included as a development dependency) and from the mod list on NeoForge.
  - The template includes a server command example (`ExampleCommand`) and a client command example (`ExampleClientCommand`) in `common`, registered on each loader through the platform contract.

# Testing

Run:

```shell
./gradlew test
```

The template includes example tests under `fabric/src/test/java` that show two useful patterns:
  - Fabric-aware tests that boot Fabric Loader and inspect loaded mod metadata.
  - Plain unit tests for your own code, such as command registration.

For integration-style server tests, run:

```shell
./gradlew :fabric:runGameTest :neoforge:runGameTest
```

The template includes a minimal server GameTest in `common/src/gametest/java` that checks the example command was registered on the server. Fabric runs it through the `@GameTest` method in `fabric/src/gametest`; NeoForge runs it through the test function registered in `neoforge/src/gametest` and its `test_instance` data.
Fabric server GameTests also run automatically as part of `./gradlew build`, which is what the included GitHub Actions workflow executes.
`./gradlew runAllGameTests` runs the Fabric production client and server GameTests and the NeoForge GameTests.

For client-side GameTests, run:

```shell
./gradlew :fabric:runProductionClientGameTest
```

The template also includes a minimal Fabric client GameTest that boots the client, connects to an in-process dedicated server through FabricModdingConventions's defensive client-join helper, starts the recording handshake, and checks that the client initializer ran in an in-world context.
When you initialise with `--side=client`, the generated repo keeps this client GameTest path and removes the dedicated-server GameTest path.

On Ubuntu, local headless client GameTests need Xvfb and the same OpenGL/windowing libraries that the GitHub Actions workflow installs. Recorded client GameTests also need ffmpeg and PipeWire tools:

```shell
sudo apt-get update
sudo apt-get install -y ffmpeg pipewire-bin xvfb mesa-utils libflite1 libgl1-mesa-dri libglx-mesa0 libxi6 libxrandr2 libxrender1 libxtst6 libxinerama1 libxcursor1 libxxf86vm1
```

Run the client GameTest through Xvfb:

```shell
ALSOFT_DRIVERS=null LIBGL_ALWAYS_SOFTWARE=1 \
xvfb-run -a --server-args="-screen 0 1280x720x24" \
./gradlew --no-daemon :fabric:runProductionClientGameTest
```

Record the client GameTest through FabricModdingConventions:

```shell
ALSOFT_DRIVERS=null LIBGL_ALWAYS_SOFTWARE=1 \
./gradlew --no-daemon :fabric:recordClientGameTest
```

# Publishing

Release automation is documented in [docs/RELEASE.md](docs/RELEASE.md).
Optional Modrinth publishing is documented in [docs/MODRINTH.md](docs/MODRINTH.md).

# Credits

Thank you to [nea89o](https://github.com/nea89o)
for developing the GitHub Actions [workflow](https://github.com/nea89o/Forge1.8.9Template/blob/master/.github/workflows/init.yml)
and [script](https://github.com/nea89o/Forge1.8.9Template/blob/master/make-my-own.sh)
from which I based my workflow and script off of.
