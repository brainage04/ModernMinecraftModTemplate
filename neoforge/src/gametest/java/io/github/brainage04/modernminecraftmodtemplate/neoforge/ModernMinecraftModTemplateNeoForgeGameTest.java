package io.github.brainage04.modernminecraftmodtemplate.neoforge;

import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplateGameTests;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.registries.RegisterEvent;

/**
 * Registers the shared GameTests as NeoForge test functions. Each function needs a matching
 * {@code data/<mod_id>/test_instance/<name>.json} in this source set's resources.
 */
@EventBusSubscriber(modid = ModernMinecraftModTemplate.MOD_ID)
public final class ModernMinecraftModTemplateNeoForgeGameTest {
    private ModernMinecraftModTemplateNeoForgeGameTest() {}

    @SubscribeEvent
    public static void registerTestFunctions(RegisterEvent event) {
        event.register(
                BuiltInRegistries.TEST_FUNCTION.key(),
                Identifier.fromNamespaceAndPath(ModernMinecraftModTemplate.MOD_ID, "example_command_is_registered"),
                () -> ModernMinecraftModTemplateGameTests::exampleCommandIsRegistered
        );
    }
}
