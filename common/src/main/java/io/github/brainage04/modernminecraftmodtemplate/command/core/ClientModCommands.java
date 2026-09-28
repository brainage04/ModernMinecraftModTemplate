package io.github.brainage04.modernminecraftmodtemplate.command.core;

import com.mojang.brigadier.CommandDispatcher;
import io.github.brainage04.modernminecraftmodtemplate.command.ExampleClientCommand;
import net.minecraft.commands.SharedSuggestionProvider;

public final class ClientModCommands {
    private ClientModCommands() {}

    public static <S extends SharedSuggestionProvider> void register(CommandDispatcher<S> dispatcher) {
        ExampleClientCommand.initialize(dispatcher);
    }
}
