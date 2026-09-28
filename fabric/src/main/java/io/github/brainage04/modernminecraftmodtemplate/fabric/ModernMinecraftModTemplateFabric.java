package io.github.brainage04.modernminecraftmodtemplate.fabric;

import com.mojang.brigadier.CommandDispatcher;
import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplatePlatform;
import java.util.function.Consumer;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.commands.CommandSourceStack;

public final class ModernMinecraftModTemplateFabric implements ModInitializer, ModernMinecraftModTemplatePlatform {
    @Override
    public void onInitialize() {
        ModernMinecraftModTemplate.initialize(this);
    }

    @Override
    public String loaderName() {
        return "Fabric";
    }

    @Override
    public void registerCommands(Consumer<CommandDispatcher<CommandSourceStack>> registration) {
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> registration.accept(dispatcher));
    }
}
