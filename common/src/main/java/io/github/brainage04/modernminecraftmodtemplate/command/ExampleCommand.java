package io.github.brainage04.modernminecraftmodtemplate.command;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.network.chat.Component;

public class ExampleCommand {
    public static final String COMMAND_NAME = "example";

    public static int execute(CommandSourceStack source) {
        source.sendSuccess(() -> Component.literal("This is an example command."), false);

        return 1;
    }

    public static void initialize(CommandDispatcher<CommandSourceStack> dispatcher) {
        dispatcher.register(LiteralArgumentBuilder.<CommandSourceStack>literal(COMMAND_NAME)
                .executes(context ->
                        execute(
                                context.getSource()
                        )
                )
        );
    }
}
