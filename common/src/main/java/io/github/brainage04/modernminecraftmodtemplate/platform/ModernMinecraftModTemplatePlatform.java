package io.github.brainage04.modernminecraftmodtemplate.platform;

import com.mojang.brigadier.CommandDispatcher;
import java.util.function.Consumer;
import net.minecraft.commands.CommandSourceStack;

/**
 * The loader services common code needs, implemented once by each loader module's entrypoint.
 *
 * <p>Keep this contract small: add a method only when common code needs something that only the
 * loader can provide (an event, a registry hook, a path), and implement it in both loader modules.
 */
public interface ModernMinecraftModTemplatePlatform {
    /** The loader's display name, for logs. */
    String loaderName();

    /** Registers commands on every server (dedicated and integrated) this mod runs on. */
    void registerCommands(Consumer<CommandDispatcher<CommandSourceStack>> registration);
}
