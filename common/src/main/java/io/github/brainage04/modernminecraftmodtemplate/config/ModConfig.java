package io.github.brainage04.modernminecraftmodtemplate.config;

import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import me.shedaniel.autoconfig.AutoConfig;
import me.shedaniel.autoconfig.ConfigData;
import me.shedaniel.autoconfig.annotation.Config;
import me.shedaniel.autoconfig.serializer.GsonConfigSerializer;

@Config(name = ModernMinecraftModTemplate.MOD_ID)
public class ModConfig implements ConfigData {
    public boolean logConfigOnStartup = true;
    public String exampleMessage = "This is an example command.";

    /** Call once, during mod initialization. */
    public static void init() {
        AutoConfig.register(ModConfig.class, GsonConfigSerializer::new);
    }

    public static ModConfig get() {
        return AutoConfig.getConfigHolder(ModConfig.class).getConfig();
    }
}
