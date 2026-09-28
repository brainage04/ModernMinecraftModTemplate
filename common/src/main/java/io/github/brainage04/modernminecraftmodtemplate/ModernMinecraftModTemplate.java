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

    private ModernMinecraftModTemplate() {}

    /** Called by each loader's main entrypoint on both physical sides. */
    public static void initialize(ModernMinecraftModTemplatePlatform platform) {
        LOGGER.info("{} initialising on {}...", MOD_NAME, platform.loaderName());

        ModConfig.init();
        platform.registerCommands(ModCommands::register);

        if (ModConfig.CONFIG.logConfigOnStartup.get()) {
            LOGGER.info(
                    "Loaded config: message='{}', mode={}, featuredItem={}, retries={}",
                    ModConfig.CONFIG.welcomeMessage.get(),
                    ModConfig.CONFIG.syncMode.get(),
                    ModConfig.CONFIG.featuredItem.get(),
                    ModConfig.CONFIG.startupRetries.get()
            );
        }

        LOGGER.info("{} initialised.", MOD_NAME);
    }
}
