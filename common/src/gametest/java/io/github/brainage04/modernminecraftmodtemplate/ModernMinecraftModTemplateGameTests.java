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
        String mainConfig = System.getProperty(prefix);
        context.assertTrue(
                mainConfig != null && mainConfig.endsWith(".mixin.ExampleMixin"),
                "Expected the main config to register ExampleMixin; properties: " + published());
        // The client config publishes its own key when it runs. Fabric never loads it on a server
        // (fabric.mod.json marks it "environment": "client"), so the key may be absent; when it is
        // present, as on NeoForge, it must be empty.
        String clientConfig = System.getProperty(prefix + ".client");
        context.assertTrue(
                clientConfig == null || clientConfig.isEmpty(),
                "A dedicated server registered a client mixin: " + clientConfig);

        context.succeed();
    }

    private static List<String> published() {
        return System.getProperties().stringPropertyNames().stream()
                .filter(name -> name.startsWith("modernminecraftmodtemplate."))
                .sorted()
                .map(name -> name + "=" + System.getProperty(name))
                .toList();
    }
}
