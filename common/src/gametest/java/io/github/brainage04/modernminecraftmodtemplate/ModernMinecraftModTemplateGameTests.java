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
        String mixinPackage = ModernMinecraftModTemplate.class.getPackageName() + ".mixin";
        String prefix = AutoDiscoveryMixinPlugin.REGISTERED_PROPERTY + mixinPackage;
        String mainConfig = System.getProperty(prefix);
        List<String> mainMixins = mainConfig == null ? List.of() : List.of(mainConfig.split(","));
        context.assertTrue(
                mainMixins.contains(mixinPackage + ".ExampleMixin"),
                "Expected the main config to register ExampleMixin; properties: " + published());
        context.assertFalse(
                mainMixins.stream().anyMatch(mixin -> mixin.startsWith(mixinPackage + ".client.")),
                "The main config registered a client mixin: " + mainConfig);
        // init.sh --side=server deletes the client config and its neoforge.mods.toml entry, so a
        // server-only generated mod has nothing to check here.
        if (ModernMinecraftModTemplate.class.getResource(
                        "/" + ModernMinecraftModTemplate.MOD_ID + ".client.mixins.json")
                == null) {
            context.succeed();
            return;
        }
        // The client config publishes its own key when it runs. Fabric never loads it on a server
        // (fabric.mod.json marks it "environment": "client"), so the key may be absent there;
        // neoforge.mods.toml lists it with no side restriction, so NeoForge loads it and it must
        // publish an empty list.
        String clientConfig = System.getProperty(prefix + ".client");
        context.assertTrue(
                clientConfig != null
                        || !ModernMinecraftModTemplate.platform().loadsClientMixinConfigOnServer(),
                "Expected the client config to run on this loader; properties: " + published());
        context.assertTrue(
                clientConfig == null || clientConfig.isEmpty(),
                "A dedicated server registered a client mixin: " + clientConfig);

        context.succeed();
    }

    private static List<String> published() {
        return System.getProperties().stringPropertyNames().stream()
                .filter(name -> name.startsWith(AutoDiscoveryMixinPlugin.REGISTERED_PROPERTY))
                .sorted()
                .map(name -> name + "=" + System.getProperty(name))
                .toList();
    }
}
