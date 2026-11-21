package io.github.brainage04.modernminecraftmodtemplate;

import io.github.brainage04.modernminecraftmodtemplate.command.core.ModCommands;
import io.github.brainage04.modernminecraftmodtemplate.config.ModConfig;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplatePlatform;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ModernMinecraftModTemplate {
    public static final String MOD_ID = "modernminecraftmodtemplate";
    public static final String MOD_NAME = "ModernMinecraftModTemplate";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_NAME);

    private static volatile ModernMinecraftModTemplatePlatform platform;

    private ModernMinecraftModTemplate() {}

    public static ModernMinecraftModTemplatePlatform platform() {
        if (platform == null) {
            throw new IllegalStateException(MOD_NAME + " has not been initialised yet");
        }
        return platform;
    }

    public static void initialize(ModernMinecraftModTemplatePlatform platform) {
        ModernMinecraftModTemplate.platform = platform;
        LOGGER.info("{} initialising on {}...", MOD_NAME, platform.loaderName());

        ModConfig.init();
        platform.registerCommands(ModCommands::register);

        if (ModConfig.get().logConfigOnStartup) {
            LOGGER.info("Loaded config: exampleMessage='{}'", ModConfig.get().exampleMessage);
        }

        LOGGER.info("{} initialised.", MOD_NAME);
    }
}
