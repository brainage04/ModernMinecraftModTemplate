# ModernMinecraftModTemplate

My template for modern Minecraft mods that ship a Fabric JAR and a NeoForge JAR from one codebase, built with the `io.github.brainage04.multiloader-mod-conventions` Gradle plugin from [MinecraftModConventions](https://github.com/brainage04/MinecraftModConventions).

The template targets Minecraft 26.3 with Fabric Loader 0.19.5 and Fabric API 0.165.0+26.3, or NeoForge 26.3.0.99, plus Cloth Config 26.3.159 and (Fabric only) Mod Menu 21.0.0. All of these are set in `gradle.properties`.

## Features

- `common`, `fabric` and `neoforge` modules: all mod logic in `common`, the loader modules stay thin adapters.
- An example command, mixin and config, with example unit tests and GameTests.
- Release workflows for GitHub, Modrinth and CurseForge.

## Getting started

1. Click `Use this template` and create your new repository.
2. Open the new repository's `Actions` tab.
3. Run the `Initialize Template Repo` workflow.
4. Choose `both`, `server`, or `client` for the mod side.

On a Linux system you can also clone this repository and initialise it locally with `./init.sh [--side=both|server|client] <mod_name>`; see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

Players install exactly one of the two JARs, matching their loader, plus [Cloth Config](https://modrinth.com/mod/cloth-config) (and Fabric API on Fabric).

## Commands

The template includes a server command example (`ExampleCommand`) and a client command example (`ExampleClientCommand`) in `common`, registered on each loader through the platform contract.

## Configuration

The example config (`ModConfig` in `common`) uses Cloth Config's AutoConfig: it is saved to `config/<mod_id>.json` and the example commands read their message from it. It generates a config screen, opened from Mod Menu on Fabric (Mod Menu is included as a development dependency) and from the mod list on NeoForge.

## Compatibility

No known incompatibilities.

## Documentation

- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) - layout, initialising, building and testing.
- [docs/RELEASE.md](docs/RELEASE.md) - release automation.
- [docs/MODRINTH.md](docs/MODRINTH.md) - optional Modrinth publishing.

Thank you to [nea89o](https://github.com/nea89o) for developing the GitHub Actions [workflow](https://github.com/nea89o/Forge1.8.9Template/blob/master/.github/workflows/init.yml) and [script](https://github.com/nea89o/Forge1.8.9Template/blob/master/make-my-own.sh) from which I based my workflow and script off of.
