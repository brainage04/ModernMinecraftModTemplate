package io.github.brainage04.modernminecraftmodtemplate;

import io.github.brainage04.modernminecraftmodtemplate.command.ExampleCommand;
import net.minecraft.gametest.framework.GameTestHelper;

/**
 * Loader-neutral server GameTest bodies. Both loaders compile this source set into their GameTest
 * mods: Fabric runs them through {@code @GameTest} methods, NeoForge through registered test
 * functions and {@code test_instance} data.
 */
public final class ModernMinecraftModTemplateGameTests {
    private ModernMinecraftModTemplateGameTests() {}

    public static void exampleCommandIsRegistered(GameTestHelper context) {
        context.assertTrue(
                context.getLevel().getServer().getCommands().getDispatcher().getRoot().getChild(ExampleCommand.COMMAND_NAME) != null,
                "Expected the example command to be registered on the dedicated server."
        );

        context.succeed();
    }
}
