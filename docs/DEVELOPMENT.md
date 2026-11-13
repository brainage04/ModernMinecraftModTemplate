# Development

## Layout

The project is split into three Gradle modules:
  - `common` holds all mod logic: commands, config, mixins, the access widener, assets and data. It compiles against vanilla Minecraft and never imports `net.fabricmc.*` or `net.neoforged.*`.
  - `fabric` holds the Fabric entrypoints (`src/main`, plus `src/client` for client-only code), `fabric.mod.json`, the Fabric GameTests and the unit tests.
  - `neoforge` holds the NeoForge `@Mod` entrypoints, `META-INF/neoforge.mods.toml`, `META-INF/accesstransformer.cfg` (mirror every access widener entry there) and the NeoForge GameTest registration.

Common code reaches loader services through the small contract in `common/src/main/java/io/github/brainage04/modernminecraftmodtemplate/platform`: `ModernMinecraftModTemplatePlatform` for both sides and `ModernMinecraftModTemplateClientPlatform` for the client.
Each loader's entrypoint implements it by wiring the loader's own events, so the loader modules stay thin adapters.
GameTest bodies shared by both loaders live in `common/src/gametest/java`.

## Initialising

```shell
./init.sh [--side=both|server|client] [--skip-format] <mod_name>
```

Local initialization requires `jq`. `<mod_name>` is your GitHub repository name/mod name; the GitHub Actions workflow uses the repository name.
Generated packages always use `io.github.brainage04.<mod_id>`, where `<mod_id>` is sanitized from `<mod_name>` so it is safe for Fabric/NeoForge mod IDs and Java package names.

The optional `--side` flag defaults to `both`.
The script records the choice as `mod_side=both|client|server`; the convention plugin derives the Fabric source sets and GameTest tasks from that property.
Use `--side=server` to generate a server-only repo: it removes the client entrypoints, client commands, client mixins, Mod Menu and the client GameTest.
Use `--side=client` to generate a client-only repo: it removes the server entrypoints, server command, server mixin and the server GameTests on both loaders.
At the end the script runs `./gradlew spotlessApply`, because the strict quality checks fail on renamed lines that no longer match google-java-format; `--skip-format` leaves that out.

The workflow and script are designed to be run once: afterwards they delete the leftover template folders and the `init` script.
The workflow's `GITHUB_TOKEN` cannot update workflow files, so a repository initialized through Actions keeps the one-shot `init` workflow; do not run it again. Run locally and pushed with your own credentials, the script also removes that workflow.

## Building

  - Use the Java version configured by `java_version` in `gradle.properties` (`25` by default) or newer for Gradle and Minecraft.
  - `./gradlew build` builds and tests both loaders and collects the Fabric JAR (`<archives_base_name>-<version>.jar`) and the NeoForge JAR (`<archives_base_name>-neoforge-<version>.jar`) in `build/libs`.
  - `./gradlew :fabric:runServer` and `./gradlew :neoforge:runServer` launch a dedicated server on each loader.
  - `./gradlew :fabric:runClient` and `./gradlew :neoforge:runClient` launch a development client on each loader. Tasks that run one loader live in that loader's project (`:fabric:` or `:neoforge:`) under the same name; the root only has tasks spanning both loaders, such as `runAllGameTests`.

## Testing

`./gradlew test` runs the example tests under `fabric/src/test/java`, which show two useful patterns:
  - Fabric-aware tests that boot Fabric Loader and inspect loaded mod metadata.
  - Plain unit tests for your own code, such as command registration.

For integration-style server tests, run:

```shell
./gradlew :fabric:runGameTest :neoforge:runGameTest
```

The template includes a minimal server GameTest in `common/src/gametest/java` that checks the example command was registered on the server. Fabric runs it through the `@GameTest` method in `fabric/src/gametest`; NeoForge runs it through the test function registered in `neoforge/src/gametest` and its `test_instance` data.
Fabric server GameTests also run automatically as part of `./gradlew build`, which is what the included GitHub Actions workflow executes.
`./gradlew runAllGameTests` runs every GameTest, one run at a time: `:fabric:runGameTest` and `:neoforge:runGameTest` in development, then the GameTests against the packaged mods: the Fabric production server and client GameTests and `:neoforge:runProductionServerGameTest`, which installs a real NeoForge server and runs the NeoForge GameTests on it against the release JAR.
The production runs don't use the development classpath: other mods the packaged mod needs go in `productionRuntimeMods` (Cloth Config in `fabric/build.gradle` and `neoforge/build.gradle`).

## Client GameTests

For client-side GameTests, run:

```shell
./gradlew :fabric:runProductionClientGameTest
```

The template also includes a minimal Fabric client GameTest that boots the client, connects to an in-process dedicated server through MinecraftModConventions's defensive client-join helper, starts the recording handshake, and checks that the client initializer ran in an in-world context.
When you initialise with `--side=client`, the generated repo keeps this client GameTest path and removes the dedicated-server GameTest path.

On Ubuntu, local headless client GameTests need Xvfb and the same OpenGL/windowing libraries that the GitHub Actions workflow installs. Recorded client GameTests also need ffmpeg and PipeWire tools.
Minecraft 26.3 opens its window through SDL3; MinecraftModConventions sets `SDL_VIDEO_DRIVER=x11` for every automated client launch, so the client uses Xvfb even on a Wayland desktop:

```shell
sudo apt-get update
sudo apt-get install -y ffmpeg pipewire-bin xvfb x11-utils mesa-utils libflite1 libgl1-mesa-dri libglx-mesa0 libxi6 libxrandr2 libxrender1 libxtst6 libxinerama1 libxcursor1 libxxf86vm1 libxss1 libxkbcommon0
```

Run the client GameTest through Xvfb:

```shell
ALSOFT_DRIVERS=null LIBGL_ALWAYS_SOFTWARE=1 \
xvfb-run -a --server-args="-screen 0 1280x720x24" \
./gradlew --no-daemon :fabric:runProductionClientGameTest
```

Record the client GameTest through MinecraftModConventions:

```shell
ALSOFT_DRIVERS=null LIBGL_ALWAYS_SOFTWARE=1 \
./gradlew --no-daemon :fabric:recordClientGameTest
```
