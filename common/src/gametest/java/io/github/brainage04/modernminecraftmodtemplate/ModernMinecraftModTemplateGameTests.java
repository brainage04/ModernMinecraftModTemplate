package io.github.brainage04.modernminecraftmodtemplate;

import io.github.brainage04.modernminecraftmodtemplate.command.ExampleCommand;
import io.github.brainage04.modernminecraftmodtemplate.init.AutoDiscoveryMixinPlugin;
import net.minecraft.gametest.framework.GameTestHelper;

public final class ModernMinecraftModTemplateGameTests {
    private ModernMinecraftModTemplateGameTests() {}

    public static void exampleCommandIsRegistered(GameTestHelper context) {
        context.assertTrue(
                context.getLevel()
                                .getServer()
                                .getCommands()
                                .getDispatcher()
                                .getRoot()
                                .getChild(ExampleCommand.COMMAND_NAME)
                        != null,
                "Expected the example command to be registered on the dedicated server.");

        context.succeed();
    }

    public static void serverLoadsNoClientMixin(GameTestHelper context) {
        String registered =
                System.getProperty(
                        AutoDiscoveryMixinPlugin.REGISTERED_PROPERTY
                                + ModernMinecraftModTemplate.class.getPackageName()
                                + ".mixin");
        context.assertTrue(
                registered != null && !registered.isEmpty(),
                "Expected the mixin plugin to register the server mixin; properties: "
                        + System.getProperties().stringPropertyNames().stream()
                                .filter(name -> name.startsWith("modernminecraftmodtemplate."))
                                .sorted()
                                .map(name -> name + "=" + System.getProperty(name))
                                .toList());
        context.assertFalse(
                registered.contains(".mixin.client."),
                "A dedicated server registered a client mixin: " + registered);

        context.succeed();
    }
}
