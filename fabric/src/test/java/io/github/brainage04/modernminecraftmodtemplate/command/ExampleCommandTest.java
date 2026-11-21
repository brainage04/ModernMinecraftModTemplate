package io.github.brainage04.modernminecraftmodtemplate.command;

import static org.junit.jupiter.api.Assertions.assertNotNull;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.commands.CommandSourceStack;
import org.junit.jupiter.api.Test;

class ExampleCommandTest {
    @Test
    void initializeRegistersTheExampleLiteral() {
        CommandDispatcher<CommandSourceStack> dispatcher = new CommandDispatcher<>();

        ExampleCommand.initialize(dispatcher);

        assertNotNull(dispatcher.getRoot().getChild(ExampleCommand.COMMAND_NAME));
    }
}
