package io.github.brainage04.modernminecraftmodtemplate.neoforge;

import com.mojang.brigadier.CommandDispatcher;
import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import io.github.brainage04.modernminecraftmodtemplate.platform.ModernMinecraftModTemplatePlatform;
import java.util.function.Consumer;
import net.minecraft.commands.CommandSourceStack;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.event.RegisterCommandsEvent;

@Mod(ModernMinecraftModTemplate.MOD_ID)
public final class ModernMinecraftModTemplateNeoForge implements ModernMinecraftModTemplatePlatform {
    public ModernMinecraftModTemplateNeoForge() {
        ModernMinecraftModTemplate.initialize(this);
    }

    @Override
    public String loaderName() {
        return "NeoForge";
    }

    @Override
    public void registerCommands(Consumer<CommandDispatcher<CommandSourceStack>> registration) {
        NeoForge.EVENT_BUS.addListener((RegisterCommandsEvent event) -> registration.accept(event.getDispatcher()));
    }
}
