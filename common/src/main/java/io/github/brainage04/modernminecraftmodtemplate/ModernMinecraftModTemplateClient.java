package io.github.brainage04.modernminecraftmodtemplate;

import io.github.brainage04.modernminecraftmodtemplate.command.core.ClientModCommands;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplateClientPlatform;

public final class ModernMinecraftModTemplateClient {
    private static volatile boolean initialized;

    private ModernMinecraftModTemplateClient() {}

    /** Called by each loader's client entrypoint on the physical client only. */
    public static void initialize(ModernMinecraftModTemplateClientPlatform platform) {
        platform.registerClientCommands(ClientModCommands::register);
        initialized = true;

        ModernMinecraftModTemplate.LOGGER.info("{} client initialised.", ModernMinecraftModTemplate.MOD_NAME);
    }

    public static boolean isInitialized() {
        return initialized;
    }
}
