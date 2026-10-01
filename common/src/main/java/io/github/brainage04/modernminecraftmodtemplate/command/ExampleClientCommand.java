package io.github.brainage04.modernminecraftmodtemplate.command;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import io.github.brainage04.modernminecraftmodtemplate.config.ModConfig;
import net.minecraft.client.Minecraft;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.network.chat.Component;

public class ExampleClientCommand {
    public static final String COMMAND_NAME = "exampleclient";

    public static int execute() {
        Minecraft minecraft = Minecraft.getInstance();
        if (minecraft.player != null) {
            minecraft.player.sendSystemMessage(Component.literal(ModConfig.get().exampleMessage));
        }

        return 1;
    }

    public static <S extends SharedSuggestionProvider> void initialize(CommandDispatcher<S> dispatcher) {
        dispatcher.register(LiteralArgumentBuilder.<S>literal(COMMAND_NAME)
                .executes(context -> execute())
        );
    }
}
