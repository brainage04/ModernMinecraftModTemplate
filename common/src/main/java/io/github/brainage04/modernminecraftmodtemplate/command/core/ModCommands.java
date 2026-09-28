package io.github.brainage04.modernminecraftmodtemplate.command.core;

import com.mojang.brigadier.CommandDispatcher;
import io.github.brainage04.modernminecraftmodtemplate.command.ExampleCommand;
import net.minecraft.commands.CommandSourceStack;

public final class ModCommands {
    private ModCommands() {}

    public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
        ExampleCommand.initialize(dispatcher);
    }
}
