package io.github.brainage04.modernminecraftmodtemplate.platform;

import com.mojang.brigadier.CommandDispatcher;
import java.util.function.Consumer;
import net.minecraft.commands.CommandSourceStack;

/**
 * Keep this contract small: add a method only when common code needs something that only the
 * loader can provide (an event, a registry hook, a path), and implement it in both loader modules.
 */
public interface ModernMinecraftModTemplatePlatform {
    String loaderName();

    void registerCommands(Consumer<CommandDispatcher<CommandSourceStack>> registration);
}
