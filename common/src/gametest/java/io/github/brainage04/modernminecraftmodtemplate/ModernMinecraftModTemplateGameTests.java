package io.github.brainage04.modernminecraftmodtemplate;

import io.github.brainage04.modernminecraftmodtemplate.command.ExampleCommand;
import io.github.brainage04.modernminecraftmodtemplate.init.AutoDiscoveryMixinPlugin;
import java.util.List;
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
        String prefix =
                AutoDiscoveryMixinPlugin.REGISTERED_PROPERTY
                        + ModernMinecraftModTemplate.class.getPackageName()
                        + ".mixin";
        // Every config the plugin serves publishes its own list, so read them all: the client
        // config is a separate config, and a server that loads it registers its mixins under
        // "<package>.mixin.client", not under the main config's key.
        List<String> registered =
                System.getProperties().stringPropertyNames().stream()
                        .filter(name -> name.startsWith(prefix))
                        .sorted()
                        .map(System::getProperty)
                        .toList();
        context.assertFalse(
                registered.isEmpty(),
                "Expected the mixin plugin to register the server mixin; properties: "
                        + System.getProperties().stringPropertyNames().stream()
                                .filter(name -> name.startsWith("modernminecraftmodtemplate."))
                                .sorted()
                                .map(name -> name + "=" + System.getProperty(name))
                                .toList());
        for (String mixins : registered) {
            context.assertFalse(
                    mixins.contains(".mixin.client."),
                    "A dedicated server registered a client mixin: " + mixins);
        }

        context.succeed();
    }
}
