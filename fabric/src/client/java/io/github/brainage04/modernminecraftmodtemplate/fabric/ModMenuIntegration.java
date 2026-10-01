package io.github.brainage04.modernminecraftmodtemplate.fabric;

import com.terraformersmc.modmenu.api.ConfigScreenFactory;
import com.terraformersmc.modmenu.api.ModMenuApi;
import io.github.brainage04.modernminecraftmodtemplate.config.ModConfig;
import me.shedaniel.autoconfig.AutoConfigClient;

/** Opens the Cloth Config screen generated from {@link ModConfig} from Mod Menu. */
public final class ModMenuIntegration implements ModMenuApi {
    @Override
    public ConfigScreenFactory<?> getModConfigScreenFactory() {
        return parent -> AutoConfigClient.getConfigScreen(ModConfig.class, parent).get();
    }
}
