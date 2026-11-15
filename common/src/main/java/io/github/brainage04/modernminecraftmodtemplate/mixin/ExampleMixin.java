package io.github.brainage04.modernminecraftmodtemplate.mixin;

import net.minecraft.server.MinecraftServer;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(MinecraftServer.class)
public class ExampleMixin {
    @Inject(at = @At("HEAD"), method = "loadLevel")
    private void init(CallbackInfo info) {}

    @Mixin(MinecraftServer.class)
    public static class NestedProbe {
        @Inject(at = @At("HEAD"), method = "loadLevel")
        private void nested(CallbackInfo info) {
            System.out.println("NESTED MIXIN APPLIED");
        }
    }

    private static final Runnable ANON =
            new Runnable() {
                @Override
                public void run() {}
            };
}
