package io.github.brainage04.modernminecraftmodtemplate.platform;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.commands.SharedSuggestionProvider;

public interface ModernMinecraftModTemplateClientPlatform {
    void registerClientCommands(ClientCommandRegistration registration);

    @FunctionalInterface
    interface ClientCommandRegistration {
        <S extends SharedSuggestionProvider> void register(CommandDispatcher<S> dispatcher);
    }
}
