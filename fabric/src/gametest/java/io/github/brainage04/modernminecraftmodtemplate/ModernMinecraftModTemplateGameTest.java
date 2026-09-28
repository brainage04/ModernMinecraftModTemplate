package io.github.brainage04.modernminecraftmodtemplate;

import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;

public class ModernMinecraftModTemplateGameTest {
    @GameTest
    public void exampleCommandIsRegistered(GameTestHelper context) {
        ModernMinecraftModTemplateGameTests.exampleCommandIsRegistered(context);
    }
}
