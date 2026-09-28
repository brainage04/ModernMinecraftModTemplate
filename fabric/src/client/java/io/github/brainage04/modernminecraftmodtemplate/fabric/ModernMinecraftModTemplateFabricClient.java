package io.github.brainage04.modernminecraftmodtemplate.fabric;

import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplateClient;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplateClientPlatform;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;

public final class ModernMinecraftModTemplateFabricClient implements ClientModInitializer, ModernMinecraftModTemplateClientPlatform {
    @Override
    public void onInitializeClient() {
        ModernMinecraftModTemplateClient.initialize(this);
    }

    @Override
    public void registerClientCommands(ClientCommandRegistration registration) {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> registration.register(dispatcher));
    }
}
