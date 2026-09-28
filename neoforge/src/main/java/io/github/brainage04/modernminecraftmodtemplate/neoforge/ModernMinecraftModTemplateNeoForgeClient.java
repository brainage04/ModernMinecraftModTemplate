package io.github.brainage04.modernminecraftmodtemplate.neoforge;

import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplateClient;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplateClientPlatform;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.client.event.RegisterClientCommandsEvent;
import net.neoforged.neoforge.common.NeoForge;

@Mod(value = ModernMinecraftModTemplate.MOD_ID, dist = Dist.CLIENT)
public final class ModernMinecraftModTemplateNeoForgeClient implements ModernMinecraftModTemplateClientPlatform {
    public ModernMinecraftModTemplateNeoForgeClient() {
        ModernMinecraftModTemplateClient.initialize(this);
    }

    @Override
    public void registerClientCommands(ClientCommandRegistration registration) {
        NeoForge.EVENT_BUS.addListener((RegisterClientCommandsEvent event) -> registration.register(event.getDispatcher()));
    }
}
