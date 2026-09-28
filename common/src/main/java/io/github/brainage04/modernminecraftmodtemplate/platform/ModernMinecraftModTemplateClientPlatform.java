package io.github.brainage04.modernminecraftmodtemplate.platform;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.commands.SharedSuggestionProvider;

/** The client-only loader services common code needs, implemented by each loader's client entrypoint. */
public interface ModernMinecraftModTemplateClientPlatform {
    /** Registers client-side commands, which run without a server round trip. */
    void registerClientCommands(ClientCommandRegistration registration);

    /**
     * Registers client commands on a loader's dispatcher. Each loader uses its own command source
     * type, so common command trees are generic over it.
     */
    @FunctionalInterface
    interface ClientCommandRegistration {
        <S extends SharedSuggestionProvider> void register(CommandDispatcher<S> dispatcher);
    }
}
