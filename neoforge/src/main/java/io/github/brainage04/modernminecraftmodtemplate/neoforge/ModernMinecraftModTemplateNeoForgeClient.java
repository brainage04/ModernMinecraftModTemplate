package io.github.brainage04.modernminecraftmodtemplate.neoforge;

import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplateClient;
import io.github.brainage04.modernminecraftmodtemplate.config.ModConfig;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplateClientPlatform;
import me.shedaniel.autoconfig.AutoConfigClient;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.client.event.RegisterClientCommandsEvent;
import net.neoforged.neoforge.client.gui.IConfigScreenFactory;
import net.neoforged.neoforge.common.NeoForge;

@Mod(value = ModernMinecraftModTemplate.MOD_ID, dist = Dist.CLIENT)
public final class ModernMinecraftModTemplateNeoForgeClient implements ModernMinecraftModTemplateClientPlatform {
    public ModernMinecraftModTemplateNeoForgeClient(ModContainer container) {
        ModernMinecraftModTemplateClient.initialize(this);
        container.registerExtensionPoint(
                IConfigScreenFactory.class,
                (modContainer, parent) -> AutoConfigClient.getConfigScreen(ModConfig.class, parent).get());
    }

    @Override
    public void registerClientCommands(ClientCommandRegistration registration) {
        NeoForge.EVENT_BUS.addListener((RegisterClientCommandsEvent event) -> registration.register(event.getDispatcher()));
    }
}
