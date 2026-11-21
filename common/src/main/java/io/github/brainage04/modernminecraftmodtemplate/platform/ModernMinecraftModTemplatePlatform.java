package io.github.brainage04.modernminecraftmodtemplate.platform;

import com.mojang.brigadier.CommandDispatcher;
import java.util.function.Consumer;
import net.minecraft.commands.CommandSourceStack;

/**
 * Keep this contract small: add a method only when common code needs something that only the loader
 * can provide (an event, a registry hook, a path), and implement it in both loader modules.
 */
public interface ModernMinecraftModTemplatePlatform {
    String loaderName();

    /**
     * Whether this loader loads this mod's client mixin config on a dedicated server. Fabric's
     * {@code fabric.mod.json} marks the client config {@code "environment": "client"} and
     * {@code V1ModMetadata.getMixinConfigs} filters on it, so a server never loads that config;
     * {@code neoforge.mods.toml} has no side element, {@code ModFileParser.getMixinConfigs} reads
     * none, and {@code MixinFacade} applies no dist filter, so NeoForge does.
     */
    boolean loadsClientMixinConfigOnServer();

    void registerCommands(Consumer<CommandDispatcher<CommandSourceStack>> registration);
}
